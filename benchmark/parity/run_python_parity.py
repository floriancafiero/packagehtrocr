#!/usr/bin/env python3
from __future__ import annotations

import sys
import pandas as pd

from ocrinfer import evaluate_recognition


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: run_python_parity.py <output.csv>")

    d = pd.read_csv("inst/extdata/toy_recognition.csv")
    x = evaluate_recognition(
        d,
        truth="reference",
        prediction="prediction",
        id="line_id",
        system="system",
        keep=["document_id"],
        metrics=["cer", "wer"],
    )

    cols = [
        "line_id", "system", "metric", "rate",
        "n_reference", "n_hypothesis",
        "substitutions", "deletions", "insertions", "distance",
    ]
    out = x[cols].sort_values(
        ["line_id", "system", "metric"],
        kind="stable",
    )
    out.to_csv(sys.argv[1], index=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
