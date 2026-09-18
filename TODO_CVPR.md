# CVPR 2027 — simple to-do list

This is the single operational checklist for the project.

## A. Already prepared

- [x] Define the central question: transcription policy as an experimental variable.
- [x] Review the main overlapping literature and narrow the novelty claim.
- [x] Choose two domains: CMMHWR26 handwriting + GT4HistOCR print.
- [x] Define neutral / matched / conflicting prompts.
- [x] Implement CER/WER, micro/macro summaries and paired document bootstrap.
- [x] Implement policy-swap analysis.
- [x] Implement error-span extraction and fidelity taxonomy.
- [x] Implement blinded A/B policy-preference annotation batches.
- [x] Implement human-preference vs CER disagreement analysis.
- [x] Add one-rule-at-a-time policy ablation prompts.
- [x] Add strict CMMHWR and GT4 analysis-table builders.
- [x] Add automated package and benchmark CI.
- [x] Add source/model revision locking and experiment hashing utilities.

## B. Do now — data and experiment freeze

### 1. Pull the repository

- [ ] Pull the latest `main` branch.
- [ ] Do not edit the primary prompt files after the experiment is frozen.

### 2. Download public datasets

Run:

```bash
bash benchmark/download_public_sources.sh /data/cvpr_ocr
```

Expected:
- CMMHWR26 test with official transcriptions;
- GT4HistOCR source archive;
- checksum verification succeeds.

### 3. Freeze exact model revisions

Run:

```bash
python benchmark/freeze_hf_revisions.py \
  benchmark/cmmhwr/SYSTEMS_POLICY.csv \
  benchmark/cmmhwr/SYSTEMS_POLICY_LOCKED.csv

python benchmark/freeze_hf_revisions.py \
  benchmark/gt4histocr/SYSTEMS_POLICY.csv \
  benchmark/gt4histocr/SYSTEMS_POLICY_LOCKED.csv
```

Then:
- [ ] verify no Hugging Face run still says `TO_FREEZE`;
- [ ] record exact Kraken/CATMuS model file + checksum + DocWorkflow version.

### 4. Freeze GT4HistOCR subset

Run:

```bash
python benchmark/gt4histocr/build_subset.py \
  --root /data/cvpr_ocr/gt4histocr/GT4HistOCR \
  --per-subcorpus 500 \
  --max-per-document 75 \
  --seed 2027 \
  --output benchmark/gt4histocr/subset_manifest.csv
```

Then:
- [ ] inspect only for obvious extraction mistakes;
- [ ] do not resample after seeing model performance.

### 5. Freeze experiment files

Follow:

```text
benchmark/FREEZE_EXPERIMENT.md
```

Then:
- [ ] commit the locked manifests;
- [ ] commit the SHA-256 experiment manifests;
- [ ] note the Git commit SHA.

## C. First GPU run — CMMHWR26 only

Do this before spending compute on GT4HistOCR.

### 6. Run conventional baseline

- [ ] Kraken/CATMuS 1.6 on all CMMHWR26 test lines.
- [ ] Export one JSON: `line_id -> prediction`.
- [ ] Record software/model version.

### 7. Run MEDUSA-4B three times

Same images, weights and decoding. Change only prompt.

- [ ] neutral prompt;
- [ ] CATMuS matched prompt;
- [ ] diplomatic conflicting prompt.

Save three JSON files.

### 8. Run Qwen3-VL-4B three times

Same images, weights and decoding. Change only prompt.

- [ ] neutral prompt;
- [ ] CATMuS matched prompt;
- [ ] diplomatic conflicting prompt.

Save three JSON files.

### 9. Run MEDUSA-9B once initially

- [ ] CATMuS matched prompt only.

Do not run every 9B condition yet. First check whether the 4B policy effect exists.

## D. First analysis gate

### 10. Build one canonical CMMHWR table

Run:

```bash
python benchmark/cmmhwr/build_analysis_table.py \
  --gt-root /data/cvpr_ocr/cmmhwr26 \
  --system kraken_catmus16=/pred/kraken.json \
  --system medusa4b_neutral=/pred/medusa4b_neutral.json \
  --system medusa4b_catmus=/pred/medusa4b_catmus.json \
  --system medusa4b_diplomatic=/pred/medusa4b_diplomatic.json \
  --system qwen4b_neutral=/pred/qwen4b_neutral.json \
  --system qwen4b_catmus=/pred/qwen4b_catmus.json \
  --system qwen4b_diplomatic=/pred/qwen4b_diplomatic.json \
  --system medusa9b_catmus=/pred/medusa9b_catmus.json \
  --output benchmark/cmmhwr/cmmhwr_predictions.csv
```

- [ ] builder finishes with no missing/unknown line IDs.

### 11. Reproduce ordinary benchmark results

Run the existing CMMHWR analysis.

- [ ] check CER/WER against published CMMHWR results where comparable;
- [ ] explain any discrepancy before doing novel analyses;
- [ ] do not tune normalization just to improve agreement.

### 12. Run policy-swap analysis

Run:

```bash
Rscript benchmark/run_policy_swap.R \
  benchmark/cmmhwr/cmmhwr_predictions.csv \
  benchmark/cmmhwr/SYSTEMS_POLICY_LOCKED.csv \
  benchmark/cmmhwr/policy_results
```

Look first at only four quantities:

- [ ] output-change rate: neutral vs matched;
- [ ] output-change rate: conflicting vs matched;
- [ ] paired CER delta;
- [ ] document-bootstrap confidence interval.

## E. Go / no-go decision for the CVPR idea

Continue aggressively if at least one is true:

- [ ] prompt policy changes a substantial fraction of outputs;
- [ ] matched policy moves output measurably toward the target convention;
- [ ] conflicting policy causes coherent opposite changes;
- [ ] MEDUSA and Qwen differ strongly in controllability;
- [ ] ordinary CER hides meaningful source/policy differences.

If essentially nothing changes:
- [ ] stop expanding the CVPR experiment;
- [ ] redirect the framework to ICDAR/R Journal.

## F. Human pilot only after the quantitative gate

### 13. Build 300 blinded A/B items

Run:

```bash
Rscript benchmark/make_policy_preference_batch.R \
  benchmark/cmmhwr/policy_results/policy_changed_outputs.csv \
  benchmark/cmmhwr/policy_annotation_pilot \
  300
```

### 14. Annotate independently

Use:
`annotation/POLICY_PREFERENCE_GUIDELINES.md`

Need:
- [ ] annotator 1 completes all 300;
- [ ] annotator 2 completes all 300 independently;
- [ ] model/prompt identity remains hidden;
- [ ] no adjudication before both finish.

For each item:
- choose A / B / tie / ambiguous;
- choose reason;
- confidence 1–3;
- optional note.

### 15. Analyze pilot

- [ ] compute agreement;
- [ ] unblind prompt conditions;
- [ ] compare human preference with CER preference;
- [ ] inspect the human-vs-CER disagreement cases.

These disagreement cases are prime candidates for paper figures.

## G. Only if CMMHWR is promising — second domain

### 16. Run GT4HistOCR pilot

Use the already frozen subset.

Minimum:
- [ ] MEDUSA-4B neutral;
- [ ] MEDUSA-4B diplomatic matched;
- [ ] MEDUSA-4B CATMuS conflicting;
- [ ] Qwen4B neutral;
- [ ] Qwen4B diplomatic matched;
- [ ] Qwen4B CATMuS conflicting;
- [ ] MEDUSA-9B diplomatic matched.

### 17. Run same policy-swap analysis

- [ ] test whether the same phenomenon appears in historical print;
- [ ] always keep results stratified by GT4 subcorpus.

## H. Policy-factor ablation

Do this on a smaller relevant subset, not the full benchmark.

### 18. Select lines relevant to each rule

Prepare 300–500 lines total containing enough examples of:
- [ ] abbreviations;
- [ ] segmentation choices;
- [ ] allographs;
- [ ] u/v or i/j distinctions;
- [ ] visually uncertain/damaged content.

### 19. Change one instruction at a time

Use prompts under:
`benchmark/prompts/ablation/`

- [ ] base vs preserve abbreviations;
- [ ] base vs modern segmentation;
- [ ] base vs standard allographs;
- [ ] base vs u/i-only;
- [ ] base vs no unsupported completion.

Goal: show that effects are specific to the rule being manipulated.

## I. Paper-ready outputs

Before writing results, produce:

- [ ] Table 1: datasets / models / policies.
- [ ] Table 2: CER/WER micro + macro.
- [ ] Figure 1: experimental design.
- [ ] Figure 2: output-change rate by model/policy.
- [ ] Figure 3: matched-vs-neutral/conflicting paired deltas + bootstrap intervals.
- [ ] Figure 4: human policy preference.
- [ ] Figure 5: human-vs-CER disagreement examples.
- [ ] Figure 6: handwriting vs print comparison.
- [ ] Appendix: one-factor ablations.
- [ ] Appendix: annotation codebook + agreement.
- [ ] Appendix: exact prompts, model SHAs, decoding settings.

## J. Submission milestones

### By 30 September
- [ ] CMMHWR data downloaded and validated.
- [ ] model revisions frozen.
- [ ] 4B CMMHWR policy-swap inference complete.
- [ ] first quantitative go/no-go decision.

### By 15 October
- [ ] human pilot complete.
- [ ] GT4HistOCR experiment complete if CMMHWR is promising.
- [ ] final taxonomy/protocol frozen.

### By 31 October
- [ ] all main figures/tables.
- [ ] full first paper draft.

### 1–9 November
- [ ] reviewer-style stress test.
- [ ] run only justified missing ablations.
- [ ] freeze results.

### 10 November
- [ ] CVPR registration.

### 16 November
- [ ] CVPR submission.
