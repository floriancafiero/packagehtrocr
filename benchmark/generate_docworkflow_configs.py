#!/usr/bin/env python3
"""Generate DocWorkflow VLMLineHTR configs from a frozen systems manifest.

The generator deliberately keeps prompt text in separate committed files and
injects it verbatim into YAML block scalars. This makes prompt provenance easy
to audit and avoids hand-editing six nearly identical configs.
"""
from __future__ import annotations

import argparse
import csv
from pathlib import Path


REQUIRED_COLUMNS = {
    "system",
    "model",
    "model_family",
    "prompt_condition",
    "model_id",
    "revision",
    "prompt_file",
}


def load_systems(path: Path):
    with path.open(
        "r",
        encoding="utf-8-sig",
        newline="",
    ) as handle:
        rows = list(csv.DictReader(handle))

    if not rows:
        raise ValueError(
            f"Empty systems manifest: {path}"
        )

    missing = REQUIRED_COLUMNS - set(rows[0])
    if missing:
        raise ValueError(
            "Systems manifest missing columns: "
            + ", ".join(sorted(missing))
        )

    names = [row["system"] for row in rows]
    if len(names) != len(set(names)):
        raise ValueError(
            "System names must be unique"
        )

    return rows


def read_prompt(repo_root: Path, prompt_file: str):
    if not prompt_file:
        return None

    path = (
        repo_root
        / prompt_file
    ).resolve()

    if not path.exists():
        raise ValueError(
            f"Prompt file not found: {path}"
        )

    return path.read_text(
        encoding="utf-8"
    ).rstrip("\r\n")


def yaml_quote(value: str):
    return (
        '"'
        + value
        .replace("\\", "\\\\")
        .replace('"', '\\"')
        + '"'
    )


def indent_block(text: str, spaces: int):
    prefix = " " * spaces
    return "\n".join(
        prefix + line
        for line in text.splitlines()
    )


def build_config(
    row,
    prompt,
    data_root: str,
    output_dir: str,
    batch_size: int,
    max_pixels: int,
):
    if row["prompt_condition"] == "fixed":
        return None

    model_id = row["model_id"]
    if not model_id:
        raise ValueError(
            f"Missing model_id for {row['system']}"
        )
    if prompt is None or not prompt.strip():
        raise ValueError(
            f"Missing prompt for {row['system']}"
        )

    config_lines = [
        f'run_name: {yaml_quote("cvpr_" + row["system"])}',
        f'output_dir: {yaml_quote(output_dir)}',
        'device: "cuda"',
        "use_wandb: false",
        "save_image: true",
        "",
        "data:",
        f"  test: {yaml_quote(data_root)}",
        "",
        "tasks:",
        "  htr:",
        "    type: VLMLineHTR",
        "    config:",
        "      use_metadata: true",
        f"      model_name: {yaml_quote(model_id)}",
        '      device_map: "auto"',
        "      max_new_tokens: 128",
        f"      line_batch_size: {batch_size}",
        f"      max_pixels: {max_pixels}",
    ]

    # MEDUSA public releases are saved as image-to-text checkpoints whose
    # repository name does not contain "qwen" or "vl". Force the generic
    # transformers image-to-text loader instead of relying on name heuristics.
    if model_id.startswith("ENC-PSL/Medusa"):
        config_lines.append(
            '      model_class: "AutoModelForImageTextToText"'
        )

    config_lines.extend([
        "      prompt_template: |",
        indent_block(prompt, 8),
        "",
    ])

    return "\n".join(config_lines)


def generate(
    systems_path: Path,
    repo_root: Path,
    data_root: str,
    output: Path,
    results_dir: str = "results/cvpr_policy",
    batch_size: int = 8,
    max_pixels: int = 401408,
):
    systems = load_systems(
        systems_path
    )
    output.mkdir(
        parents=True,
        exist_ok=True,
    )

    written = []

    for row in systems:
        if row["prompt_condition"] == "fixed":
            continue

        prompt = read_prompt(
            repo_root,
            row["prompt_file"],
        )

        config = build_config(
            row,
            prompt=prompt,
            data_root=data_root,
            output_dir=results_dir,
            batch_size=batch_size,
            max_pixels=max_pixels,
        )

        path = (
            output
            / f"{row['system']}.yml"
        )
        path.write_text(
            config,
            encoding="utf-8",
        )
        written.append(path)

    return written


def parse_args(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--systems",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path("."),
    )
    parser.add_argument(
        "--data-root",
        required=True,
    )
    parser.add_argument(
        "--output",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--results-dir",
        default="results/cvpr_policy",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=8,
    )
    parser.add_argument(
        "--max-pixels",
        type=int,
        default=401408,
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    written = generate(
        systems_path=args.systems.expanduser(),
        repo_root=args.repo_root.expanduser(),
        data_root=args.data_root,
        output=args.output.expanduser(),
        results_dir=args.results_dir,
        batch_size=args.batch_size,
        max_pixels=args.max_pixels,
    )

    print(
        f"Generated DocWorkflow configs: "
        f"{len(written)}"
    )
    for path in written:
        print(f"  - {path}")


if __name__ == "__main__":
    main()
