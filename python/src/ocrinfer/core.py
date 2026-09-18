from __future__ import annotations

from dataclasses import dataclass
import re
import unicodedata
from typing import Iterable, Literal

import regex as uregex

Unit = Literal["grapheme", "codepoint", "word"]


@dataclass(frozen=True)
class AlignmentRow:
    reference: str | None
    hypothesis: str | None
    operation: str


@dataclass(frozen=True)
class EditCounts:
    n_reference: int
    n_hypothesis: int
    equal: int
    substitutions: int
    deletions: int
    insertions: int
    distance: int


def normalize_text(
    text: str,
    unicode: str = "NFC",
    case: str = "preserve",
    whitespace: str = "preserve",
    punctuation: str = "preserve",
) -> str:
    if text is None:
        raise ValueError("text must not be None")

    unicode = unicode.upper() if unicode != "none" else "none"
    if unicode not in {"NFC", "NFD", "NFKC", "NFKD", "none"}:
        raise ValueError("unicode must be NFC, NFD, NFKC, NFKD, or none")
    if case not in {"preserve", "lower", "upper"}:
        raise ValueError("case must be preserve, lower, or upper")
    if whitespace not in {"preserve", "collapse", "trim"}:
        raise ValueError("whitespace must be preserve, collapse, or trim")
    if punctuation not in {"preserve", "remove"}:
        raise ValueError("punctuation must be preserve or remove")

    out = str(text)

    if unicode != "none":
        out = unicodedata.normalize(unicode, out)

    if case == "lower":
        out = out.lower()
    elif case == "upper":
        out = out.upper()

    if punctuation == "remove":
        out = "".join(
            ch for ch in out
            if not unicodedata.category(ch).startswith("P")
        )

    if whitespace == "collapse":
        out = re.sub(r"\s+", " ", out).strip()
    elif whitespace == "trim":
        out = out.strip()

    return out


def _tokenize(text: str, unit: Unit) -> list[str]:
    if unit == "grapheme":
        return uregex.findall(r"\X", text)
    if unit == "codepoint":
        return list(text)
    if unit == "word":
        if not text:
            return []
        return re.split(r"\s+", text.strip()) if text.strip() else []
    raise ValueError(f"unknown unit: {unit}")


def _normalized_tokens(
    text: str,
    unit: Unit,
    unicode: str,
    case: str,
    whitespace: str,
    punctuation: str,
) -> list[str]:
    return _tokenize(
        normalize_text(
            text,
            unicode=unicode,
            case=case,
            whitespace=whitespace,
            punctuation=punctuation,
        ),
        unit,
    )


def align_text(
    reference: str,
    hypothesis: str,
    unit: Unit = "grapheme",
    unicode: str = "NFC",
    case: str = "preserve",
    whitespace: str = "preserve",
    punctuation: str = "preserve",
) -> list[AlignmentRow]:
    ref = _normalized_tokens(
        reference, unit, unicode, case, whitespace, punctuation
    )
    hyp = _normalized_tokens(
        hypothesis, unit, unicode, case, whitespace, punctuation
    )

    n, m = len(ref), len(hyp)
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    back: list[list[str | None]] = [[None] * (m + 1) for _ in range(n + 1)]

    for i in range(1, n + 1):
        dp[i][0] = i
        back[i][0] = "deletion"
    for j in range(1, m + 1):
        dp[0][j] = j
        back[0][j] = "insertion"

    for i in range(1, n + 1):
        for j in range(1, m + 1):
            same = ref[i - 1] == hyp[j - 1]
            diag = dp[i - 1][j - 1] + (0 if same else 1)
            delete = dp[i - 1][j] + 1
            insert = dp[i][j - 1] + 1
            best = min(diag, delete, insert)
            dp[i][j] = best

            # deterministic tie break: diagonal, deletion, insertion
            if diag == best:
                back[i][j] = "equal" if same else "substitution"
            elif delete == best:
                back[i][j] = "deletion"
            else:
                back[i][j] = "insertion"

    rows: list[AlignmentRow] = []
    i, j = n, m
    while i > 0 or j > 0:
        op = back[i][j]
        if op in {"equal", "substitution"}:
            rows.append(AlignmentRow(ref[i - 1], hyp[j - 1], op))
            i -= 1
            j -= 1
        elif op == "deletion":
            rows.append(AlignmentRow(ref[i - 1], None, op))
            i -= 1
        elif op == "insertion":
            rows.append(AlignmentRow(None, hyp[j - 1], op))
            j -= 1
        else:
            raise RuntimeError("invalid alignment backtrace")

    rows.reverse()
    return rows


def edit_counts(
    reference: str,
    hypothesis: str,
    unit: Unit = "grapheme",
    unicode: str = "NFC",
    case: str = "preserve",
    whitespace: str = "preserve",
    punctuation: str = "preserve",
) -> EditCounts:
    rows = align_text(
        reference,
        hypothesis,
        unit=unit,
        unicode=unicode,
        case=case,
        whitespace=whitespace,
        punctuation=punctuation,
    )
    ops = [row.operation for row in rows]
    n_reference = sum(row.reference is not None for row in rows)
    n_hypothesis = sum(row.hypothesis is not None for row in rows)
    substitutions = ops.count("substitution")
    deletions = ops.count("deletion")
    insertions = ops.count("insertion")
    equal = ops.count("equal")
    distance = substitutions + deletions + insertions

    return EditCounts(
        n_reference=n_reference,
        n_hypothesis=n_hypothesis,
        equal=equal,
        substitutions=substitutions,
        deletions=deletions,
        insertions=insertions,
        distance=distance,
    )


def _rate(counts: EditCounts) -> float:
    if counts.n_reference == 0:
        return 0.0 if counts.n_hypothesis == 0 else float(counts.insertions)
    return counts.distance / counts.n_reference


def cer(
    reference: str,
    hypothesis: str,
    *,
    char_unit: Literal["grapheme", "codepoint"] = "grapheme",
    unicode: str = "NFC",
    case: str = "preserve",
    whitespace: str = "preserve",
    punctuation: str = "preserve",
) -> float:
    return _rate(
        edit_counts(
            reference,
            hypothesis,
            unit=char_unit,
            unicode=unicode,
            case=case,
            whitespace=whitespace,
            punctuation=punctuation,
        )
    )


def wer(
    reference: str,
    hypothesis: str,
    *,
    unicode: str = "NFC",
    case: str = "preserve",
    whitespace: str = "collapse",
    punctuation: str = "preserve",
) -> float:
    return _rate(
        edit_counts(
            reference,
            hypothesis,
            unit="word",
            unicode=unicode,
            case=case,
            whitespace=whitespace,
            punctuation=punctuation,
        )
    )
