#!/usr/bin/env bash
set -euo pipefail

# Download and verify the two public datasets used by the CVPR project.
#
# Usage:
#   bash benchmark/download_public_sources.sh /data/cvpr_ocr
#
# CMMHWR26 is ~236 MB.
# GT4HistOCR is ~4 GB.
#
# curl resumes partial downloads (-C -). md5 checks are upstream-provided.

ROOT="${1:-}"
if [[ -z "$ROOT" ]]; then
  echo "Usage: $0 <data-root>" >&2
  exit 2
fi

mkdir -p "$ROOT/downloads" "$ROOT/cmmhwr26" "$ROOT/gt4histocr"

CMM_FILE="$ROOT/downloads/cmmhwr_test_with_transcriptions.tar.xz"
GT4_FILE="$ROOT/downloads/GT4HistOCR.tar"

CMM_URL="https://zenodo.org/records/19884972/files/cmmhwr_test_with_transcriptions.tar.xz?download=1"
GT4_URL="https://zenodo.org/records/1344132/files/GT4HistOCR.tar?download=1"

echo "Downloading CMMHWR26..."
curl -L --fail --retry 3 -C - -o "$CMM_FILE" "$CMM_URL"

echo "Verifying CMMHWR26 MD5..."
echo "b7c4ac7c615700f1d9e31f035297bf93  $CMM_FILE" | md5sum -c -

echo "Extracting CMMHWR26..."
tar -xJf "$CMM_FILE" -C "$ROOT/cmmhwr26"

echo "Downloading GT4HistOCR (~4 GB)..."
curl -L --fail --retry 3 -C - -o "$GT4_FILE" "$GT4_URL"

echo "Verifying GT4HistOCR MD5..."
echo "3c382e707042ed5f548caf180fec40f8  $GT4_FILE" | md5sum -c -

echo "Extracting GT4HistOCR..."
tar -xf "$GT4_FILE" -C "$ROOT/gt4histocr"

echo
echo "Done."
echo "CMMHWR26: $ROOT/cmmhwr26"
echo "GT4HistOCR: $ROOT/gt4histocr"
