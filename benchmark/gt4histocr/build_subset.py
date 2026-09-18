#!/usr/bin/env python3
"""Build a balanced, deterministic GT4HistOCR line subset manifest."""
from __future__ import annotations

import argparse
import csv
from pathlib import Path
import random
import re


LANGUAGE_BY_SUBCORPUS = {
    "dta19": "German",
    "EarlyModernLatin": "Latin",
    "Kallimachos": "German/Latin",
    "RefCorpus-ENHG-Incunabula": "German",
    "RIDGES-Fraktur": "German",
}
IMAGE_SUFFIXES = (".nrm.png", ".bin.png", ".png", ".tif", ".tiff")


def strip_gt_suffix(path: Path) -> str:
    name = path.name
    suffix = ".gt.txt"
    if not name.endswith(suffix):
        raise ValueError(
            f"Not a GT4HistOCR transcription file: {path}"
        )
    return name[:-len(suffix)]


def find_image(gt_path: Path) -> Path | None:
    base = strip_gt_suffix(gt_path)
    for suffix in IMAGE_SUFFIXES:
        candidate = gt_path.with_name(base + suffix)
        if candidate.exists():
            return candidate
    return None


def infer_year(document_id: str):
    match = re.search(
        r"(?<!\d)(1[4-9]\d{2})(?!\d)",
        document_id,
    )
    return int(match.group(1)) if match else ""


def scan_pairs(root: Path, require_image: bool = True):
    rows = []

    for gt_path in sorted(root.rglob("*.gt.txt")):
        rel = gt_path.relative_to(root)
        if len(rel.parts) < 2:
            continue

        subcorpus = rel.parts[0]
        document_id = (
            rel.parts[1]
            if len(rel.parts) >= 3
            else subcorpus
        )

        image = find_image(gt_path)
        if image is None and require_image:
            raise ValueError(
                f"No line image found for {gt_path}"
            )

        reference = gt_path.read_text(
            encoding="utf-8-sig"
        ).rstrip("\r\n")

        base = strip_gt_suffix(gt_path)
        line_id = "::".join(
            (*rel.parts[:-1], base)
        )

        rows.append({
            "benchmark": "gt4histocr",
            "subcorpus": subcorpus,
            "corpus_language": (
                LANGUAGE_BY_SUBCORPUS.get(
                    subcorpus,
                    "",
                )
            ),
            "document_id": document_id,
            "year": infer_year(document_id),
            "line_id": line_id,
            "reference": reference,
            "image_path": (
                str(image.relative_to(root))
                if image
                else ""
            ),
            "gt_path": str(rel),
        })

    if not rows:
        raise ValueError(
            f"No *.gt.txt files found under {root}"
        )

    return rows


def balanced_sample(
    rows,
    per_subcorpus: int,
    max_per_document: int,
    seed: int,
):
    rng = random.Random(seed)
    by_subcorpus = {}

    for row in rows:
        by_subcorpus.setdefault(
            row["subcorpus"],
            [],
        ).append(row)

    selected = []

    for subcorpus in sorted(by_subcorpus):
        by_document = {}

        for row in by_subcorpus[subcorpus]:
            by_document.setdefault(
                row["document_id"],
                [],
            ).append(row)

        document_ids = sorted(by_document)
        rng.shuffle(document_ids)

        for document_id in document_ids:
            rng.shuffle(by_document[document_id])

        positions = {
            document_id: 0
            for document_id in document_ids
        }
        used = {
            document_id: 0
            for document_id in document_ids
        }
        chosen = []

        while len(chosen) < per_subcorpus:
            progressed = False

            for document_id in document_ids:
                if len(chosen) >= per_subcorpus:
                    break

                if (
                    used[document_id]
                    >= max_per_document
                ):
                    continue

                pool = by_document[document_id]
                pos = positions[document_id]

                if pos >= len(pool):
                    continue

                chosen.append(pool[pos])
                positions[document_id] += 1
                used[document_id] += 1
                progressed = True

            if not progressed:
                break

        selected.extend(chosen)

    return selected


def write_manifest(rows, output: Path):
    output.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    fields = [
        "benchmark",
        "subcorpus",
        "corpus_language",
        "document_id",
        "year",
        "line_id",
        "reference",
        "image_path",
        "gt_path",
    ]

    with output.open(
        "w",
        encoding="utf-8",
        newline="",
    ) as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=fields,
        )
        writer.writeheader()
        writer.writerows(rows)


def parse_args(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--per-subcorpus",
        type=int,
        default=500,
    )
    parser.add_argument(
        "--max-per-document",
        type=int,
        default=75,
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=2027,
    )
    parser.add_argument(
        "--allow-missing-images",
        action="store_true",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    if args.per_subcorpus < 1:
        raise ValueError(
            "--per-subcorpus must be positive"
        )
    if args.max_per_document < 1:
        raise ValueError(
            "--max-per-document must be positive"
        )

    root = args.root.expanduser()

    rows = scan_pairs(
        root,
        require_image=(
            not args.allow_missing_images
        ),
    )

    selected = balanced_sample(
        rows,
        per_subcorpus=args.per_subcorpus,
        max_per_document=args.max_per_document,
        seed=args.seed,
    )

    write_manifest(
        selected,
        args.output.expanduser(),
    )

    total_by_subcorpus = {}
    selected_by_subcorpus = {}
    docs_by_subcorpus = {}

    for row in rows:
        total_by_subcorpus[row["subcorpus"]] = (
            total_by_subcorpus.get(
                row["subcorpus"],
                0,
            ) + 1
        )

    for row in selected:
        selected_by_subcorpus[row["subcorpus"]] = (
            selected_by_subcorpus.get(
                row["subcorpus"],
                0,
            ) + 1
        )
        docs_by_subcorpus.setdefault(
            row["subcorpus"],
            set(),
        ).add(row["document_id"])

    print(
        f"Discovered line pairs: {len(rows)}"
    )
    print(
        f"Selected lines: {len(selected)}"
    )

    for subcorpus in sorted(total_by_subcorpus):
        print(
            f"  - {subcorpus}: "
            f"{selected_by_subcorpus.get(subcorpus, 0)} "
            "selected / "
            f"{total_by_subcorpus[subcorpus]} "
            "available; "
            f"{len(docs_by_subcorpus.get(subcorpus, set()))} "
            "documents"
        )

    print(
        f"Wrote: {args.output.expanduser()}"
    )


if __name__ == "__main__":
    main()
