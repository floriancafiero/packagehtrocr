from __future__ import annotations

from collections.abc import Iterable

import numpy as np
import pandas as pd

from .diagnostics import extract_error_spans


def fidelity_codebook() -> pd.DataFrame:
    labels = [
        ("visual_misrecognition", "visual_error",
         "Visible source content is transcribed incorrectly without a stronger policy-related interpretation."),
        ("content_omission", "completeness_error",
         "Visible source content required by the target policy is missing."),
        ("hallucinated_addition", "unsupported_generation",
         "Prediction adds content not supported by the visible source or target policy."),
        ("repetition", "unsupported_generation",
         "Prediction duplicates content beyond what appears in the source."),
        ("orthographic_normalization", "policy_intervention",
         "Prediction normalizes a visible historical or non-standard form beyond the target policy."),
        ("linguistic_correction", "policy_intervention",
         "Prediction changes a visible form toward a more probable/correct language form beyond the target policy."),
        ("abbreviation_change", "policy_intervention",
         "Prediction changes abbreviation representation contrary to the target policy."),
        ("segmentation_policy_change", "policy_intervention",
         "Prediction changes token boundaries contrary to the target policy."),
        ("unsupported_completion", "unsupported_generation",
         "Prediction supplies plausible content where visual evidence is insufficient."),
        ("other", "other",
         "Source-aware error not covered by the current taxonomy."),
        ("ambiguous", "ambiguous",
         "Image, reference, or policy does not support a reliable decision."),
    ]
    return pd.DataFrame(
        [
            {
                "label": label,
                "behavior_group": group,
                "definition": definition,
                "requires_image": True,
            }
            for label, group, definition in labels
        ]
    )


def _balanced_sample(
    frame: pd.DataFrame,
    n: int | None,
    strata: list[str],
    rng: np.random.Generator,
) -> pd.DataFrame:
    if n is None or n >= len(frame):
        order = rng.permutation(len(frame))
        return frame.iloc[order].reset_index(drop=True)

    indices = np.arange(len(frame))
    if not strata:
        selected = rng.choice(indices, size=n, replace=False)
        return frame.iloc[rng.permutation(selected)].reset_index(drop=True)

    groups = frame.groupby(strata, dropna=False, sort=False).indices
    per_group = max(1, n // len(groups))
    selected: list[int] = []

    for group_indices in groups.values():
        group_indices = np.asarray(group_indices, dtype=int)
        size = min(len(group_indices), per_group)
        if size:
            selected.extend(
                rng.choice(group_indices, size=size, replace=False).tolist()
            )

    selected = list(dict.fromkeys(selected))

    if len(selected) < n:
        remaining = np.setdiff1d(indices, np.asarray(selected, dtype=int))
        extra_n = min(len(remaining), n - len(selected))
        if extra_n:
            selected.extend(
                rng.choice(remaining, size=extra_n, replace=False).tolist()
            )

    if len(selected) > n:
        selected = rng.choice(
            np.asarray(selected, dtype=int),
            size=n,
            replace=False,
        ).tolist()

    selected = rng.permutation(np.asarray(selected, dtype=int))
    return frame.iloc[selected].reset_index(drop=True)


def prepare_fidelity_annotation(
    x: pd.DataFrame,
    *,
    metric: str = "cer",
    system_col: str = "system",
    id_col: str = "line_id",
    keep: Iterable[str] | None = None,
    strata: Iterable[str] | None = None,
    n: int | None = None,
    context: int = 5,
    seed: int = 1,
    blind: bool = True,
) -> dict[str, pd.DataFrame]:
    keep_cols = list(keep or [])
    strata_cols = list(strata or [])
    metadata = list(dict.fromkeys([system_col, id_col, *keep_cols, *strata_cols]))

    missing = [col for col in metadata if col not in x.columns]
    if missing:
        raise ValueError("unknown annotation columns: " + ", ".join(missing))

    spans = extract_error_spans(
        x,
        metric=metric,
        by=metadata,
        context=context,
    )

    if spans.empty:
        return {
            "items": spans.copy(),
            "key": pd.DataFrame(),
            "codebook": fidelity_codebook(),
        }

    rng = np.random.default_rng(seed)
    sampled = _balanced_sample(spans, n, strata_cols, rng)
    annotation_id = [
        f"ann_{i:06d}" for i in range(1, len(sampled) + 1)
    ]

    key_cols = list(dict.fromkeys([system_col, id_col, *keep_cols, *strata_cols]))
    key = sampled[key_cols + ["input_row", "span_id"]].copy()
    key.insert(0, "annotation_id", annotation_id)
    key = key.rename(
        columns={
            "input_row": "source_input_row",
            "span_id": "source_span_id",
        }
    )

    items = sampled.copy()
    if blind and system_col in items.columns:
        items = items.drop(columns=[system_col])
    items.insert(0, "annotation_id", annotation_id)
    items["primary_label"] = pd.NA
    items["secondary_label"] = pd.NA
    items["annotator"] = pd.NA
    items["confidence"] = pd.NA
    items["notes"] = pd.NA

    return {
        "items": items,
        "key": key,
        "codebook": fidelity_codebook(),
    }


def fidelity_profile(
    annotations: pd.DataFrame,
    *,
    key: pd.DataFrame | None = None,
    by: Iterable[str] | str = "system",
    label_col: str = "primary_label",
    include_unlabelled: bool = False,
) -> pd.DataFrame:
    by_cols = [by] if isinstance(by, str) else list(by)
    if "annotation_id" not in annotations.columns or label_col not in annotations.columns:
        raise ValueError("annotations must contain annotation_id and label column")

    d = annotations.copy()
    if key is not None:
        if "annotation_id" not in key.columns:
            raise ValueError("key must contain annotation_id")
        if key["annotation_id"].duplicated().any():
            raise ValueError("key annotation_id must be unique")
        extra = [
            c for c in key.columns
            if c != "annotation_id" and c not in d.columns
        ]
        d = d.merge(
            key[["annotation_id", *extra]],
            on="annotation_id",
            how="left",
            sort=False,
        )

    missing = [c for c in by_cols if c not in d.columns]
    if missing:
        raise ValueError("unknown grouping columns: " + ", ".join(missing))

    labels = d[label_col].astype("string")
    unlabelled = labels.isna() | labels.fillna("").eq("")
    if include_unlabelled:
        d[label_col] = labels.mask(unlabelled, "unlabelled")
    else:
        d = d.loc[~unlabelled].copy()

    if d.empty:
        return pd.DataFrame(columns=[*by_cols, "label", "n", "proportion"])

    allowed = set(fidelity_codebook()["label"])
    if include_unlabelled:
        allowed.add("unlabelled")
    invalid = set(d[label_col].astype(str)).difference(allowed)
    if invalid:
        raise ValueError("unknown fidelity labels: " + ", ".join(sorted(invalid)))

    counts = (
        d.groupby([*by_cols, label_col], dropna=False, sort=False)
        .size()
        .reset_index(name="n")
        .rename(columns={label_col: "label"})
    )
    if by_cols:
        counts["proportion"] = counts["n"] / counts.groupby(
            by_cols, dropna=False
        )["n"].transform("sum")
    else:
        counts["proportion"] = counts["n"] / counts["n"].sum()

    return counts.sort_values(
        ["proportion", "n"],
        ascending=[False, False],
        kind="stable",
    ).reset_index(drop=True)
