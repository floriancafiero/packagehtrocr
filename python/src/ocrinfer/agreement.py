from __future__ import annotations

import pandas as pd


def fidelity_agreement(
    annotations: pd.DataFrame,
    *,
    id_col: str = "annotation_id",
    annotator_col: str = "annotator",
    label_col: str = "primary_label",
    drop_missing: bool = True,
) -> pd.DataFrame:
    required = {id_col, annotator_col, label_col}
    missing = required.difference(annotations.columns)
    if missing:
        raise ValueError("missing agreement columns: " + ", ".join(sorted(missing)))

    d = annotations[[id_col, annotator_col, label_col]].copy()
    annotators = [
        a for a in pd.unique(d[annotator_col].astype(str))
        if a and a != "nan"
    ]
    if len(annotators) != 2:
        raise ValueError("exactly two annotators are required")

    if d.duplicated([id_col, annotator_col]).any():
        raise ValueError("each annotator may label each item only once")

    wide = d.pivot(index=id_col, columns=annotator_col, values=label_col)
    a = wide.get(annotators[0])
    b = wide.get(annotators[1])

    if drop_missing:
        valid = a.notna() & b.notna() & a.astype("string").ne("") & b.astype("string").ne("")
        a = a[valid].astype(str)
        b = b[valid].astype(str)
    else:
        a = a.fillna("<missing>").astype(str)
        b = b.fillna("<missing>").astype(str)

    n = len(a)
    if n == 0:
        return pd.DataFrame(
            [{
                "n_items": 0,
                "raw_agreement": float("nan"),
                "expected_agreement": float("nan"),
                "cohen_kappa": float("nan"),
            }]
        )

    raw = float((a.to_numpy() == b.to_numpy()).mean())
    labels = sorted(set(a).union(set(b)))
    pa = a.value_counts(normalize=True)
    pb = b.value_counts(normalize=True)
    expected = sum(float(pa.get(label, 0)) * float(pb.get(label, 0)) for label in labels)
    kappa = (
        float("nan")
        if expected == 1.0
        else (raw - expected) / (1.0 - expected)
    )

    return pd.DataFrame(
        [{
            "annotator_a": annotators[0],
            "annotator_b": annotators[1],
            "n_items": n,
            "raw_agreement": raw,
            "expected_agreement": expected,
            "cohen_kappa": kappa,
        }]
    )
