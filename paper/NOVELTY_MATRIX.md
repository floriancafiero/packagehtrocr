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
| HIPE-OCRepair 2026 | cMER/wMER, micro/macro aggregation, confidence intervals, preference vs raw OCR; documents over-correction | Statistical evaluation and over-correction | Text-only post-correction without source images, retrieval-oriented normalization; useful precedent but not our headline novelty |
| Vesalainen et al. 2026 | Qwen can achieve better CER/WER than TrOCR while silently regularizing historical orthography; model families show different error structures | Extremely close empirical phenomenon | We cannot claim discovery of VLM normalization. We instead manipulate the requested transcription policy within the same model/weights and measure controllability/compliance |
| OCR-EDR (Zhao et al., Sep. 2026) | Source-image + OCR-output + rendered-output diagnosis and repair; preserves rendering-equivalent outputs; diagnoses omissions/hallucinations and localizes genuine errors | Source-grounded diagnosis | Source-grounded diagnosis is not new. Our proposed variable is the declared transcription policy and its controlled prompt intervention on the same image/model |
| Transcription Policy as a Latent Variable (Wagner et al., ASR 2026) | ASR style mismatch can account for a large share of WER; models can be activated toward verbatim/intended transcription policies | Very close conceptual precedent outside vision | Strong motivation/analogy. Our question is visual transcription: source image provides independent grounding and policy compliance can be manipulated through VLM instructions |
| Normalized vs Diplomatic Annotation (Bottaioli et al.) / Ocular | Same document images can have different legitimate transcription targets (normalized vs diplomatic) | Multiple target conventions | Multiple transcription targets are established. Our proposed contribution is not creating two styles, but testing instruction-conditioned switching/compliance in generative visual recognizers |
| When Good OCR Is Not Enough (ACL 2026) | CER/WER do not fully predict downstream RAG utility | Limits of scalar OCR metrics | Our outcome is policy-conditioned visual transcription, not RAG performance |

## The novelty claim we should defend

The previous "source-grounded fidelity" claim is no longer strong enough after
OCR-EDR and Vesalainen et al. 2026.

The current claim should be:

> For generative visual recognizers, the **target transcription policy is an
> experimental variable**. We introduce a paired **policy-swap protocol** that
> changes only the transcription instruction while holding the source image,
> model weights, decoding regime and evaluation material fixed, then measures
> whether the model moves toward the requested target convention without losing
> visual grounding.

The contribution is the combination of:

1. **Controlled intervention:** neutral, matched-policy and deliberately
   conflicting policy prompts are applied to the same model/image pairs.
2. **Policy-conditioned evaluation:** an output is judged relative to the
   declared target convention, not an imagined universally "literal" ground
   truth.
3. **Within-model comparisons:** prompt effects are separated from architecture
   and training effects by comparing the same weights under different policies.
4. **Cross-domain validation:** the target policy is intentionally different on
   CMMHWR26 (CATMuS-like) and GT4HistOCR (diplomatic historical print).
5. **Source-grounded diagnosis as supporting evidence:** human annotation is
   used to explain *how* policy interventions change errors, but source-grounded
   diagnosis itself is not claimed as novel.

The statistical robustness layer remains supporting methodology rather than a
headline novelty.

## Strong empirical result needed

The paper becomes compelling if we can demonstrate at least one of:

- changing only the policy instruction materially changes a model's output on
  the same images;
- the matched policy moves outputs toward the target convention while a
  conflicting policy moves them away;
- specialist and general-purpose VLMs differ systematically in policy
  controllability;
- ordinary CER/WER hides whether a delta comes from visual recognition or target
  convention mismatch;
- the policy effect recurs in both handwriting and print despite opposite target
  conventions.

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
- first micro/macro OCR evaluation;
- first source-grounded OCR diagnosis;
- first observation that VLMs normalize historical text;
- first use of diplomatic vs normalized transcription targets.

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
- Zhao et al., *OCR-EDR: Rendering-Aware Diagnosis and Repair for Closed-Loop
  OCR Improvement*, 2026.
- Vesalainen et al., *Error Patterns in Historical OCR: A Comparative Analysis
  of TrOCR and a Vision-Language Model*, 2026.
- Wagner et al., *Transcription Policy as a Latent Variable: Activating
  Controllable Verbatim ASR with Word-Level Timing*, 2026.
