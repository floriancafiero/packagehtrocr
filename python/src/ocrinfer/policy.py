from __future__ import annotations

from itertools import combinations
from typing import Literal

import numpy as np
import pandas as pd

from .compare import compare_systems
from .core import edit_counts


def policy_swap_summary(
    x: pd.DataFrame,
    *,
    model_col: str = "model",
    condition_col: str = "prompt_condition",
    system_col: str = "system",
    pair_id: str = "line_id",
    unit: str = "document_id",
    metric: Literal["cer", "wer"] = "cer",
    n_boot: int = 2000,
    conf_level: float = 0.95,
    seed: int | None = 2027,
) -> pd.DataFrame:
    required = {
        "metric", "reference", "prediction", "rate",
        model_col, condition_col, system_col, pair_id, unit,
    }
    missing = required.difference(x.columns)
    if missing:
        raise ValueError(
            "missing policy-swap columns: " + ", ".join(sorted(missing))
        )

    d = x[x["metric"].astype(str) == metric].copy()
    rows = []

    def output_distance(a: str, b: str) -> float:
        counts = edit_counts(
            a, b,
            unit="grapheme",
            unicode="NFC",
            case="preserve",
            whitespace="preserve",
            punctuation="preserve",
        )
        denom = max(counts.n_reference, counts.n_hypothesis)
        return 0.0 if denom == 0 else counts.distance / denom

    for model in pd.unique(d[model_col].astype(str)):
        m = d[d[model_col].astype(str) == model].copy()
        conditions = [
            c for c in pd.unique(m[condition_col].astype(str))
            if c and c != "nan"
        ]
        if len(conditions) < 2:
            continue

        system_by_condition = {}
        for condition in conditions:
            values = pd.unique(
                m.loc[
                    m[condition_col].astype(str) == condition,
                    system_col,
                ].astype(str)
            )
            if len(values) != 1:
                raise ValueError(
                    f"model {model} condition {condition} must map to one system"
                )
            system_by_condition[condition] = values[0]

        for condition_a, condition_b in combinations(conditions, 2):
            system_a = system_by_condition[condition_a]
            system_b = system_by_condition[condition_b]

            a = m[m[condition_col].astype(str) == condition_a].copy()
            b = m[m[condition_col].astype(str) == condition_b].copy()

            for z in (a, b):
                if z.duplicated([unit, pair_id]).any():
                    raise ValueError(
                        f"duplicate paired observations for {model}"
                    )

            a["_key"] = list(zip(a[unit].astype(str), a[pair_id].astype(str)))
            b["_key"] = list(zip(b[unit].astype(str), b[pair_id].astype(str)))
            if set(a["_key"]) != set(b["_key"]):
                raise ValueError(
                    f"policy conditions do not cover identical observations for {model}"
                )
            b = b.set_index("_key").loc[a["_key"]].reset_index()

            if a["reference"].astype(str).tolist() != b["reference"].astype(str).tolist():
                raise ValueError(
                    f"reference differs across conditions for {model}"
                )

            changed = (
                a["prediction"].astype(str).to_numpy()
                != b["prediction"].astype(str).to_numpy()
            )
            distances = np.array(
                [
                    output_distance(pa, pb)
                    for pa, pb in zip(
                        a["prediction"].astype(str),
                        b["prediction"].astype(str),
                    )
                ],
                dtype=float,
            )
            delta = b["rate"].to_numpy(dtype=float) - a["rate"].to_numpy(dtype=float)
            tolerance = np.sqrt(np.finfo(float).eps)

            inference = compare_systems(
                m,
                [system_a, system_b],
                unit=unit,
                pair_id=pair_id,
                system_col=system_col,
                estimand="macro",
                n_boot=n_boot,
                conf_level=conf_level,
                seed=seed,
            )
            inference = inference[inference["metric"].astype(str) == metric]
            if len(inference) != 1:
                raise RuntimeError("unexpected comparison result")
            inf = inference.iloc[0]

            rows.append(
                {
                    "model": model,
                    "condition_a": condition_a,
                    "condition_b": condition_b,
                    "system_a": system_a,
                    "system_b": system_b,
                    "metric": metric,
                    "n_lines": len(a),
                    "output_change_rate": float(changed.mean()),
                    "mean_output_distance": float(distances.mean()),
                    "median_output_distance": float(np.median(distances)),
                    "improved_toward_target": float((delta < -tolerance).mean()),
                    "worsened_from_target": float((delta > tolerance).mean()),
                    "unchanged_target_error": float(
                        (np.abs(delta) <= tolerance).mean()
                    ),
                    "mean_line_delta_b_minus_a": float(delta.mean()),
                    "target_difference_b_minus_a": float(
                        inf["difference_b_minus_a"]
                    ),
                    "conf_low": float(inf["conf_low"]),
                    "conf_high": float(inf["conf_high"]),
                    "conf_level": float(inf["conf_level"]),
                    "n_units": int(inf["n_units"]),
                }
            )

    return pd.DataFrame(rows)
