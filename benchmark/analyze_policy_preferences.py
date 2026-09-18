#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
import pandas as pd


def wilson(successes: int, n: int, z: float = 1.959963984540054) -> tuple[float, float]:
    if n == 0:
        return (float("nan"), float("nan"))
    p = successes / n
    denom = 1 + z * z / n
    center = (p + z * z / (2 * n)) / denom
    half = (
        z
        * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
        / denom
    )
    return max(0.0, center - half), min(1.0, center + half)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("completed_items_csv")
    parser.add_argument("private_key_csv")
    parser.add_argument("output_dir")
    args = parser.parse_args()

    items = pd.read_csv(args.completed_items_csv)
    key = pd.read_csv(args.private_key_csv)

    required_items = {
        "annotation_id", "preferred_output", "annotator", "confidence"
    }
    required_key = {
        "annotation_id", "model", "condition_A", "condition_B",
        "target_rate_A", "target_rate_B", "target_delta_B_minus_A",
    }
    mi = required_items.difference(items.columns)
    mk = required_key.difference(key.columns)
    if mi:
        raise ValueError("items missing: " + ", ".join(sorted(mi)))
    if mk:
        raise ValueError("key missing: " + ", ".join(sorted(mk)))
    if key["annotation_id"].duplicated().any():
        raise ValueError("private key annotation IDs must be unique")

    valid = {"A", "B", "tie", "ambiguous"}
    items = items[
        items["preferred_output"].notna()
        & items["preferred_output"].astype(str).ne("")
    ].copy()
    invalid = set(items["preferred_output"].astype(str)).difference(valid)
    if invalid:
        raise ValueError(
            "unknown preferred_output labels: " + ", ".join(sorted(invalid))
        )

    d = items.merge(
        key,
        on="annotation_id",
        how="left",
        validate="many_to_one",
        sort=False,
    )
    if d["model"].isna().any():
        raise ValueError("some annotations are absent from the private key")

    d["preferred_condition"] = np.where(
        d["preferred_output"].eq("A"),
        d["condition_A"],
        np.where(
            d["preferred_output"].eq("B"),
            d["condition_B"],
            d["preferred_output"],
        ),
    )

    tolerance = math.sqrt(np.finfo(float).eps)
    delta = d["target_delta_B_minus_A"].to_numpy(dtype=float)
    d["cer_preferred_output"] = np.where(
        delta < -tolerance,
        "B",
        np.where(delta > tolerance, "A", "tie"),
    )

    d["human_cer_relation"] = np.select(
        [
            d["preferred_output"].eq("ambiguous"),
            d["preferred_output"].eq(d["cer_preferred_output"]),
            d["preferred_output"].eq("tie")
            | d["cer_preferred_output"].eq("tie"),
        ],
        ["ambiguous", "agree", "one_tie"],
        default="disagree",
    )

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    d.to_csv(
        output_dir / "policy_preferences_unblinded.csv",
        index=False,
    )

    summaries = []
    d["condition_pair"] = d.apply(
        lambda row: " vs ".join(
            sorted([str(row["condition_A"]), str(row["condition_B"])])
        ),
        axis=1,
    )

    for (model, pair), z in d.groupby(
        ["model", "condition_pair"], sort=False
    ):
        conditions = sorted(
            set(z["condition_A"].astype(str))
            | set(z["condition_B"].astype(str))
        )
        if len(conditions) != 2:
            raise ValueError("summary group must contain two conditions")

        decisive = z["preferred_condition"].isin(conditions)
        n_decisive = int(decisive.sum())
        p1 = int(z["preferred_condition"].eq(conditions[0]).sum())
        p2 = int(z["preferred_condition"].eq(conditions[1]).sum())
        low, high = wilson(p1, n_decisive)

        both_decisive = (
            z["preferred_output"].isin(["A", "B"])
            & z["cer_preferred_output"].isin(["A", "B"])
        )
        agreement = (
            float(
                (
                    z.loc[both_decisive, "preferred_output"]
                    == z.loc[both_decisive, "cer_preferred_output"]
                ).mean()
            )
            if both_decisive.any()
            else float("nan")
        )

        summaries.append(
            {
                "model": model,
                "condition_1": conditions[0],
                "condition_2": conditions[1],
                "n_labelled": len(z),
                "n_decisive": n_decisive,
                "n_tie": int(z["preferred_output"].eq("tie").sum()),
                "n_ambiguous": int(
                    z["preferred_output"].eq("ambiguous").sum()
                ),
                "condition_1_preferred": p1,
                "condition_2_preferred": p2,
                "condition_1_preference_rate": (
                    p1 / n_decisive if n_decisive else float("nan")
                ),
                "condition_1_wilson_low": low,
                "condition_1_wilson_high": high,
                "human_vs_cer_agreement": agreement,
                "n_human_cer_disagreements": int(
                    z["human_cer_relation"].eq("disagree").sum()
                ),
            }
        )

    pd.DataFrame(summaries).to_csv(
        output_dir / "policy_preference_summary.csv",
        index=False,
    )

    (
        d.groupby(["model", "human_cer_relation"], dropna=False)
        .size()
        .reset_index(name="n")
        .to_csv(
            output_dir / "human_vs_cer_relation.csv",
            index=False,
        )
    )

    d[d["human_cer_relation"].eq("disagree")].to_csv(
        output_dir / "human_cer_disagreement_cases.csv",
        index=False,
    )
    print(output_dir.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
