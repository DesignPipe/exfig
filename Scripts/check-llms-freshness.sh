#!/bin/bash
# Check if llms.txt / llms-full.txt are up to date with documentation sources.
# Generates to a temp directory (parallel-safe) and compares with repo versions.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

LLMS_TXT="$TMPDIR/llms.txt" LLMS_FULL="$TMPDIR/llms-full.txt" \
    bash Scripts/generate-llms.sh > /dev/null 2>&1

diff -q llms.txt "$TMPDIR/llms.txt" > /dev/null 2>&1 \
    && diff -q llms-full.txt "$TMPDIR/llms-full.txt" > /dev/null 2>&1
