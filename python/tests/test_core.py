import math

from ocrinfer import cer, edit_counts, normalize_text, wer


def test_cer_basic():
    assert math.isclose(cer("abc", "axc"), 1 / 3)


def test_canonical_unicode_equivalence():
    ref = "e\u0301"
    hyp = "\u00e9"

    assert cer(
        ref,
        hyp,
        char_unit="codepoint",
        unicode="none",
    ) > 0

    assert cer(
        ref,
        hyp,
        char_unit="grapheme",
        unicode="NFC",
    ) == 0


def test_wer_basic():
    assert wer("one two", "one too") == 0.5


def test_edit_counts_deletion():
    counts = edit_counts("abc", "ac")
    assert counts.deletions == 1
    assert counts.distance == 1
