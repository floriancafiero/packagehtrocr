from __future__ import annotations

from typing import Literal

import numpy as np
import pandas as pd


def _rate(distance: float, n_reference: float, insertions: float) -> float:
    if n_reference == 0:
        return 0.0 if insertions == 0 else float(insertions)
    return float(distance) / float(n_reference)


def compare_systems(
    x: pd.DataFrame,
    systems: tuple[str, str] | list[str],
    *,
    unit: str,
    pair_id: str,
    system_col: str = "system",
    estimand: Literal["macro", "micro"] = "macro",
    n_boot: int = 2000,
    conf_level: float = 0.95,
    seed: int | None = None,
) -> pd.DataFrame:
    if len(systems) != 2 or systems[0] == systems[1]:
        raise ValueError("systems must name exactly two distinct levels")
    if estimand not in {"macro", "micro"}:
        raise ValueError("estimand must be macro or micro")
    if n_boot < 1:
        raise ValueError("n_boot must be positive")
    if not 0 < conf_level < 1:
        raise ValueError("conf_level must lie strictly between 0 and 1")

    required = {
        "metric", "reference", "n_reference", "n_hypothesis",
        "substitutions", "deletions", "insertions", "distance",
        unit, pair_id, system_col,
    }
    missing = required.difference(x.columns)
    if missing:
        raise ValueError(
            "missing required evaluation columns: " + ", ".join(sorted(missing))
        )

    rng = np.random.default_rng(seed)
    result_rows = []

    for metric in pd.unique(x["metric"].astype(str)):
        d = x[
            (x["metric"].astype(str) == metric)
            & x[system_col].astype(str).isin(systems)
        ].copy()

        a = d[d[system_col].astype(str) == systems[0]].copy()
        b = d[d[system_col].astype(str) == systems[1]].copy()

        for z in (a, b):
            if z.duplicated([unit, pair_id]).any():
                raise ValueError(
                    f"each unit + pair_id must occur once per system for {metric}"
                )

        a["_key"] = list(zip(a[unit].astype(str), a[pair_id].astype(str)))
        b["_key"] = list(zip(b[unit].astype(str), b[pair_id].astype(str)))

        if set(a["_key"]) != set(b["_key"]):
            raise ValueError(
                f"systems are not evaluated on the same observations for {metric}"
            )

        b = b.set_index("_key").loc[a["_key"]].reset_index()

        if a["reference"].astype(str).tolist() != b["reference"].astype(str).tolist():
            raise ValueError(
                f"reference texts differ between systems for {metric}"
            )
        if not np.array_equal(
            a["n_reference"].to_numpy(),
            b["n_reference"].to_numpy(),
        ):
            raise ValueError(
                f"reference lengths differ between systems for {metric}"
            )

        def aggregate_units(z: pd.DataFrame) -> pd.DataFrame:
            rows = []
            for unit_value, g in z.groupby(unit, dropna=False, sort=False):
                ref = int(g["n_reference"].sum())
                ins = int(g["insertions"].sum())
                dist = int(g["distance"].sum())
                rows.append(
                    {
                        "unit_value": unit_value,
                        "n_reference": ref,
                        "insertions": ins,
                        "distance": dist,
                        "rate": _rate(dist, ref, ins),
                    }
                )
            return pd.DataFrame(rows)

        au = aggregate_units(a)
        bu = aggregate_units(b).set_index("unit_value").loc[
            au["unit_value"]
        ].reset_index()

        def estimate(tab: pd.DataFrame, idx: np.ndarray | None = None) -> float:
            if idx is None:
                selected = tab
            else:
                selected = tab.iloc[idx]
            if estimand == "macro":
                return float(selected["rate"].mean())
            ref = selected["n_reference"].sum()
            ins = selected["insertions"].sum()
            dist = selected["distance"].sum()
            return _rate(dist, ref, ins)

        est_a = estimate(au)
        est_b = estimate(bu)
        observed = est_b - est_a

        n_units = len(au)
        boot = np.empty(n_boot, dtype=float)
        for i in range(n_boot):
            sampled = rng.integers(0, n_units, size=n_units)
            boot[i] = estimate(bu, sampled) - estimate(au, sampled)

        alpha = (1.0 - conf_level) / 2.0
        low, high = np.quantile(boot, [alpha, 1.0 - alpha])

        result_rows.append(
            {
                "metric": metric,
                "system_a": systems[0],
                "system_b": systems[1],
                "estimand": estimand,
                "estimate_a": est_a,
                "estimate_b": est_b,
                "difference_b_minus_a": observed,
                "conf_low": float(low),
                "conf_high": float(high),
                "conf_level": conf_level,
                "n_units": n_units,
                "n_boot": int(n_boot),
            }
        )

    out = pd.DataFrame(result_rows)
    out.attrs["ocrinfer_policy"] = x.attrs.get("ocrinfer_policy")
    return out
