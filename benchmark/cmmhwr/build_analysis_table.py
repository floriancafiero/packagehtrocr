#!/usr/bin/env python3
"""Build a canonical line-level OCR/HTR benchmark table.

The script joins ALTO ground truth with one or more prediction JSON files in the
CMMHWR/DocWorkflow format (a JSON object mapping line_id -> transcription).

It uses only Python's standard library so it can run in either the DocWorkflow
environment or a lightweight reproducibility environment.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import xml.etree.ElementTree as ET


IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".tif", ".tiff", ".webp")
RESERVED_COLUMNS = {
    "benchmark", "document_id", "page_id", "line_id", "system",
    "reference", "prediction", "image_path", "source_xml",
    "hpos", "vpos", "width", "height", "polygon",
}


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def iter_local(element: ET.Element, name: str):
    for child in element.iter():
        if local_name(child.tag) == name:
            yield child


def parse_float(value):
    if value is None or value == "":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def clean_number(value):
    if value is None:
        return ""
    if float(value).is_integer():
        return int(value)
    return value


def parse_polygon(textline: ET.Element) -> str:
    for shape in textline:
        if local_name(shape.tag) != "Shape":
            continue
        for polygon in shape:
            if local_name(polygon.tag) == "Polygon":
                points = polygon.attrib.get("POINTS", "").strip()
                if points:
                    return points
    return ""


def polygon_bbox(points: str):
    if not points:
        return None
    coords = []
    for token in points.replace(";", " ").split():
        if "," not in token:
            continue
        x, y = token.split(",", 1)
        try:
            coords.append((float(x), float(y)))
        except ValueError:
            continue
    if not coords:
        return None
    xs = [p[0] for p in coords]
    ys = [p[1] for p in coords]
    return min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)


def line_text(textline: ET.Element) -> str:
    words = []
    for string in iter_local(textline, "String"):
        content = string.attrib.get("CONTENT", "")
        if content:
            words.append(content)
    return " ".join(words)


def build_image_index(root: Path):
    by_stem = {}
    if not root.exists():
        return by_stem
    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS:
            by_stem.setdefault(path.stem, []).append(path)
    return by_stem


def find_image(xml_path: Path, gt_root: Path, image_root: Path | None, image_index):
    for ext in IMAGE_EXTENSIONS:
        candidate = xml_path.with_suffix(ext)
        if candidate.exists():
            return candidate

    if image_root is None:
        return None

    try:
        rel_parent = xml_path.parent.relative_to(gt_root)
        for ext in IMAGE_EXTENSIONS:
            candidate = image_root / rel_parent / (xml_path.stem + ext)
            if candidate.exists():
                return candidate
    except ValueError:
        pass

    matches = image_index.get(xml_path.stem, [])
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        raise ValueError(
            f"Ambiguous image stem {xml_path.stem!r}: "
            + ", ".join(str(p) for p in matches[:5])
        )
    return None


def display_path(path: Path | None, base: Path) -> str:
    if path is None:
        return ""
    try:
        return str(path.resolve().relative_to(base.resolve()))
    except ValueError:
        return str(path.resolve())


def read_ground_truth(gt_root: Path, image_root: Path | None):
    xml_files = sorted(gt_root.rglob("*.xml"))
    if not xml_files:
        raise ValueError(f"No XML files found under {gt_root}")

    image_index = build_image_index(image_root) if image_root else {}
    rows = []
    seen = {}

    for xml_path in xml_files:
        try:
            root = ET.parse(xml_path).getroot()
        except ET.ParseError as exc:
            raise ValueError(f"Invalid XML: {xml_path}: {exc}") from exc

        image_path = find_image(
            xml_path,
            gt_root=gt_root,
            image_root=image_root,
            image_index=image_index,
        )

        document_id = xml_path.parent.name
        page_id = xml_path.stem

        for textline in iter_local(root, "TextLine"):
            line_id = textline.attrib.get("ID", "").strip()
            if not line_id:
                continue
            if line_id in seen:
                raise ValueError(
                    f"Duplicate line_id {line_id!r} in {xml_path}; "
                    f"already seen in {seen[line_id]}"
                )
            seen[line_id] = xml_path

            polygon = parse_polygon(textline)
            hpos = parse_float(textline.attrib.get("HPOS"))
            vpos = parse_float(textline.attrib.get("VPOS"))
            width = parse_float(textline.attrib.get("WIDTH"))
            height = parse_float(textline.attrib.get("HEIGHT"))

            if any(v is None for v in (hpos, vpos, width, height)):
                bbox = polygon_bbox(polygon)
                if bbox is not None:
                    ph, pv, pw, pheight = bbox
                    hpos = ph if hpos is None else hpos
                    vpos = pv if vpos is None else vpos
                    width = pw if width is None else width
                    height = pheight if height is None else height

            rows.append({
                "document_id": document_id,
                "page_id": page_id,
                "line_id": line_id,
                "reference": line_text(textline),
                "image_path": display_path(
                    image_path,
                    image_root if image_root is not None else gt_root,
                ),
                "source_xml": display_path(xml_path, gt_root),
                "hpos": clean_number(hpos),
                "vpos": clean_number(vpos),
                "width": clean_number(width),
                "height": clean_number(height),
                "polygon": polygon,
            })

    if not rows:
        raise ValueError(f"No TextLine IDs found under {gt_root}")
    return rows


def load_predictions(spec: str):
    if "=" not in spec:
        raise ValueError(
            f"System specification {spec!r} must be NAME=/path/to/predictions.json"
        )
    name, raw_path = spec.split("=", 1)
    name = name.strip()
    if not name:
        raise ValueError(f"Empty system name in {spec!r}")
    path = Path(raw_path).expanduser()
    if not path.exists():
        raise ValueError(f"Prediction file not found for {name}: {path}")

    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    if isinstance(data, dict):
        predictions = {
            str(k): str(v) if v is not None else ""
            for k, v in data.items()
        }
    elif isinstance(data, list):
        predictions = {}
        for item in data:
            if not isinstance(item, dict):
                raise ValueError(f"Unsupported list item in {path}: {item!r}")
            line_id = item.get("line_id", item.get("id"))
            value = item.get("prediction", item.get("text"))
            if line_id is None or value is None:
                raise ValueError(
                    f"List predictions in {path} need line_id/id and prediction/text"
                )
            line_id = str(line_id)
            if line_id in predictions:
                raise ValueError(
                    f"Duplicate prediction line_id {line_id!r} in {path}"
                )
            predictions[line_id] = str(value)
    else:
        raise ValueError(
            f"Unsupported prediction JSON root in {path}: "
            f"{type(data).__name__}"
        )

    return name, path, predictions


def load_metadata(path: Path | None):
    if path is None:
        return {}, []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or "line_id" not in reader.fieldnames:
            raise ValueError("Metadata CSV must contain a line_id column")

        extra_columns = [
            column for column in reader.fieldnames
            if column != "line_id"
        ]
        collisions = RESERVED_COLUMNS.intersection(extra_columns)
        if collisions:
            raise ValueError(
                "Metadata columns collide with reserved output columns: "
                + ", ".join(sorted(collisions))
            )

        metadata = {}
        for row in reader:
            line_id = row["line_id"]
            if line_id in metadata:
                raise ValueError(
                    f"Duplicate line_id {line_id!r} in metadata"
                )
            metadata[line_id] = {
                column: row.get(column, "")
                for column in extra_columns
            }
    return metadata, extra_columns


def build_table(
    gt_rows,
    system_specs,
    benchmark: str,
    metadata,
    metadata_columns,
    allow_missing: bool,
):
    gt_ids = {row["line_id"] for row in gt_rows}
    systems = []
    names = set()

    for spec in system_specs:
        name, path, predictions = load_predictions(spec)
        if name in names:
            raise ValueError(f"Duplicate system name: {name}")
        names.add(name)

        pred_ids = set(predictions)
        missing = sorted(gt_ids - pred_ids)
        extra = sorted(pred_ids - gt_ids)

        if extra:
            raise ValueError(
                f"{name}: {len(extra)} prediction IDs are absent from "
                f"ground truth; examples: {extra[:5]}"
            )
        if missing and not allow_missing:
            raise ValueError(
                f"{name}: missing {len(missing)} ground-truth line IDs; "
                f"examples: {missing[:5]}. Use --allow-missing only "
                "for diagnostics."
            )

        systems.append((name, path, predictions, len(missing)))

    out = []
    for base in gt_rows:
        line_id = base["line_id"]
        meta = metadata.get(line_id, {})
        for name, _, predictions, _ in systems:
            row = {
                "benchmark": benchmark,
                "document_id": base["document_id"],
                "page_id": base["page_id"],
                "line_id": line_id,
                "system": name,
                "reference": base["reference"],
                "prediction": predictions.get(line_id, ""),
                "image_path": base["image_path"],
                "source_xml": base["source_xml"],
                "hpos": base["hpos"],
                "vpos": base["vpos"],
                "width": base["width"],
                "height": base["height"],
                "polygon": base["polygon"],
            }
            for column in metadata_columns:
                row[column] = meta.get(column, "")
            out.append(row)

    return out, systems


def write_csv(rows, output: Path, metadata_columns):
    output.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "benchmark", "document_id", "page_id", "line_id", "system",
        "reference", "prediction", "image_path", "source_xml",
        "hpos", "vpos", "width", "height", "polygon",
        *metadata_columns,
    ]
    with output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=fields,
            extrasaction="raise",
        )
        writer.writeheader()
        writer.writerows(rows)


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description=(
            "Join CMMHWR-style ALTO ground truth and prediction JSON "
            "files into one canonical line-by-system CSV."
        )
    )
    parser.add_argument("--gt-root", type=Path, required=True)
    parser.add_argument(
        "--system",
        action="append",
        required=True,
        metavar="NAME=JSON",
        help="Repeat for each recognition system.",
    )
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--image-root", type=Path)
    parser.add_argument("--metadata", type=Path)
    parser.add_argument("--benchmark", default="cmmhwr26")
    parser.add_argument(
        "--allow-missing",
        action="store_true",
        help=(
            "Allow systems to omit GT line IDs; missing predictions "
            "become empty strings."
        ),
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    gt_root = args.gt_root.expanduser()
    image_root = args.image_root.expanduser() if args.image_root else None

    gt_rows = read_ground_truth(
        gt_root,
        image_root=image_root,
    )
    metadata, metadata_columns = load_metadata(
        args.metadata.expanduser()
        if args.metadata
        else None
    )

    rows, systems = build_table(
        gt_rows=gt_rows,
        system_specs=args.system,
        benchmark=args.benchmark,
        metadata=metadata,
        metadata_columns=metadata_columns,
        allow_missing=args.allow_missing,
    )
    write_csv(
        rows,
        args.output.expanduser(),
        metadata_columns,
    )

    print(f"Ground-truth lines: {len(gt_rows)}")
    print(f"Systems: {len(systems)}")
    for name, path, _, missing in systems:
        suffix = f", {missing} missing" if missing else ""
        print(f"  - {name}: {path}{suffix}")
    print(f"Output rows: {len(rows)}")
    print(f"Wrote: {args.output.expanduser()}")


if __name__ == "__main__":
    main()
