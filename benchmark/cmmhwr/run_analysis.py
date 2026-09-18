#!/usr/bin/env python3
from __future__ import annotations

import argparse
from itertools import combinations
from pathlib import Path

import pandas as pd

from ocrinfer import (
    compare_systems,
    error_profile,
    evaluate_recognition,
    extract_error_spans,
    fidelity_codebook,
    prepare_fidelity_annotation,
    summarize_recognition,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("predictions_csv")
    parser.add_argument("output_dir")
    parser.add_argument("--annotation-n", type=int, default=400)
    args = parser.parse_args()

    input_path = Path(args.predictions_csv)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    d = pd.read_csv(input_path)
    required = {
        "document_id", "page_id", "line_id",
        "system", "reference", "prediction",
    }
    missing = required.difference(d.columns)
    if missing:
        raise ValueError("missing columns: " + ", ".join(sorted(missing)))

    if d.duplicated(["line_id", "system"]).any():
        raise ValueError("each line_id x system must occur exactly once")

    systems = sorted(d["system"].astype(str).unique())
    if len(systems) < 2:
        raise ValueError("at least two systems are required")

    ids0 = set(d.loc[d["system"].astype(str).eq(systems[0]), "line_id"].astype(str))
    ref0 = (
        d.loc[
            d["system"].astype(str).eq(systems[0]),
            ["line_id", "reference"],
        ]
        .assign(line_id=lambda z: z["line_id"].astype(str))
        .sort_values("line_id")
        .reset_index(drop=True)
    )
    for system in systems[1:]:
        z = d[d["system"].astype(str).eq(system)]
        if set(z["line_id"].astype(str)) != ids0:
            raise ValueError(f"system {system} does not cover the same line IDs")
        ref = (
            z[["line_id", "reference"]]
            .assign(line_id=lambda q: q["line_id"].astype(str))
            .sort_values("line_id")
            .reset_index(drop=True)
        )
        if not ref.equals(ref0):
            raise ValueError(f"reference text differs for system {system}")

    metadata_candidates = [
        "benchmark", "task", "language", "script", "script_type", "century",
        "page_id", "document_id", "image_path", "source_xml",
        "hpos", "vpos", "width", "height", "polygon",
    ]
    keep = [
        c for c in metadata_candidates
        if c in d.columns and c not in {"line_id", "system"}
    ]

    evaluated = evaluate_recognition(
        d,
        truth="reference",
        prediction="prediction",
        id="line_id",
        system="system",
        keep=keep,
        metrics=["cer", "wer"],
        char_unit="grapheme",
        unicode="NFC",
        case="preserve",
        whitespace="preserve",
        punctuation="preserve",
    )
    evaluated.to_csv(output_dir / "evaluated_lines.csv", index=False)

    micro = summarize_recognition(
        evaluated, by=["system"], averaging="micro"
    )
    macro = summarize_recognition(
        evaluated,
        by=["system"],
        averaging="macro",
        unit="document_id",
    )
    micro.to_csv(output_dir / "summary_micro.csv", index=False)
    macro.to_csv(output_dir / "summary_macro_document.csv", index=False)

    for stratum in ["task", "language", "script_type", "century"]:
        if stratum in evaluated.columns:
            summary = summarize_recognition(
                evaluated,
                by=["system", stratum],
                averaging="macro",
                unit="document_id",
            )
            summary.to_csv(
                output_dir / f"summary_macro_by_{stratum}.csv",
                index=False,
            )

    pairwise_macro = []
    pairwise_micro = []
    for a, b in combinations(systems, 2):
        pairwise_macro.append(
            compare_systems(
                evaluated,
                [a, b],
                unit="document_id",
                pair_id="line_id",
                estimand="macro",
                n_boot=5000,
                conf_level=0.95,
                seed=2027,
            )
        )
        pairwise_micro.append(
            compare_systems(
                evaluated,
                [a, b],
                unit="document_id",
                pair_id="line_id",
                estimand="micro",
                n_boot=5000,
                conf_level=0.95,
                seed=2027,
            )
        )

    pd.concat(pairwise_macro, ignore_index=True).to_csv(
        output_dir / "pairwise_macro_document.csv", index=False
    )
    pd.concat(pairwise_micro, ignore_index=True).to_csv(
        output_dir / "pairwise_micro.csv", index=False
    )

    profile = error_profile(evaluated, by="system")
    profile.to_csv(output_dir / "error_profile.csv", index=False)

    span_keep = [
        c for c in [
            "system", "line_id", "document_id", "page_id", "task", "language",
            "script_type", "century", "image_path", "source_xml",
            "hpos", "vpos", "width", "height", "polygon",
        ]
        if c in evaluated.columns
    ]
    spans = extract_error_spans(
        evaluated,
        metric="cer",
        by=span_keep,
        context=8,
    )
    spans.to_csv(output_dir / "cer_error_spans.csv", index=False)

    strata = [
        c for c in ["system", "task", "language"]
        if c in evaluated.columns
    ]
    annotation_keep = [
        c for c in [
            "document_id", "page_id", "task", "language", "script_type",
            "century", "image_path", "source_xml",
            "hpos", "vpos", "width", "height", "polygon",
        ]
        if c in evaluated.columns
    ]
    batch = prepare_fidelity_annotation(
        evaluated,
        metric="cer",
        system_col="system",
        id_col="line_id",
        keep=annotation_keep,
        strata=strata,
        n=min(args.annotation_n, len(spans)) if len(spans) else None,
        context=8,
        seed=2027,
        blind=True,
    )
    batch["items"].to_csv(
        output_dir / "annotation_items_blinded.csv", index=False
    )
    batch["key"].to_csv(
        output_dir / "annotation_key_private.csv", index=False
    )
    fidelity_codebook().to_csv(
        output_dir / "fidelity_codebook.csv", index=False
    )

    manifest = pd.DataFrame(
        [{
            "input_file": str(input_path.resolve()),
            "n_rows": len(d),
            "n_lines": d["line_id"].nunique(),
            "n_documents": d["document_id"].nunique(),
            "n_systems": len(systems),
            "systems": ";".join(systems),
            "annotation_n": len(batch["items"]),
            "implementation": "python",
        }]
    )
    manifest.to_csv(output_dir / "analysis_manifest.csv", index=False)
    print(output_dir.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
