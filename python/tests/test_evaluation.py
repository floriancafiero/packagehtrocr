import math

import pandas as pd

from ocrinfer import evaluate_recognition, summarize_recognition


def test_evaluate_and_micro_summary():
    df = pd.DataFrame(
        {
            "document_id": ["d1", "d1"],
            "line_id": ["l1", "l2"],
            "system": ["A", "A"],
            "reference": ["abc", "def"],
            "prediction": ["axc", "def"],
        }
    )

    x = evaluate_recognition(
        df,
        truth="reference",
        prediction="prediction",
        id="line_id",
        system="system",
        keep=["document_id"],
        metrics=["cer"],
    )

    assert {"reference", "prediction", "rate", "distance"}.issubset(x.columns)
    assert x.attrs["ocrinfer_policy"]["char_unit"] == "grapheme"

    s = summarize_recognition(x, by=["system"], averaging="micro")
    assert math.isclose(float(s.loc[0, "rate"]), 1 / 6)


def test_document_macro_differs_from_micro():
    df = pd.DataFrame(
        {
            "document_id": ["long", "long", "short"],
            "line_id": ["l1", "l2", "l3"],
            "system": ["A", "A", "A"],
            "reference": ["abcdefghij", "abcdefghij", "a"],
            "prediction": ["abcdefghij", "abcdefghij", ""],
        }
    )
    x = evaluate_recognition(
        df,
        truth="reference",
        prediction="prediction",
        id="line_id",
        system="system",
        keep=["document_id"],
        metrics=["cer"],
    )
    micro = summarize_recognition(x, by="system", averaging="micro")
    macro = summarize_recognition(
        x,
        by="system",
        averaging="macro",
        unit="document_id",
    )
    assert float(macro.loc[0, "rate"]) > float(micro.loc[0, "rate"])
