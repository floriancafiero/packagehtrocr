# CVPR novelty matrix

This file is intentionally conservative. It records what prior work already
covers so the paper does not claim novelty that is not there.

| Prior work | What it already establishes | Overlap with us | What remains different |
|---|---|---|---|
| Paired Model Evaluation of OCR Algorithms (Kanungo et al., 1998/1999) | Paired comparisons and confidence intervals for OCR systems evaluated on the same documents | Paired system comparison | We use this as statistical precedent; not a novelty claim |
| CLEval (CVPRW 2020) | Fine-grained character-level OCR/text recognition evaluation | Character-level alignment and diagnosis | We do not claim character-level diagnosis as new |
| End-to-End Page-Level Assessment of HTR (2023) | Separates recognition quality and reading-order quality | Multi-level document evaluation | Our target is source fidelity in visual transcription, not page ordering |
| DISGO (2023) | Deletion/insertion/substitution/grouping/ordering decomposition | Error decomposition | We add source-aware classes that require comparison to visual evidence |
| OCRBench / OCRBench v2 | Broad LMM OCR capability benchmarking | VLM OCR evaluation | We do not aim to be a broader task benchmark |
| CC-OCR (2024) | Broad OCR-centric LMM benchmark; documents repetition hallucination | VLM failure analysis | We focus on *why a transcription differs from visible text*, with paired source-aware annotation |
| OHRBench (2024) | Semantic vs formatting noise and downstream RAG effects | Beyond-CER evaluation | We evaluate transcription fidelity itself rather than downstream utility |
| Levchenko (LM4DH 2025) | Historical OCR framework for 18th-c. Russian; HCPR/AIR; contamination and stability; over-historicization | Extremely close motivation: diplomatic fidelity and temporal bias | Their fidelity metrics are character-inventory- and period-specific. We target language/script-independent source-grounded error attribution across model families and domains |
| SCORE (2025) | Multidimensional semantic evaluation for generative document parsing, including hallucination/omission | Generative document evaluation | SCORE accepts semantically equivalent structural realizations; transcription fidelity may require preserving visually attested non-standard forms |
| OCR-Critic / OCR-ERROR (2025) | Fine-grained OCR error detection/categorization using multimodal critical feedback | Error taxonomy | Our task is benchmark evaluation of recognition outputs and source fidelity, not training an error critic |
| FinCriticalED (2025) | Fact-level OCR/VLM correctness in financial documents | Importance-weighted/semantic error analysis | Domain-critical factual correctness is distinct from literal source transcription |
| HIPE-OCRepair 2026 | cMER/wMER, micro/macro aggregation, confidence intervals, preference vs raw OCR; documents over-correction | Statistical evaluation and over-correction | Text-only post-correction without source images, retrieval-oriented normalization; we use image evidence to distinguish misreading from correction/normalization/completion |
| When Good OCR Is Not Enough (ACL 2026) | CER/WER do not fully predict downstream RAG utility | Limits of scalar OCR metrics | Our outcome is source fidelity, not RAG performance |

## The novelty claim we should defend

The paper should make a narrower claim than "the first fidelity-aware OCR
evaluation framework."

A defensible formulation is:

> We introduce a **source-grounded error attribution protocol for visual
> transcription** that separates visually unsupported or language-prior
> transformations from ordinary recognition errors, and use it to compare
> specialized recognizers and generative VLMs under the same images and ground
> truth.

Three properties matter together:

1. **Source-grounded:** difficult labels are assigned with the image visible,
   not from reference/prediction strings alone.
2. **General:** categories are not tied to one language-specific inventory such
   as a predefined list of historical Russian characters.
3. **Comparative:** the same source lines are recognized by model families with
   different inductive biases, so error composition can be compared directly.

The statistical robustness layer (micro/macro, paired intervals, policy
sensitivity) supports the evaluation but is not itself the headline novelty.

## Strong empirical result needed

The paper becomes compelling if we can demonstrate at least one of:

- similar CER/WER but substantially different source-grounded error profiles;
- a model that improves edit distance while increasing normalization/correction
  or unsupported-generation errors;
- conclusions that change under a defensible transcription-fidelity criterion;
- a recurring model-family pattern that appears in both handwriting and print.

Without such a result, the framework alone is unlikely to be strong enough for
CVPR main track.

## Explicit non-claims

Do not claim:
- first OCR error taxonomy;
- first evaluation beyond CER/WER;
- first paired statistical comparison of OCR;
- first discussion of VLM hallucination in OCR;
- first historical-fidelity OCR metric;
- first observation of over-correction;
- first micro/macro OCR evaluation.

## Key references to cite prominently

- Levchenko, *Evaluating LLMs for Historical Document OCR: A Methodological
  Framework for Digital Humanities*, LM4DH 2025.
- Ehrmann et al., *ICDAR 2026 HIPE-OCRepair Competition on LLM-Assisted OCR
  Post-Correction for Historical Documents*, 2026.
- Li et al., *SCORE: A Semantic Evaluation Framework for Generative Document
  Parsing*, 2025.
- CC-OCR, 2024.
- OCRBench / OCRBench v2.
- OHRBench, 2024.
- CLEval, 2020.
- Kanungo et al., *Paired Model Evaluation of OCR Algorithms*, 1998/1999.
