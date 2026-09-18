# GT4HistOCR benchmark workflow

## Why this benchmark

GT4HistOCR is the planned printed-text counterpoint to CMMHWR26.

It contains 313,173 line-image/transcription pairs drawn from five historical
print subcorpora:

- `dta19`;
- `EarlyModernLatin`;
- `Kallimachos`;
- `RefCorpus-ENHG-Incunabula`;
- `RIDGES-Fraktur`.

The source archive pairs line images with diplomatic `*.gt.txt`
transcriptions preserving historical character forms as far as possible in
Unicode. The five subcorpora use different transcription guidelines, so the
paper must preserve subcorpus identity rather than merge them into one
undifferentiated benchmark.

## Licensing note

There is a discrepancy in the upstream descriptions:

- the accompanying publication/abstract describes the dataset as CC BY 4.0;
- the README shipped in the Zenodo record states **CC BY-SA 4.0**.

For this project, treat the archive as **CC BY-SA 4.0 unless clarified by the
dataset maintainers**. The repository should store manifests and derived model
outputs, not redistribute the 4 GB source corpus.

## 1. Unpack upstream data

The official archive is distributed as `GT4HistOCR.tar`, containing compressed
subcorpora. Follow the upstream README/tesstrain instructions to unpack it until
the tree contains directories such as:

```text
GT4HistOCR/
  dta19/
    1882-keller_sinngedicht/
      04970.gt.txt
      ...
  EarlyModernLatin/
  Kallimachos/
  RefCorpus-ENHG-Incunabula/
  RIDGES-Fraktur/
```

Line images are typically named with suffixes such as `.nrm.png` or
`.bin.png`.

## 2. Freeze a balanced evaluation subset

Do **not** sample uniformly over all 313k lines: `dta19` alone contains roughly
244k lines and would dominate the study.

The default pilot samples up to 500 lines from each subcorpus, with at most 75
lines from any one book:

```bash
python benchmark/gt4histocr/build_subset.py \
  --root /data/GT4HistOCR \
  --per-subcorpus 500 \
  --max-per-document 75 \
  --seed 2027 \
  --output benchmark/gt4histocr/subset_manifest.csv
```

This yields a maximum of roughly 2,500 lines and deliberately spreads samples
across books.

For the final paper, the sample size can be increased after measuring inference
cost, but the selection rule and seed should be frozen before inspecting
model-specific error profiles.

The manifest contains:

```text
benchmark
subcorpus
corpus_language
document_id
year
line_id
reference
image_path
gt_path
```

`corpus_language` is only a coarse subcorpus-level descriptor:
`Kallimachos` is explicitly marked German/Latin rather than assigning a
line-level language without evidence.

## 3. Recognition systems

The goal is not to benchmark models trained directly on these exact lines.

Avoid historical-print checkpoints known to have been trained on the entire
GT4HistOCR collection when claiming out-of-domain generalization.

A useful comparison should include:

1. a conventional OCR baseline not trained on the evaluation lines;
2. MEDUSA 4B/9B as historical-text VLMs evaluated out of their main handwritten
   domain;
3. the same general-purpose VLM used in the CMMHWR26 experiment.

Record model revision, prompt, decoding parameters and software version for every
run.

Prediction output should be a JSON mapping the frozen manifest IDs to text:

```json
{
  "dta19::1882-keller_sinngedicht::04970": "recognized line",
  "EarlyModernLatin::1500-book::00123": "recognized line"
}
```

## 4. Join predictions strictly

```bash
python benchmark/gt4histocr/join_predictions.py \
  --manifest benchmark/gt4histocr/subset_manifest.csv \
  --system tesseract=/predictions/tesseract.json \
  --system medusa4b=/predictions/medusa4b.json \
  --system medusa9b=/predictions/medusa9b.json \
  --system qwen=/predictions/qwen.json \
  --output benchmark/gt4histocr/gt4histocr_predictions.csv
```

Unknown IDs and missing IDs are errors by default. This keeps model comparisons
strictly paired.

## 5. Analysis

The same `ocrinfer` workflow used for CMMHWR26 should be applied:

- micro CER/WER;
- document-level macro CER/WER;
- paired document bootstrap;
- error profiles and span extraction;
- pre-specified normalization-policy sensitivity;
- blinded source-aware fidelity annotation.

For GT4HistOCR, always report/subset results by upstream subcorpus because
transcription conventions differ.

## Why it matters for the CVPR question

CMMHWR26 asks whether the phenomenon appears in historical handwriting.
GT4HistOCR asks whether it persists in historical **print**.

If VLMs show similar source-fidelity interventions in both settings, that is much
stronger evidence that we are measuring a model-family behavior rather than a
quirk of one manuscript benchmark.
