import math

import pandas as pd

from ocrinfer import compare_systems, evaluate_recognition


def make_evaluated():
    df = pd.DataFrame(
        {
            "document_id": [
                "d1", "d1", "d1", "d1",
                "d2", "d2", "d2", "d2",
            ],
            "line_id": ["l1", "l2", "l1", "l2"] * 2,
            "system": ["A", "A", "B", "B"] * 2,
            "reference": ["abcdefghij", "klmnopqrst", "abcdefghij", "klmnopqrst"] * 2,
            "prediction": [
                "abxxefghij", "klxxopqrst",  # A d1: .2, .2
                "abxdefghij", "klmnopqrst",  # B d1: .1, 0
                "xxxxefghij", "klxxopqrst",  # A d2: .4, .2
                "abxxefghij", "klxmnopqrs",  # B d2: .2, .2
            ],
        }
    )
    return evaluate_recognition(
        df,
        truth="reference",
        prediction="prediction",
        id="line_id",
        system="system",
        keep=["document_id"],
        metrics=["cer"],
    )


def test_compare_systems_paired_macro():
    x = make_evaluated()
    out = compare_systems(
        x,
        ["A", "B"],
        unit="document_id",
        pair_id="line_id",
        estimand="macro",
        n_boot=200,
        seed=1,
    )

    assert len(out) == 1
    assert out.loc[0, "difference_b_minus_a"] < 0
    assert out.loc[0, "n_units"] == 2


def test_compare_rejects_changed_reference():
    x = make_evaluated()
    idx = x["system"].eq("B").idxmax()
    x.loc[idx, "reference"] = "different"
    try:
        compare_systems(
            x,
            ["A", "B"],
            unit="document_id",
            pair_id="line_id",
            n_boot=10,
        )
    except ValueError as exc:
        assert "reference" in str(exc).lower()
    else:
        raise AssertionError("expected mismatched reference error")
