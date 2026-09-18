# Public source lock

This file records the authoritative public inputs for the CVPR experiment.

## CMMHWR26

- Record: Zenodo 19884972
- DOI: 10.5281/zenodo.19884972
- File: `cmmhwr_test_with_transcriptions.tar.xz`
- Size: approximately 235.9 MB
- Upstream MD5: `b7c4ac7c615700f1d9e31f035297bf93`
- Purpose: primary historical-handwriting benchmark with post-competition ground truth.

The released test material covers the three competition tasks:
Romance languages represented in training/test, unseen Occitan, and Czech
cross-family generalization.

## GT4HistOCR

- Record: Zenodo 1344132
- DOI: 10.5281/zenodo.1344132
- File: `GT4HistOCR.tar`
- Size: approximately 4.0 GB
- Upstream MD5: `3c382e707042ed5f548caf180fec40f8`
- Purpose: historical-print counterpoint with line-image/diplomatic-transcription pairs.

The upstream Zenodo record contains 313,173 line pairs and warns that its
subcorpora use different transcription guidelines. The experiment therefore
keeps subcorpus identity and uses the frozen balanced subset builder.

## Model revisions

Do not leave `TO_FREEZE` in the final experiment manifests.

Resolve exact Hugging Face repository SHAs immediately before the first
inference run:

```bash
python benchmark/freeze_hf_revisions.py \
  benchmark/cmmhwr/SYSTEMS_POLICY.csv \
  benchmark/cmmhwr/SYSTEMS_POLICY_LOCKED.csv

python benchmark/freeze_hf_revisions.py \
  benchmark/gt4histocr/SYSTEMS_POLICY.csv \
  benchmark/gt4histocr/SYSTEMS_POLICY_LOCKED.csv
```

The locked files, not the editable templates, are the provenance manifests for
paper results.

Kraken/CATMuS is not a Hugging Face model in the current manifest and must be
frozen by recording the exact model file/checksum and software version used by
DocWorkflow.
