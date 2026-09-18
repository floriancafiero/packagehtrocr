# CVPR 2027 positioning

## Working title

**Beyond Edit Distance: Evaluating Visual Transcription Fidelity in the VLM Era**

Alternative:

**Do Better Error Rates Mean Better Transcriptions? Reassessing OCR/HTR Evaluation for Generative Vision-Language Models**

Target: **CVPR 2027**, submission deadline 16 November 2026 AOE.

## Central research question

Modern generative vision-language models do not only make local recognition
errors. They can normalize, correct, complete, repeat, omit, or invent text under
strong language priors.

The paper asks:

> When systems with different inductive biases are compared as visual
> transcription systems, do conventional OCR/HTR evaluation protocols support
> reliable conclusions about which system is better and why?

The contribution is NOT "CER/WER are bad" and is NOT merely "we introduce a
taxonomy of OCR errors."

## Prior work that directly constrains novelty

### Traditional fine-grained OCR evaluation

**CLEval (CVPRW 2020)**  
Character-level evaluation for text detection/recognition, including partial
correctness and split/merge cases.

Implication for us:
- character-level diagnosis is not novel;
- we must not claim fine-grained character evaluation as a contribution.

### End-to-end / ordering-aware OCR evaluation

**DISGO (2023)**  
Deletion, Insertion, Substitution, Grouping/Ordering WER for scene text OCR.

**Vidal et al., End-to-End Page-Level Assessment of HTR (2023)**  
Separates intrinsic recognition accuracy from reading-order quality at page level.

Implication:
- decomposing recognition vs layout/ordering is established;
- our main paper should stay focused on visual transcription fidelity rather than
  claim general page parsing evaluation novelty.

### Statistical comparison of OCR systems

**Kanungo, Marton & Bulbul, Paired Model Evaluation of OCR Algorithms (1998/1999)**  
Already argues for paired comparisons and confidence intervals across the same
documents.

Implication:
- paired inference by itself is not novel;
- our statistical component is a modernized protocol for hierarchical benchmarks,
  not the headline invention.

### Broad LMM OCR benchmarks

**OCRBench (2023)** and **OCRBench v2 (2024/2025)**  
Broad OCR-centric evaluation of multimodal models across many tasks/scenarios.

**CC-OCR (2024)**  
39 subsets / 7,058 images, including recognition, multilingual reading, parsing
and KIE; identifies weaknesses including repetition hallucination.

**OmniDocBench (2024)** and **Real5-OmniDocBench (2026)**  
Comprehensive document parsing and robustness benchmarks.

Implication:
- "a comprehensive OCR benchmark for VLMs" is already crowded;
- we should not compete on number of tasks/datasets.

### Evaluation beyond edit distance

**OHRBench / OCR Hinders RAG (2024)**  
Separates semantic and formatting OCR noise and studies cascading downstream RAG
effects.

**When Good OCR Is Not Enough (ACL 2026)**  
Shows low CER/WER does not necessarily imply strong downstream RAG performance.

**FinCriticalED (2025)**  
Fact-level OCR/VLM evaluation for high-stakes financial values.

Implication:
- downstream utility/factual correctness beyond CER is established;
- our contribution should not be "semantic utility matters."

### Historical-fidelity evaluation of VLM OCR

**Levchenko (LM4DH 2025)**  
Evaluates 12 multimodal LLMs on 18th-century Russian print and introduces
Historical Character Preservation Rate (HCPR) and Archaic Insertion Rate (AIR).
The paper demonstrates "over-historicization", where models insert archaic
characters from the wrong historical period, and includes contamination/stability
analysis.

Implication:
- historical/diplomatic fidelity is already an explicit evaluation target;
- we cannot claim to be first to show that CER/WER miss historical-fidelity
  failures;
- our contribution must generalize beyond a period-specific character inventory
  to source-grounded error attribution across languages/scripts and model
  families.

**HIPE-OCRepair 2026**  
Uses cMER/wMER, micro/macro aggregation, confidence intervals and a preference
score against raw OCR; the shared task explicitly documents over-correction by
LLM post-correctors.

Implication:
- micro/macro aggregation, uncertainty and over-correction are established;
- the key distinction is that HIPE-OCRepair is text-only post-correction and
  retrieval-oriented, whereas our difficult labels are conditioned on the
  original source image and target visual transcription fidelity.

### Generative document parsing evaluation

**SCORE (2025)**  
The closest conceptual competitor. It proposes a semantic evaluation framework
for generative document parsing, including adjusted edit distance, hallucination
vs omission diagnostics, semantic/spatial table evaluation, and hierarchy-aware
consistency.

Implication:
- "multidimensional evaluation of generative document outputs" is NOT sufficient
  novelty;
- our distinction must be transcription-specific and must address fidelity to
  visible source text rather than equivalence among semantically valid parses.

### Fine-grained OCR error criticism

**OCR-Critic / OCR-ERROR (2025)**  
Detects and categorizes OCR errors using multimodal critical feedback.

Implication:
- error categorization itself is not novel;
- we should not position the paper as simply detecting OCR errors.

## The defensible gap

The gap is therefore narrower than initially expected. It is the intersection
of three things that existing work has not yet combined in a general
source-grounded visual-transcription benchmark:

### 1. Visual transcription fidelity

For transcription, semantic equivalence is not always correctness.

A generative recognizer may produce:
- a linguistically corrected word;
- expanded abbreviations;
- normalized historical orthography;
- plausible completion of unreadable material;
- repeated text;
- unsupported but contextually plausible tokens.

Some of these outputs can be semantically better than the literal visual
transcription while being *less faithful as transcription*.

This is different from SCORE's goal of accepting alternative semantically valid
document parses.

### 2. Model-family-specific error structure

We compare systems with different inductive biases:
- classical/specialized recognizers;
- encoder-decoder HTR/OCR models;
- generative VLMs.

The hypothesis is not merely that their CER differs, but that the **composition
of their errors differs systematically**.

### 3. Reliability of benchmark conclusions

We treat a leaderboard claim as an estimand that depends on:
- aggregation level (micro vs document-level macro);
- document/manuscript heterogeneity;
- evaluation policy (Unicode, punctuation, case, whitespace);
- error severity/fidelity definition.

The question becomes:

> Is "system B is better than system A" stable under scientifically defensible
> choices of unit, policy, and fidelity criterion?

The historical paired-evaluation literature motivates this rather than making it
our novelty claim.

## Proposed conceptual contribution

### Fidelity-aware transcription error taxonomy

Start with mechanically observable alignment errors:
- substitution;
- deletion;
- insertion;
- repetition / duplicated span;
- segmentation/boundary effects where relevant.

Add generative-fidelity categories that require source-aware adjudication:
- **orthographic normalization**: faithful historical/non-standard form replaced
  by a normalized modern form;
- **linguistic correction**: visible source form changed toward a more probable
  language form;
- **abbreviation expansion/contraction**: representation changed beyond the
  transcription convention;
- **unsupported completion**: text inferred beyond visible evidence;
- **hallucinated addition**: content without source support;
- **content omission**: visible content not transcribed.

The taxonomy must distinguish:
- what can be automatically inferred from reference/prediction alignment;
- what needs image-conditioned human or validated model annotation.

### Evaluation profile, not one universal score

The paper should resist inventing one arbitrary weighted scalar.

Core report:
1. CER/WER under an explicit policy;
2. micro and document-level macro estimates;
3. paired document-level uncertainty;
4. error composition;
5. fidelity-error rates;
6. sensitivity across pre-specified evaluation policies.

A scalar "fidelity score" is optional and should only be introduced if validated
against human judgments.

## Claims we can make only if demonstrated

Potentially strong claims:
- model families with similar CER have materially different fidelity/error
  profiles;
- leaderboard ordering is unstable under plausible aggregation or policy choices;
- VLMs reduce local visual substitutions while increasing one or more
  language-prior/fidelity errors;
- document-level uncertainty reveals that some small leaderboard differences do
  not support a robust superiority claim.

Do NOT assume these results in advance.

## What would make this a CVPR paper rather than an ICDAR/R Journal paper?

At least three of the following need to be strong:

1. **New empirical phenomenon** associated with generative visual recognition,
   not only a software framework.
2. **Human-validated fidelity taxonomy/annotation set** that others can reuse.
3. **Multiple model families**, including genuinely generative VLMs.
4. **More than one benchmark/domain**, ideally historical handwriting plus a
   modern/printed text setting.
5. **Ranking or conclusion changes** that conventional evaluation hides.
6. A public evaluation toolkit reproducing all analyses.

If we only obtain cleaner statistics and nicer error tables, the work is better
suited to ICDAR/R Journal.

## Main related-work references to track

- Kanungo, Marton, Bulbul. Paired Model Evaluation of OCR Algorithms. 1998.
- Baek et al. CLEval. CVPR Workshops 2020.
- Hwang et al. DISGO. 2023.
- Vidal et al. End-to-End Page-Level Assessment of HTR. 2023.
- Liu et al. OCRBench. 2023.
- Zhang et al. OHRBench / OCR Hinders RAG. 2024.
- Yang et al. CC-OCR. 2024.
- Ouyang et al. OmniDocBench. 2024.
- Fu et al. OCRBench v2. 2025.
- Li et al. SCORE. 2025.
- OCR-Critic / OCR-ERROR. 2025.
- FinCriticalED. 2025.
- Sun et al. When Good OCR Is Not Enough. ACL 2026.
- Real5-OmniDocBench. 2026.

Before submission, every capability comparison must be re-checked against the
latest released versions and contemporaneous work.
