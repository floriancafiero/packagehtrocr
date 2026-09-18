# ocrinfer — Python implementation

Python companion to the R package in the repository root.

The Python API mirrors the main research workflow:

- Unicode-aware CER/WER;
- row-level evaluation;
- micro/macro aggregation;
- paired document-level bootstrap;
- normalization sensitivity;
- error-span extraction;
- transcription-policy swap analysis.

Install from the repository root:

```bash
pip install -e "python[dev]"
```

Example:

```python
import pandas as pd
from ocrinfer import evaluate_recognition, summarize_recognition

df = pd.DataFrame({
    "line_id": ["l1", "l2"],
    "document_id": ["d1", "d1"],
    "system": ["A", "A"],
    "reference": ["abc", "def"],
    "prediction": ["axc", "def"],
})

evaluated = evaluate_recognition(
    df,
    truth="reference",
    prediction="prediction",
    id="line_id",
    system="system",
    keep=["document_id"],
)

print(summarize_recognition(evaluated, by=["system"], averaging="micro"))
```

The R and Python implementations are intended to agree on the core benchmark
quantities. Cross-language parity tests will be added around frozen fixtures.
