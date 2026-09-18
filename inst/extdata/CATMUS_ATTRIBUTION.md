# CATMuS fixture attribution

The files `catmus_medieval_public_fixture.csv` and
`catmus_medieval_controlled_predictions.csv` contain a small set of text
transcriptions and metadata selected from the public **CATMuS Medieval Samples**
dataset.

Source: https://huggingface.co/datasets/CATMuS/medieval-samples

Parent dataset: https://huggingface.co/datasets/CATMuS/medieval

CATMuS Medieval is released under **CC BY 4.0**. The source dataset is curated
by Thibault Clérice and collaborators; users of this fixture should cite the
CATMuS Medieval dataset/paper as requested by the upstream dataset card.

Only transcription text and descriptive metadata are reproduced here; no
manuscript images are redistributed.

## Important methodological note

The three values of `system` in
`catmus_medieval_controlled_predictions.csv` are **controlled transformations,
not OCR/HTR model outputs**:

- `exact`: identical to the public reference;
- `nfc_equivalent`: canonically equivalent NFC Unicode representation;
- `punctuation_dropped`: Unicode punctuation removed.

This fixture exists to test Unicode/normalization sensitivity and aggregation
semantics. It must not be reported as a benchmark of recognition systems.
