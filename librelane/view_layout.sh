#!/bin/bash
#=============================================================================
# view_layout.sh - Open Latest Layout in Magic
#=============================================================================
# Automatically opens the .mag layout file from the latest Librelane run
# Usage: ./view_layout.sh
#=============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS_DIR="$SCRIPT_DIR/runs"

# Find the latest run
if [[ ! -d "$RUNS_DIR" ]]; then
    echo "Error: No runs directory found at $RUNS_DIR"
    exit 1
fi

LATEST_RUN=$(ls -1dt "$RUNS_DIR"/RUN_* 2>/dev/null | head -1)
if [[ -z "$LATEST_RUN" ]]; then
    echo "Error: No RUN_* directories found in $RUNS_DIR"
    exit 1
fi

RUN_NAME=$(basename "$LATEST_RUN")
MAG_DIR="$LATEST_RUN/final/mag"

if [[ ! -d "$MAG_DIR" ]]; then
    echo "Error: mag directory not found at $MAG_DIR"
    exit 1
fi

# Find .mag file
MAG_FILE=$(find "$MAG_DIR" -maxdepth 1 -name "*.mag" | head -1)
if [[ -z "$MAG_FILE" ]]; then
    echo "Error: No .mag file found in $MAG_DIR"
    exit 1
fi

MAG_FILENAME=$(basename "$MAG_FILE")

echo "========================================="
echo "Opening Layout in Magic"
echo "========================================="
echo "Run:    $RUN_NAME"
echo "File:   $MAG_FILENAME"
echo "Path:   $MAG_DIR"
echo "========================================="
echo ""

# Change to the mag directory and launch magic
cd "$MAG_DIR"
magic "$MAG_FILENAME"
