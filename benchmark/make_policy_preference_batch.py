#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("policy_changed_outputs_csv")
    parser.add_argument("output_dir")
    parser.add_argument("--n", type=int, default=300)
    parser.add_argument("--seed", type=int, default=2027)
    args = parser.parse_args()

    if args.n < 1:
        raise ValueError("--n must be positive")

    d = pd.read_csv(args.policy_changed_outputs_csv)
    required = {
        "model", "condition_a", "condition_b", "system_a", "system_b",
        "document_id", "line_id", "reference", "prediction_a", "prediction_b",
        "target_rate_a", "target_rate_b", "target_delta_b_minus_a",
    }
    missing = required.difference(d.columns)
    if missing:
        raise ValueError("missing columns: " + ", ".join(sorted(missing)))

    d = d[
        d["prediction_a"].astype(str).ne(d["prediction_b"].astype(str))
    ].copy()
    if d.empty:
        raise ValueError("no changed outputs are available")

    rng = np.random.default_rng(args.seed)
    strata = ["model", "condition_a", "condition_b"]
    groups = d.groupby(strata, dropna=False, sort=False).indices
    per_group = max(1, args.n // len(groups))

    selected: list[int] = []
    for indices in groups.values():
        indices = np.asarray(indices, dtype=int)
        size = min(len(indices), per_group)
        selected.extend(
            rng.choice(indices, size=size, replace=False).tolist()
        )
    selected = list(dict.fromkeys(selected))

    target = min(args.n, len(d))
    if len(selected) < target:
        remaining = np.setdiff1d(
            np.arange(len(d)),
            np.asarray(selected, dtype=int),
        )
        size = min(len(remaining), target - len(selected))
        selected.extend(
            rng.choice(remaining, size=size, replace=False).tolist()
        )

    if len(selected) > target:
        selected = rng.choice(
            np.asarray(selected, dtype=int),
            size=target,
            replace=False,
        ).tolist()

    selected = rng.permutation(np.asarray(selected, dtype=int))
    sampled = d.iloc[selected].reset_index(drop=True)

    swap = rng.random(len(sampled)) < 0.5
    annotation_id = [
        f"policy_{i:06d}" for i in range(1, len(sampled) + 1)
    ]

    def choose(a, b):
        return np.where(swap, b, a)

    metadata_candidates = [
        "task", "language", "script_type", "century", "page_id",
        "image_path", "source_xml", "hpos", "vpos", "width",
        "height", "polygon",
    ]
    metadata = [
        c for c in metadata_candidates if c in sampled.columns
    ]

    items = pd.DataFrame(
        {
            "annotation_id": annotation_id,
            "document_id": sampled["document_id"],
            "line_id": sampled["line_id"],
            "reference": sampled["reference"],
            "output_A": choose(
                sampled["prediction_a"], sampled["prediction_b"]
            ),
            "output_B": choose(
                sampled["prediction_b"], sampled["prediction_a"]
            ),
            "preferred_output": pd.NA,
            "reason_label": pd.NA,
            "annotator": pd.NA,
            "confidence": pd.NA,
            "notes": pd.NA,
        }
    )
    for col in metadata:
        items[col] = sampled[col]

    key = pd.DataFrame(
        {
            "annotation_id": annotation_id,
            "model": sampled["model"],
            "condition_A": choose(
                sampled["condition_a"], sampled["condition_b"]
            ),
            "condition_B": choose(
                sampled["condition_b"], sampled["condition_a"]
            ),
            "system_A": choose(
                sampled["system_a"], sampled["system_b"]
            ),
            "system_B": choose(
                sampled["system_b"], sampled["system_a"]
            ),
            "target_rate_A": choose(
                sampled["target_rate_a"], sampled["target_rate_b"]
            ),
            "target_rate_B": choose(
                sampled["target_rate_b"], sampled["target_rate_a"]
            ),
            "target_delta_B_minus_A": np.where(
                swap,
                -sampled["target_delta_b_minus_a"].to_numpy(dtype=float),
                sampled["target_delta_b_minus_a"].to_numpy(dtype=float),
            ),
        }
    )

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    items.to_csv(
        output_dir / "policy_preference_items_blinded.csv",
        index=False,
    )
    key.to_csv(
        output_dir / "policy_preference_key_private.csv",
        index=False,
    )
    pd.DataFrame(
        [{
            "source_file": str(
                Path(args.policy_changed_outputs_csv).resolve()
            ),
            "n_available_changed_outputs": len(d),
            "n_annotation_items": len(items),
            "n_models": sampled["model"].nunique(),
            "seed": args.seed,
            "implementation": "python",
        }]
    ).to_csv(
        output_dir / "policy_preference_manifest.csv",
        index=False,
    )
    print(output_dir.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
