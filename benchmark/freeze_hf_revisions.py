#!/usr/bin/env python3
"""Resolve and freeze Hugging Face model revisions in SYSTEMS_POLICY.csv.

Usage:
    python benchmark/freeze_hf_revisions.py       benchmark/cmmhwr/SYSTEMS_POLICY.csv       benchmark/cmmhwr/SYSTEMS_POLICY_LOCKED.csv

The script queries the public Hugging Face model API and replaces TO_FREEZE
with the exact repository SHA returned at execution time. Non-Hugging-Face
baselines (for example Kraken) are left unchanged and must be versioned
separately.
"""

from __future__ import annotations

import csv
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def resolve_sha(model_id: str) -> str:
    url = "https://huggingface.co/api/models/" + urllib.parse.quote(
        model_id, safe="/"
    )
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "ocrinfer-cvpr-revision-lock/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(
            f"Hugging Face returned HTTP {exc.code} for {model_id}"
        ) from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(
            f"Could not query Hugging Face for {model_id}: {exc}"
        ) from exc

    sha = payload.get("sha")
    if not sha:
        raise RuntimeError(f"No repository SHA returned for {model_id}")
    return str(sha)


def looks_like_hf_id(model_id: str) -> bool:
    return "/" in model_id and not model_id.startswith(("/", "."))


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "Usage: freeze_hf_revisions.py <SYSTEMS_POLICY.csv> <LOCKED.csv>",
            file=sys.stderr,
        )
        return 2

    source = Path(sys.argv[1])
    target = Path(sys.argv[2])

    with source.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise RuntimeError("Input manifest has no header.")
        rows = list(reader)
        fieldnames = list(reader.fieldnames)

    required = {"system", "model_id", "revision"}
    missing = required.difference(fieldnames)
    if missing:
        raise RuntimeError(
            "Missing required columns: " + ", ".join(sorted(missing))
        )

    cache: dict[str, str] = {}

    for row in rows:
        model_id = row["model_id"].strip()
        revision = row["revision"].strip()

        if revision != "TO_FREEZE":
            continue

        if not looks_like_hf_id(model_id):
            print(
                f"SKIP {row['system']}: non-HF model_id={model_id}",
                file=sys.stderr,
            )
            continue

        if model_id not in cache:
            cache[model_id] = resolve_sha(model_id)

        row["revision"] = cache[model_id]
        print(
            f"LOCK {row['system']}: {model_id}@{row['revision']}",
            file=sys.stderr,
        )

    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
