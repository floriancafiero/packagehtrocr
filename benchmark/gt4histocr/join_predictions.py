#!/usr/bin/env python3
"""Join a GT4HistOCR subset manifest with frozen line-level predictions."""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def load_manifest(path: Path):
    with path.open(
        "r",
        encoding="utf-8-sig",
        newline="",
    ) as handle:
        rows = list(csv.DictReader(handle))

    if not rows:
        raise ValueError(
            f"Empty manifest: {path}"
        )

    required = {
        "benchmark",
        "subcorpus",
        "document_id",
        "line_id",
        "reference",
        "image_path",
    }

    missing = required - set(rows[0])
    if missing:
        raise ValueError(
            "Manifest missing columns: "
            + ", ".join(sorted(missing))
        )

    ids = [
        row["line_id"]
        for row in rows
    ]

    if len(ids) != len(set(ids)):
        raise ValueError(
            "Manifest line_id values must be unique"
        )

    return rows


def load_system(spec: str):
    if "=" not in spec:
        raise ValueError(
            "System must be "
            "NAME=/path/to/predictions.json"
        )

    name, raw_path = spec.split("=", 1)
    name = name.strip()
    path = Path(raw_path).expanduser()

    if not name:
        raise ValueError(
            "System name cannot be empty"
        )

    if not path.exists():
        raise ValueError(
            f"Prediction file not found: {path}"
        )

    with path.open(
        "r",
        encoding="utf-8",
    ) as handle:
        data = json.load(handle)

    if not isinstance(data, dict):
        raise ValueError(
            f"{path} must contain a JSON object "
            "mapping line_id to text"
        )

    return (
        name,
        path,
        {
            str(key): (
                ""
                if value is None
                else str(value)
            )
            for key, value in data.items()
        },
    )


def join(
    manifest,
    system_specs,
    allow_missing=False,
):
    gt_ids = {
        row["line_id"]
        for row in manifest
    }

    systems = []
    seen_names = set()

    for spec in system_specs:
        name, path, predictions = (
            load_system(spec)
        )

        if name in seen_names:
            raise ValueError(
                f"Duplicate system name: {name}"
            )
        seen_names.add(name)

        pred_ids = set(predictions)
        extra = sorted(pred_ids - gt_ids)
        missing = sorted(gt_ids - pred_ids)

        if extra:
            raise ValueError(
                f"{name}: {len(extra)} unknown "
                f"line IDs; examples: {extra[:5]}"
            )

        if missing and not allow_missing:
            raise ValueError(
                f"{name}: missing {len(missing)} "
                f"lines; examples: {missing[:5]}"
            )

        systems.append(
            (name, path, predictions)
        )

    out = []

    for source in manifest:
        for name, _, predictions in systems:
            row = dict(source)
            row["system"] = name
            row["prediction"] = (
                predictions.get(
                    source["line_id"],
                    "",
                )
            )
            out.append(row)

    return out, systems


def write(rows, output: Path):
    output.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    original = list(rows[0].keys())
    fields = [
        field
        for field in original
        if field not in (
            "system",
            "prediction",
        )
    ]
    fields += [
        "system",
        "prediction",
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
        "--manifest",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--system",
        action="append",
        required=True,
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--allow-missing",
        action="store_true",
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    manifest = load_manifest(
        args.manifest.expanduser()
    )

    rows, systems = join(
        manifest,
        args.system,
        allow_missing=args.allow_missing,
    )

    write(
        rows,
        args.output.expanduser(),
    )

    print(
        f"Manifest lines: {len(manifest)}"
    )
    print(
        f"Systems: {len(systems)}"
    )
    print(
        f"Output rows: {len(rows)}"
    )
    print(
        f"Wrote: {args.output.expanduser()}"
    )


if __name__ == "__main__":
    main()
