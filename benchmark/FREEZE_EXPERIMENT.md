# Freeze the experiment before inference

Do this once, immediately before the first paper-producing model run.

## 1. Lock model revisions

```bash
python benchmark/freeze_hf_revisions.py \
  benchmark/cmmhwr/SYSTEMS_POLICY.csv \
  benchmark/cmmhwr/SYSTEMS_POLICY_LOCKED.csv

python benchmark/freeze_hf_revisions.py \
  benchmark/gt4histocr/SYSTEMS_POLICY.csv \
  benchmark/gt4histocr/SYSTEMS_POLICY_LOCKED.csv
```

Check that no Hugging Face model used in an experiment still has
`revision=TO_FREEZE`.

## 2. Freeze benchmark subset

CMMHWR26 uses the full released post-competition test set.

GT4HistOCR:

```bash
python benchmark/gt4histocr/build_subset.py \
  --root /data/GT4HistOCR \
  --per-subcorpus 500 \
  --max-per-document 75 \
  --seed 2027 \
  --output benchmark/gt4histocr/subset_manifest.csv
```

Do not change the subset after seeing model outputs.

## 3. Hash the CMMHWR experiment definition

```bash
python benchmark/hash_experiment_files.py \
  benchmark/cmmhwr/SYSTEMS_POLICY_LOCKED.csv \
  benchmark/prompts/cmmhwr_neutral.txt \
  benchmark/prompts/cmmhwr_catmus.txt \
  benchmark/prompts/cmmhwr_diplomatic.txt \
  > benchmark/cmmhwr/EXPERIMENT_SHA256.txt
```

## 4. Hash the GT4HistOCR experiment definition

```bash
python benchmark/hash_experiment_files.py \
  benchmark/gt4histocr/SYSTEMS_POLICY_LOCKED.csv \
  benchmark/gt4histocr/subset_manifest.csv \
  benchmark/prompts/gt4_neutral.txt \
  benchmark/prompts/gt4_catmus.txt \
  benchmark/prompts/gt4_diplomatic.txt \
  > benchmark/gt4histocr/EXPERIMENT_SHA256.txt
```

## 5. Commit the locked manifests and hashes

The commit immediately before inference is the experiment-definition commit.
Record its Git SHA in the paper notes.

After this point:
- do not edit prompt wording for primary experiments;
- do not change the GT4 subset;
- do not move model revisions;
- do not alter decoding settings without creating a new explicitly named
  experiment.

Exploratory runs may still be done, but they must not silently replace the
pre-specified primary runs.
