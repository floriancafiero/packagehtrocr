from __future__ import annotations

from collections.abc import Iterable
from typing import Literal

import pandas as pd

from .core import edit_counts


def _as_list(value):
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    return list(value)


def _rate(distance: int, n_reference: int, insertions: int) -> float:
    if n_reference == 0:
        return 0.0 if insertions == 0 else float(insertions)
    return float(distance) / float(n_reference)


def evaluate_recognition(
    data: pd.DataFrame,
    truth: str,
    prediction: str,
    *,
    id: str | None = None,
    system: str | None = None,
    keep: Iterable[str] | None = None,
    keep_text: bool = True,
    metrics: Iterable[str] = ("cer", "wer"),
    char_unit: Literal["grapheme", "codepoint"] = "grapheme",
    unicode: str = "NFC",
    case: str = "preserve",
    whitespace: str = "preserve",
    punctuation: str = "preserve",
) -> pd.DataFrame:
    if not isinstance(data, pd.DataFrame):
        raise TypeError("data must be a pandas DataFrame")

    metrics = list(dict.fromkeys(metrics))
    if not metrics or any(m not in {"cer", "wer"} for m in metrics):
        raise ValueError("metrics must contain cer and/or wer")

    requested = [truth, prediction] + _as_list(keep)
    if id is not None:
        requested.append(id)
    if system is not None:
        requested.append(system)
    missing = [c for c in requested if c not in data.columns]
    if missing:
        raise ValueError(f"unknown columns: {', '.join(missing)}")

    base_cols = []
    for col in [id, system, *_as_list(keep)]:
        if col is not None and col not in {truth, prediction} and col not in base_cols:
            base_cols.append(col)

    rows: list[dict] = []
    for input_row, (_, source) in enumerate(data.iterrows(), start=1):
        ref = source[truth]
        hyp = source[prediction]
        if pd.isna(ref) or pd.isna(hyp):
            raise ValueError(
                f"missing reference or prediction at input row {input_row}"
            )

        for metric in metrics:
            unit = char_unit if metric == "cer" else "word"
            metric_ws = (
                "collapse"
                if metric == "wer" and whitespace == "preserve"
                else whitespace
            )
            counts = edit_counts(
                str(ref),
                str(hyp),
                unit=unit,
                unicode=unicode,
                case=case,
                whitespace=metric_ws,
                punctuation=punctuation,
            )
            row = {col: source[col] for col in base_cols}
            if keep_text:
                row["reference"] = str(ref)
                row["prediction"] = str(hyp)
            row.update(
                {
                    "input_row": input_row,
                    "metric": metric,
                    "rate": _rate(
                        counts.distance,
                        counts.n_reference,
                        counts.insertions,
                    ),
                    "n_reference": counts.n_reference,
                    "n_hypothesis": counts.n_hypothesis,
                    "substitutions": counts.substitutions,
                    "deletions": counts.deletions,
                    "insertions": counts.insertions,
                    "distance": counts.distance,
                }
            )
            rows.append(row)

    out = pd.DataFrame(rows)
    out.attrs["ocrinfer_policy"] = {
        "char_unit": char_unit,
        "unicode": unicode,
        "case": case,
        "whitespace": whitespace,
        "punctuation": punctuation,
        "keep_text": keep_text,
    }
    return out


def summarize_recognition(
    x: pd.DataFrame,
    *,
    by: Iterable[str] | str | None = None,
    averaging: Literal["micro", "macro"] = "micro",
    unit: str | None = None,
) -> pd.DataFrame:
    required = {
        "metric", "n_reference", "n_hypothesis",
        "substitutions", "deletions", "insertions", "distance", "rate",
    }
    missing = required.difference(x.columns)
    if missing:
        raise ValueError(
            "missing required evaluation columns: " + ", ".join(sorted(missing))
        )
    if averaging not in {"micro", "macro"}:
        raise ValueError("averaging must be micro or macro")

    by_cols = _as_list(by)
    unknown = [c for c in by_cols if c not in x.columns]
    if unknown:
        raise ValueError(f"unknown grouping columns: {', '.join(unknown)}")
    if unit is not None and unit not in x.columns:
        raise ValueError(f"unknown unit column: {unit}")

    group_cols = list(dict.fromkeys([*by_cols, "metric"]))
    rows: list[dict] = []

    grouped = x.groupby(group_cols, dropna=False, sort=False) if group_cols else [((), x)]

    for keys, d in grouped:
        if not isinstance(keys, tuple):
            keys = (keys,)
        meta = dict(zip(group_cols, keys))

        if averaging == "micro":
            ref = int(d["n_reference"].sum())
            ins = int(d["insertions"].sum())
            dist = int(d["distance"].sum())
            row = {
                **meta,
                "averaging": "micro",
                "n_rows": len(d),
                "n_units": pd.NA,
                "n_reference": ref,
                "n_hypothesis": int(d["n_hypothesis"].sum()),
                "substitutions": int(d["substitutions"].sum()),
                "deletions": int(d["deletions"].sum()),
                "insertions": ins,
                "distance": dist,
                "rate": _rate(dist, ref, ins),
            }
        else:
            if unit is None:
                rates = d["rate"].astype(float)
                n_units = len(d)
            else:
                unit_rates = []
                for _, z in d.groupby(unit, dropna=False, sort=False):
                    ref = int(z["n_reference"].sum())
                    ins = int(z["insertions"].sum())
                    dist = int(z["distance"].sum())
                    unit_rates.append(_rate(dist, ref, ins))
                rates = pd.Series(unit_rates, dtype=float)
                n_units = len(unit_rates)

            row = {
                **meta,
                "averaging": "macro",
                "n_rows": len(d),
                "n_units": n_units,
                "n_reference": int(d["n_reference"].sum()),
                "n_hypothesis": int(d["n_hypothesis"].sum()),
                "substitutions": int(d["substitutions"].sum()),
                "deletions": int(d["deletions"].sum()),
                "insertions": int(d["insertions"].sum()),
                "distance": int(d["distance"].sum()),
                "rate": float(rates.mean()) if len(rates) else float("nan"),
            }
        rows.append(row)

    out = pd.DataFrame(rows)
    out.attrs["ocrinfer_policy"] = x.attrs.get("ocrinfer_policy")
    return out


summarise_recognition = summarize_recognition


def normalization_sensitivity(
    data: pd.DataFrame,
    truth: str,
    prediction: str,
    *,
    policies: dict[str, dict],
    id: str | None = None,
    system: str | None = None,
    keep: Iterable[str] | None = None,
    metrics: Iterable[str] = ("cer", "wer"),
    char_unit: str = "grapheme",
    summarize: bool = False,
    by: Iterable[str] | str | None = None,
    averaging: Literal["micro", "macro"] = "micro",
    unit: str | None = None,
) -> pd.DataFrame:
    if not policies:
        raise ValueError("policies must be a non-empty mapping")

    allowed = {"unicode", "case", "whitespace", "punctuation", "char_unit"}
    frames = []
    for name, spec in policies.items():
        unknown = set(spec).difference(allowed)
        if unknown:
            raise ValueError(
                f"unknown settings in policy {name}: {', '.join(sorted(unknown))}"
            )
        settings = {
            "unicode": "NFC",
            "case": "preserve",
            "whitespace": "preserve",
            "punctuation": "preserve",
            "char_unit": char_unit,
            **spec,
        }
        result = evaluate_recognition(
            data,
            truth,
            prediction,
            id=id,
            system=system,
            keep=keep,
            metrics=metrics,
            **settings,
        )
        result["policy"] = name
        for key, value in settings.items():
            result[f"policy_{key}"] = value

        if summarize:
            summary_by = list(dict.fromkeys([*_as_list(by), "policy"]))
            result = summarize_recognition(
                result,
                by=summary_by,
                averaging=averaging,
                unit=unit,
            )
            for key, value in settings.items():
                result[f"policy_{key}"] = value
        frames.append(result)

    return pd.concat(frames, ignore_index=True)
