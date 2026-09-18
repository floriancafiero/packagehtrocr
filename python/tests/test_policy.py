import pandas as pd

from ocrinfer import evaluate_recognition, policy_swap_summary


def test_policy_swap_summary():
    df = pd.DataFrame(
        {
            "document_id": ["d1", "d1", "d1", "d1", "d2", "d2", "d2", "d2"],
            "line_id": ["l1", "l1", "l2", "l2"] * 2,
            "system": ["qwen_neutral", "qwen_matched"] * 4,
            "model": ["Qwen"] * 8,
            "prompt_condition": ["neutral", "matched"] * 4,
            "reference": ["abc", "abc", "def", "def"] * 2,
            "prediction": [
                "axc", "abc",
                "def", "def",
                "abc", "abc",
                "dxf", "def",
            ],
        }
    )
    x = evaluate_recognition(
        df,
        truth="reference",
        prediction="prediction",
        id="line_id",
        system="system",
        keep=["document_id", "model", "prompt_condition"],
        metrics=["cer"],
    )
    out = policy_swap_summary(x, metric="cer", n_boot=50, seed=42)

    assert len(out) == 1
    assert out.loc[0, "model"] == "Qwen"
    assert out.loc[0, "output_change_rate"] == 0.5
    assert out.loc[0, "target_difference_b_minus_a"] < 0
