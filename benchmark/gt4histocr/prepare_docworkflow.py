#!/usr/bin/env python3
"""Materialize a GT4HistOCR subset as leakage-free one-line ALTO files.

Each selected line image becomes one ALTO page with a single TextLine covering
the full image. Ground-truth text is deliberately NOT embedded in the ALTO.
The TextLine ID is the stable line_id from the subset manifest, so DocWorkflow
prediction JSON can be joined back to ground truth without filename heuristics.
"""
from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path
import shutil
import struct
import xml.etree.ElementTree as ET


ALTO_NS = "http://www.loc.gov/standards/alto/ns-v4#"
XSI_NS = "http://www.w3.org/2001/XMLSchema-instance"
ET.register_namespace("", ALTO_NS)
ET.register_namespace("xsi", XSI_NS)


def read_png_size(path: Path):
    with path.open("rb") as handle:
        signature = handle.read(24)

    if len(signature) < 24:
        raise ValueError(
            f"Image too short to be a PNG: {path}"
        )
    if signature[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(
            f"Expected PNG line image, got unsupported format: {path}"
        )
    if signature[12:16] != b"IHDR":
        raise ValueError(
            f"PNG lacks IHDR at expected location: {path}"
        )

    width, height = struct.unpack(
        ">II",
        signature[16:24],
    )
    if width < 1 or height < 1:
        raise ValueError(
            f"Invalid image size {width}x{height}: {path}"
        )
    return width, height


def load_manifest(path: Path):
    with path.open(
        "r",
        encoding="utf-8-sig",
        newline="",
    ) as handle:
        rows = list(csv.DictReader(handle))

    if not rows:
        raise ValueError(
            f"Empty subset manifest: {path}"
        )

    required = {
        "line_id",
        "reference",
        "image_path",
        "document_id",
        "subcorpus",
    }
    missing = required - set(rows[0])
    if missing:
        raise ValueError(
            "Manifest missing columns: "
            + ", ".join(sorted(missing))
        )

    ids = [row["line_id"] for row in rows]
    if len(ids) != len(set(ids)):
        raise ValueError(
            "Manifest line_id values must be unique"
        )

    return rows


def qname(name: str):
    return f"{{{ALTO_NS}}}{name}"


def create_alto(
    output_xml: Path,
    image_filename: str,
    line_id: str,
    width: int,
    height: int,
):
    alto = ET.Element(
        qname("alto"),
        {
            f"{{{XSI_NS}}}schemaLocation":
                "http://www.loc.gov/standards/alto/ns-v4# "
                "http://www.loc.gov/standards/alto/v4/alto-4-2.xsd"
        },
    )

    description = ET.SubElement(
        alto,
        qname("Description"),
    )
    ET.SubElement(
        description,
        qname("MeasurementUnit"),
    ).text = "pixel"

    source_info = ET.SubElement(
        description,
        qname("sourceImageInformation"),
    )
    ET.SubElement(
        source_info,
        qname("fileName"),
    ).text = image_filename

    tags = ET.SubElement(
        alto,
        qname("Tags"),
    )
    ET.SubElement(
        tags,
        qname("OtherTag"),
        {
            "ID": "BT1",
            "LABEL": "MainZone",
            "DESCRIPTION": "block type MainZone",
        },
    )
    ET.SubElement(
        tags,
        qname("OtherTag"),
        {
            "ID": "LT1",
            "LABEL": "DefaultLine",
            "DESCRIPTION": "line type DefaultLine",
        },
    )

    layout = ET.SubElement(
        alto,
        qname("Layout"),
    )
    page = ET.SubElement(
        layout,
        qname("Page"),
        {
            "ID": "page_1",
            "PHYSICAL_IMG_NR": "1",
            "WIDTH": str(width),
            "HEIGHT": str(height),
        },
    )
    print_space = ET.SubElement(
        page,
        qname("PrintSpace"),
        {
            "HPOS": "0",
            "VPOS": "0",
            "WIDTH": str(width),
            "HEIGHT": str(height),
        },
    )
    block = ET.SubElement(
        print_space,
        qname("TextBlock"),
        {
            "ID": "block_1",
            "HPOS": "0",
            "VPOS": "0",
            "WIDTH": str(width),
            "HEIGHT": str(height),
            "TAGREFS": "BT1",
        },
    )

    x2 = max(0, width - 1)
    y2 = max(0, height - 1)
    baseline_y = max(0, height - 2)

    line = ET.SubElement(
        block,
        qname("TextLine"),
        {
            "ID": line_id,
            "HPOS": "0",
            "VPOS": "0",
            "WIDTH": str(width),
            "HEIGHT": str(height),
            "TAGREFS": "LT1",
            "BASELINE": (
                f"0 {baseline_y} "
                f"{x2} {baseline_y}"
            ),
        },
    )
    shape = ET.SubElement(
        line,
        qname("Shape"),
    )
    ET.SubElement(
        shape,
        qname("Polygon"),
        {
            "POINTS": (
                f"0,0 {x2},0 "
                f"{x2},{y2} 0,{y2}"
            )
        },
    )

    output_xml.parent.mkdir(
        parents=True,
        exist_ok=True,
    )
    ET.ElementTree(alto).write(
        output_xml,
        encoding="UTF-8",
        xml_declaration=True,
    )


def materialize_image(
    source: Path,
    destination: Path,
    mode: str,
):
    destination.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    if destination.exists() or destination.is_symlink():
        destination.unlink()

    if mode == "symlink":
        os.symlink(
            source.resolve(),
            destination,
        )
    elif mode == "copy":
        shutil.copy2(
            source,
            destination,
        )
    else:
        raise ValueError(
            f"Unsupported materialization mode: {mode}"
        )


def prepare(
    root: Path,
    manifest_rows,
    output: Path,
    mode: str,
):
    output.mkdir(
        parents=True,
        exist_ok=True,
    )

    generated = []

    for row in manifest_rows:
        source_image = (
            root
            / row["image_path"]
        )
        if not source_image.exists():
            raise ValueError(
                f"Missing source image: {source_image}"
            )

        width, height = read_png_size(
            source_image
        )

        line_id = row["line_id"]
        image_name = f"{line_id}.png"
        xml_name = f"{line_id}.xml"

        destination_image = (
            output
            / image_name
        )
        destination_xml = (
            output
            / xml_name
        )

        materialize_image(
            source_image,
            destination_image,
            mode,
        )

        create_alto(
            destination_xml,
            image_filename=image_name,
            line_id=line_id,
            width=width,
            height=height,
        )

        generated.append({
            "line_id": line_id,
            "source_image": str(
                source_image
            ),
            "prepared_image": str(
                destination_image
            ),
            "prepared_xml": str(
                destination_xml
            ),
            "width": width,
            "height": height,
        })

    return generated


def parse_args(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        required=True,
        help="Unpacked GT4HistOCR root.",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--mode",
        choices=("symlink", "copy"),
        default="symlink",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    rows = load_manifest(
        args.manifest.expanduser()
    )

    generated = prepare(
        root=args.root.expanduser(),
        manifest_rows=rows,
        output=args.output.expanduser(),
        mode=args.mode,
    )

    print(
        f"Prepared leakage-free ALTO lines: "
        f"{len(generated)}"
    )
    print(
        f"Output: {args.output.expanduser()}"
    )


if __name__ == "__main__":
    main()
