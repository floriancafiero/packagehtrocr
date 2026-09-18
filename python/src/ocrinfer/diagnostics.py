from __future__ import annotations

from collections.abc import Iterable

import pandas as pd

from .core import align_text


def _policy(x: pd.DataFrame) -> dict:
    return x.attrs.get("ocrinfer_policy") or {}


def confusion_table(
    x: pd.DataFrame,
    *,
    metric: str = "cer",
    by: Iterable[str] | str | None = None,
    include_equal: bool = False,
    epsilon: str = "<eps>",
) -> pd.DataFrame:
    if metric not in {"cer", "wer"}:
        raise ValueError("metric must be cer or wer")
    by_cols = [] if by is None else ([by] if isinstance(by, str) else list(by))
    required = {"metric", "reference", "prediction", *by_cols}
    missing = required.difference(x.columns)
    if missing:
        raise ValueError("missing columns: " + ", ".join(sorted(missing)))

    policy = _policy(x)
    char_unit = policy.get("char_unit", "grapheme")
    whitespace = policy.get("whitespace", "preserve")
    align_ws = "collapse" if metric == "wer" and whitespace == "preserve" else whitespace

    rows = []
    d = x[x["metric"].astype(str) == metric]
    for _, source in d.iterrows():
        alignment = align_text(
            str(source["reference"]),
            str(source["prediction"]),
            unit=char_unit if metric == "cer" else "word",
            unicode=policy.get("unicode", "NFC"),
            case=policy.get("case", "preserve"),
            whitespace=align_ws,
            punctuation=policy.get("punctuation", "preserve"),
        )
        for item in alignment:
            if not include_equal and item.operation == "equal":
                continue
            row = {col: source[col] for col in by_cols}
            row.update(
                {
                    "reference_token": epsilon if item.reference is None else item.reference,
                    "prediction_token": epsilon if item.hypothesis is None else item.hypothesis,
                    "operation": item.operation,
                }
            )
            rows.append(row)

    if not rows:
        return pd.DataFrame(
            columns=[*by_cols, "reference_token", "prediction_token", "operation", "n"]
        )

    raw = pd.DataFrame(rows)
    group_cols = [*by_cols, "reference_token", "prediction_token", "operation"]
    out = (
        raw.groupby(group_cols, dropna=False, sort=False)
        .size()
        .reset_index(name="n")
        .sort_values("n", ascending=False, kind="stable")
        .reset_index(drop=True)
    )
    return out


def error_profile(
    x: pd.DataFrame,
    *,
    by: Iterable[str] | str | None = None,
) -> pd.DataFrame:
    by_cols = [] if by is None else ([by] if isinstance(by, str) else list(by))
    required = {
        "metric", "n_reference", "substitutions",
        "deletions", "insertions", "distance", *by_cols,
    }
    missing = required.difference(x.columns)
    if missing:
        raise ValueError("missing columns: " + ", ".join(sorted(missing)))

    group_cols = [*by_cols, "metric"]
    rows = []
    for keys, d in x.groupby(group_cols, dropna=False, sort=False):
        if not isinstance(keys, tuple):
            keys = (keys,)
        meta = dict(zip(group_cols, keys))
        ref = int(d["n_reference"].sum())
        sub = int(d["substitutions"].sum())
        delete = int(d["deletions"].sum())
        insert = int(d["insertions"].sum())
        dist = int(d["distance"].sum())

        def rate(value: int) -> float:
            return float("nan") if ref == 0 else value / ref

        rows.append(
            {
                **meta,
                "n_rows": len(d),
                "n_reference": ref,
                "substitutions": sub,
                "deletions": delete,
                "insertions": insert,
                "distance": dist,
                "substitution_rate": rate(sub),
                "deletion_rate": rate(delete),
                "insertion_rate": rate(insert),
                "error_rate": (
                    0.0 if ref == 0 and insert == 0
                    else float(insert) if ref == 0
                    else dist / ref
                ),
            }
        )

    out = pd.DataFrame(rows)
    out.attrs["ocrinfer_policy"] = x.attrs.get("ocrinfer_policy")
    return out


def extract_error_spans(
    x: pd.DataFrame,
    *,
    metric: str = "cer",
    by: Iterable[str] | str | None = None,
    context: int = 5,
) -> pd.DataFrame:
    if metric not in {"cer", "wer"}:
        raise ValueError("metric must be cer or wer")
    if context < 0:
        raise ValueError("context must be non-negative")

    by_cols = [] if by is None else ([by] if isinstance(by, str) else list(by))
    required = {"metric", "reference", "prediction", "input_row", *by_cols}
    missing = required.difference(x.columns)
    if missing:
        raise ValueError("missing columns: " + ", ".join(sorted(missing)))

    policy = _policy(x)
    char_unit = policy.get("char_unit", "grapheme")
    whitespace = policy.get("whitespace", "preserve")
    align_ws = "collapse" if metric == "wer" and whitespace == "preserve" else whitespace
    sep = " " if metric == "wer" else ""

    def collapse(tokens):
        return sep.join(token for token in tokens if token is not None)

    rows = []
    d = x[x["metric"].astype(str) == metric]

    for _, source in d.iterrows():
        alignment = align_text(
            str(source["reference"]),
            str(source["prediction"]),
            unit=char_unit if metric == "cer" else "word",
            unicode=policy.get("unicode", "NFC"),
            case=policy.get("case", "preserve"),
            whitespace=align_ws,
            punctuation=policy.get("punctuation", "preserve"),
        )
        if not alignment or all(a.operation == "equal" for a in alignment):
            continue

        ref_pos = []
        hyp_pos = []
        r = h = 0
        for a in alignment:
            if a.reference is not None:
                r += 1
            if a.hypothesis is not None:
                h += 1
            ref_pos.append(r)
            hyp_pos.append(h)

        error_indices = [i for i, a in enumerate(alignment) if a.operation != "equal"]
        runs = []
        start = prev = error_indices[0]
        for idx in error_indices[1:]:
            if idx == prev + 1:
                prev = idx
            else:
                runs.append((start, prev))
                start = prev = idx
        runs.append((start, prev))

        for span_id, (start, end) in enumerate(runs, start=1):
            part = alignment[start:end + 1]
            ops = [a.operation for a in part]
            operation = ops[0] if len(set(ops)) == 1 else "mixed"

            ref_positions = [
                ref_pos[i] for i in range(start, end + 1)
                if alignment[i].reference is not None
            ]
            hyp_positions = [
                hyp_pos[i] for i in range(start, end + 1)
                if alignment[i].hypothesis is not None
            ]

            inserted = [a.hypothesis for a in part if a.hypothesis is not None]
            possible_repetition = False
            if ops and all(op == "insertion" for op in ops) and inserted:
                k = len(inserted)
                before = [
                    a.hypothesis for a in alignment[:start]
                    if a.hypothesis is not None
                ]
                after = [
                    a.hypothesis for a in alignment[end + 1:]
                    if a.hypothesis is not None
                ]
                possible_repetition = (
                    (len(before) >= k and before[-k:] == inserted)
                    or (len(after) >= k and after[:k] == inserted)
                )

            before_tokens = [
                (a.reference if a.reference is not None else a.hypothesis)
                for a in alignment[max(0, start - context):start]
            ]
            after_tokens = [
                (a.reference if a.reference is not None else a.hypothesis)
                for a in alignment[end + 1:end + 1 + context]
            ]

            row = {col: source[col] for col in by_cols}
            row.update(
                {
                    "input_row": int(source["input_row"]),
                    "span_id": span_id,
                    "operation": operation,
                    "operations": "+".join(ops),
                    "reference_span": collapse([a.reference for a in part]),
                    "prediction_span": collapse([a.hypothesis for a in part]),
                    "reference_start": min(ref_positions) if ref_positions else pd.NA,
                    "reference_end": max(ref_positions) if ref_positions else pd.NA,
                    "prediction_start": min(hyp_positions) if hyp_positions else pd.NA,
                    "prediction_end": max(hyp_positions) if hyp_positions else pd.NA,
                    "substitutions": ops.count("substitution"),
                    "deletions": ops.count("deletion"),
                    "insertions": ops.count("insertion"),
                    "context_before": collapse(before_tokens),
                    "context_after": collapse(after_tokens),
                    "possible_repetition": possible_repetition,
                    "reference": str(source["reference"]),
                    "prediction": str(source["prediction"]),
                }
            )
            rows.append(row)

    out = pd.DataFrame(rows)
    out.attrs["ocrinfer_policy"] = x.attrs.get("ocrinfer_policy")
    return out
