#!/usr/bin/env python3
from __future__ import annotations

import argparse
from itertools import combinations
from pathlib import Path

import pandas as pd

from ocrinfer import (
    evaluate_recognition,
    policy_swap_summary,
    summarize_recognition,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("predictions_csv")
    parser.add_argument("systems_csv")
    parser.add_argument("output_dir")
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    predictions = pd.read_csv(args.predictions_csv)
    systems = pd.read_csv(args.systems_csv)

    required_predictions = {
        "document_id", "line_id", "system", "reference", "prediction"
    }
    required_systems = {
        "system", "model", "model_family", "prompt_policy",
        "prompt_condition", "model_id", "revision", "prompt_file",
    }

    mp = required_predictions.difference(predictions.columns)
    ms = required_systems.difference(systems.columns)
    if mp:
        raise ValueError("predictions missing: " + ", ".join(sorted(mp)))
    if ms:
        raise ValueError("systems manifest missing: " + ", ".join(sorted(ms)))
    if systems["system"].duplicated().any():
        raise ValueError("systems.csv must contain one row per system")

    unknown = set(predictions["system"].astype(str)).difference(
        set(systems["system"].astype(str))
    )
    if unknown:
        raise ValueError("unknown systems: " + ", ".join(sorted(unknown)))

    metadata = systems.copy()
    predictions = predictions.merge(
        metadata,
        on="system",
        how="left",
        validate="many_to_one",
        sort=False,
    )

    if predictions.duplicated(["line_id", "system"]).any():
        raise ValueError("each line_id x system must occur once")

    promptable = predictions[
        predictions["prompt_condition"].astype(str).ne("fixed")
    ]
    for model, d in promptable.groupby("model", sort=False):
        if d["model_id"].dropna().astype(str).nunique() != 1:
            raise ValueError(f"model {model} maps to multiple model_id values")
        if d["revision"].dropna().astype(str).nunique() != 1:
            raise ValueError(f"model {model} maps to multiple revisions")

    keep_candidates = [
        "benchmark", "subcorpus", "task", "language", "corpus_language",
        "script", "script_type", "century", "year", "page_id", "document_id",
        "image_path", "source_xml", "gt_path", "hpos", "vpos", "width",
        "height", "polygon", "model", "model_family", "prompt_policy",
        "prompt_condition", "model_id", "revision", "prompt_file",
    ]
    keep = [
        c for c in keep_candidates
        if c in predictions.columns and c not in {"line_id", "system"}
    ]

    evaluated = evaluate_recognition(
        predictions,
        truth="reference",
        prediction="prediction",
        id="line_id",
        system="system",
        keep=keep,
        metrics=["cer", "wer"],
    )
    evaluated.to_csv(output_dir / "policy_evaluated_lines.csv", index=False)

    group = [
        "model", "model_family", "prompt_condition",
        "prompt_policy", "system",
    ]
    summarize_recognition(
        evaluated, by=group, averaging="micro"
    ).to_csv(output_dir / "policy_summary_micro.csv", index=False)

    summarize_recognition(
        evaluated,
        by=group,
        averaging="macro",
        unit="document_id",
    ).to_csv(
        output_dir / "policy_summary_macro_document.csv",
        index=False,
    )

    policy_frames = []
    for metric in ["cer", "wer"]:
        result = policy_swap_summary(
            evaluated,
            model_col="model",
            condition_col="prompt_condition",
            system_col="system",
            pair_id="line_id",
            unit="document_id",
            metric=metric,
            n_boot=5000,
            conf_level=0.95,
            seed=2027,
        )
        if not result.empty:
            policy_frames.append(result)

    policy = (
        pd.concat(policy_frames, ignore_index=True)
        if policy_frames
        else pd.DataFrame()
    )
    policy.to_csv(output_dir / "policy_swap_summary.csv", index=False)

    # Export changed CER outputs for blinded human preference batches.
    cer = evaluated[evaluated["metric"].astype(str).eq("cer")].copy()
    changed_frames = []

    if not policy.empty:
        for _, comparison in policy[
            policy["metric"].astype(str).eq("cer")
        ].iterrows():
            a = cer[cer["system"].astype(str).eq(str(comparison["system_a"]))].copy()
            b = cer[cer["system"].astype(str).eq(str(comparison["system_b"]))].copy()

            a["_key"] = list(zip(
                a["document_id"].astype(str),
                a["line_id"].astype(str),
            ))
            b["_key"] = list(zip(
                b["document_id"].astype(str),
                b["line_id"].astype(str),
            ))
            if set(a["_key"]) != set(b["_key"]):
                raise ValueError("policy pair is not strictly paired")
            b = b.set_index("_key").loc[a["_key"]].reset_index()

            changed = (
                a["prediction"].astype(str).to_numpy()
                != b["prediction"].astype(str).to_numpy()
            )
            if not changed.any():
                continue

            changed_frames.append(
                pd.DataFrame(
                    {
                        "model": comparison["model"],
                        "condition_a": comparison["condition_a"],
                        "condition_b": comparison["condition_b"],
                        "system_a": comparison["system_a"],
                        "system_b": comparison["system_b"],
                        "document_id": a.loc[changed, "document_id"].to_numpy(),
                        "line_id": a.loc[changed, "line_id"].to_numpy(),
                        "reference": a.loc[changed, "reference"].to_numpy(),
                        "prediction_a": a.loc[changed, "prediction"].to_numpy(),
                        "prediction_b": b.loc[changed, "prediction"].to_numpy(),
                        "target_rate_a": a.loc[changed, "rate"].to_numpy(),
                        "target_rate_b": b.loc[changed, "rate"].to_numpy(),
                        "target_delta_b_minus_a": (
                            b.loc[changed, "rate"].to_numpy()
                            - a.loc[changed, "rate"].to_numpy()
                        ),
                    }
                )
            )

    if changed_frames:
        pd.concat(changed_frames, ignore_index=True).to_csv(
            output_dir / "policy_changed_outputs.csv",
            index=False,
        )

    pd.DataFrame(
        [{
            "predictions_file": str(Path(args.predictions_csv).resolve()),
            "systems_file": str(Path(args.systems_csv).resolve()),
            "n_lines": predictions["line_id"].nunique(),
            "n_systems": predictions["system"].nunique(),
            "n_models": predictions["model"].nunique(),
            "n_policy_rows": len(policy),
            "implementation": "python",
        }]
    ).to_csv(output_dir / "policy_analysis_manifest.csv", index=False)

    print(output_dir.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
