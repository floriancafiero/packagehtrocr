# CMMHWR26 benchmark workflow

This directory turns the public post-competition CMMHWR26 ground truth and
frozen model outputs into the canonical table consumed by `ocrinfer`.

## 1. Ground truth

Use the released CMMHWR26 test set **with transcriptions**. Keep the original
page images and ALTO XML together if possible.

The table builder reads:

- every ALTO `TextLine/@ID`;
- its official `String/@CONTENT` transcription;
- page/document identifiers;
- line bounding box and polygon where available;
- corresponding page image path.

Line geometry is retained specifically so the fidelity-annotation workflow can
show/crop the original visual evidence.

## 2. Produce frozen predictions with DocWorkflow

Existing DocWorkflow configs already cover several relevant systems.

### Kraken / CATMuS baseline

```bash
docworkflow \
  -c configs/cmmhwr/test_compet/kraken_htr.yml \
  predict -t htr -d test
```

Export the ALTO predictions to the competition-style JSON:

```bash
docworkflow \
  -c configs/cmmhwr/test_compet/kraken_htr.yml \
  print -t htr \
  -p results/test_compet_kraken/htr \
  --json
```

The JSON written by DocWorkflow is a mapping:

```json
{
  "line-id-1": "recognized text",
  "line-id-2": "recognized text"
}
```

### Qwen-family VLMs

The repository already contains CMMHWR line-level configs, including:

- `configs/cmmhwr/Qwen8B_linelvl.yml`;
- `configs/cmmhwr/Qwen4B_linelvl.yml`;
- `configs/cmmhwr/Qwen2B_linelvl.yml`;
- fine-tuned Qwen3.5 competition configs under
  `configs/cmmhwr/test_compet/`.

For the CVPR experiment, record the exact config, model revision/checkpoint and
prompt beside every frozen prediction file.

### MEDUSA

Use the public MEDUSA 4B/9B releases in a dedicated inference environment. Do
not silently substitute a local competition checkpoint for a public release:
the paper must distinguish exact model/version provenance.

## 3. Build the canonical table

Example:

```bash
python benchmark/cmmhwr/build_analysis_table.py \
  --gt-root /data/cmmhwr_test_with_transcriptions \
  --system kraken=/predictions/kraken.json \
  --system medusa4b=/predictions/medusa4b.json \
  --system medusa9b=/predictions/medusa9b.json \
  --system qwen=/predictions/qwen.json \
  --output benchmark/cmmhwr/cmmhwr_predictions.csv
```

If images live separately from ALTO:

```bash
  --image-root /data/cmmhwr_images
```

Optional task/language metadata can be joined from a CSV keyed by `line_id`:

```bash
  --metadata benchmark/cmmhwr/line_metadata.csv
```

## 4. Strict pairing is deliberate

By default the builder refuses to continue when:

- a ground-truth line ID occurs twice;
- a system predicts an unknown line ID;
- a system omits any ground-truth line ID;
- two systems are accidentally given the same name.

This prevents apparently paired comparisons from being run over different
material.

`--allow-missing` exists only for diagnostics and should not be used for final
paper comparisons.

## 5. Canonical output

One row per line and system, with at least:

```text
benchmark
document_id
page_id
line_id
system
reference
prediction
image_path
source_xml
hpos
vpos
width
height
polygon
```

plus optional benchmark metadata such as `task` and `language`.

This is the only table the R analysis should need.

## 6. First validation gate

Before source-fidelity analysis:

1. reproduce the official CMMHWR aggregate CER/WER as closely as possible;
2. document the exact competition-compatible normalization policy;
3. check that all systems have identical reference strings and line IDs;
4. freeze predictions and record checksums;
5. only then run micro/macro, paired uncertainty, error-span extraction and
   source-aware annotation.

A discrepancy with the official leaderboard must be explained rather than
normalized away post hoc.
