# Start here — CVPR experiment

If you only read one file, read this one.

## What is already ready

The repository already contains:
- evaluation code;
- policy-swap analysis;
- CMMHWR and GT4 table builders;
- neutral/matched/conflicting prompts;
- blinded annotation tooling;
- human-vs-CER analysis;
- CI tests;
- experiment-freezing utilities.

## What you need to do first

### 1. Get data

```bash
bash benchmark/download_public_sources.sh /data/cvpr_ocr
```

### 2. Freeze model revisions

```bash
python benchmark/freeze_hf_revisions.py \
  benchmark/cmmhwr/SYSTEMS_POLICY.csv \
  benchmark/cmmhwr/SYSTEMS_POLICY_LOCKED.csv
```

### 3. Freeze the experiment

Follow:
`benchmark/FREEZE_EXPERIMENT.md`

### 4. Run CMMHWR inference

First priority only:
- Kraken/CATMuS baseline;
- MEDUSA-4B × neutral / CATMuS / diplomatic;
- Qwen3-VL-4B × neutral / CATMuS / diplomatic;
- MEDUSA-9B × CATMuS.

Do **not** start with GT4HistOCR or full ablations.

### 5. Build canonical predictions table

Follow:
`benchmark/cmmhwr/README.md`

### 6. Run policy analysis

```bash
Rscript benchmark/run_policy_swap.R \
  benchmark/cmmhwr/cmmhwr_predictions.csv \
  benchmark/cmmhwr/SYSTEMS_POLICY_LOCKED.csv \
  benchmark/cmmhwr/policy_results
```

### 7. Decide whether the CVPR hypothesis is alive

Open:
`benchmark/cmmhwr/policy_results/policy_swap_summary.csv`

The first question is simply:

> Does changing only the transcription instruction materially and coherently
> change the output?

If yes, continue to annotation and GT4HistOCR.

If no, stop spending compute on the CVPR version and redirect to ICDAR/R Journal.

## Full checklist

See:
`TODO_CVPR.md`
