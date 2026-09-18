import pandas as pd

from ocrinfer import (
    evaluate_recognition,
    fidelity_agreement,
    prepare_fidelity_annotation,
)


def test_blinded_annotation_batch():
    df = pd.DataFrame(
        {
            "document_id": ["d1", "d1"],
            "line_id": ["l1", "l2"],
            "system": ["A", "A"],
            "reference": ["abc", "def"],
            "prediction": ["axc", "dxf"],
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
    batch = prepare_fidelity_annotation(
        x,
        keep=["document_id"],
        n=2,
        seed=1,
        blind=True,
    )
    assert len(batch["items"]) == 2
    assert "system" not in batch["items"].columns
    assert "system" in batch["key"].columns


def test_kappa_perfect_agreement():
    annotations = pd.DataFrame(
        {
            "annotation_id": ["a", "b", "a", "b"],
            "annotator": ["x", "x", "y", "y"],
            "primary_label": [
                "visual_misrecognition",
                "content_omission",
                "visual_misrecognition",
                "content_omission",
            ],
        }
    )
    out = fidelity_agreement(annotations)
    assert out.loc[0, "raw_agreement"] == 1.0
    assert out.loc[0, "cohen_kappa"] == 1.0
