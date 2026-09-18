#!/usr/bin/env python3
from __future__ import annotations

import sys
import numpy as np
import pandas as pd


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: compare_parity.py <r.csv> <python.csv>")

    r = pd.read_csv(sys.argv[1])
    py = pd.read_csv(sys.argv[2])

    key = ["line_id", "system", "metric"]
    r = r.sort_values(key).reset_index(drop=True)
    py = py.sort_values(key).reset_index(drop=True)

    if r[key].astype(str).to_dict("records") != py[key].astype(str).to_dict("records"):
        raise AssertionError("R and Python row keys differ")

    integer_cols = [
        "n_reference", "n_hypothesis",
        "substitutions", "deletions", "insertions", "distance",
    ]
    for col in integer_cols:
        if not np.array_equal(r[col].to_numpy(), py[col].to_numpy()):
            raise AssertionError(
                f"R/Python parity failure in {col}:\n"
                f"R={r[col].tolist()}\nPY={py[col].tolist()}"
            )

    if not np.allclose(
        r["rate"].to_numpy(dtype=float),
        py["rate"].to_numpy(dtype=float),
        rtol=1e-12,
        atol=1e-12,
        equal_nan=True,
    ):
        raise AssertionError(
            "R/Python rate parity failure:\n"
            f"R={r['rate'].tolist()}\nPY={py['rate'].tolist()}"
        )

    print(f"Parity OK on {len(r)} evaluated rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
