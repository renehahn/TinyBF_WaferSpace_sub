#!/bin/bash
#=============================================================================
# check_design.sh - Librelane Design Verification Script
#=============================================================================
# Automatically checks timing, DRC, and design quality from latest Librelane run
# Usage:
#   ./check_design.sh           # Show summary
#   ./check_design.sh -v        # Show verbose/detailed stats
#=============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS_DIR="$SCRIPT_DIR/runs"

# Parse arguments
VERBOSE=0
if [[ "$1" == "-v" ]] || [[ "$1" == "--verbose" ]]; then
    VERBOSE=1
fi

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
METRICS_FILE="$LATEST_RUN/final/metrics.json"

if [[ ! -f "$METRICS_FILE" ]]; then
    echo "Error: metrics.json not found in $LATEST_RUN/final/"
    exit 1
fi

echo "========================================="
echo "Design Verification Report"
echo "========================================="
echo "Run: $RUN_NAME"
echo "Date: $(stat -c %y "$LATEST_RUN" 2>/dev/null | cut -d' ' -f1 || echo 'Unknown')"
echo ""

# Extract timing metrics
SETUP_WNS=$(jq -r '.timing__setup__wns // "N/A"' "$METRICS_FILE")
SETUP_TNS=$(jq -r '.timing__setup__tns // "N/A"' "$METRICS_FILE")
SETUP_VIO=$(jq -r '.timing__setup_vio__count // "N/A"' "$METRICS_FILE")
SETUP_WS=$(jq -r '.timing__setup__ws // "N/A"' "$METRICS_FILE")

HOLD_WNS=$(jq -r '.timing__hold__wns // "N/A"' "$METRICS_FILE")
HOLD_TNS=$(jq -r '.timing__hold__tns // "N/A"' "$METRICS_FILE")
HOLD_VIO=$(jq -r '.timing__hold_vio__count // "N/A"' "$METRICS_FILE")
HOLD_WS=$(jq -r '.timing__hold__ws // "N/A"' "$METRICS_FILE")

MAX_SLEW_VIO=$(jq -r '.design__max_slew_violation__count // "N/A"' "$METRICS_FILE")
MAX_CAP_VIO=$(jq -r '.design__max_cap_violation__count // "N/A"' "$METRICS_FILE")
MAX_FANOUT_VIO=$(jq -r '.design__max_fanout_violation__count // "N/A"' "$METRICS_FILE")

# Extract DRC metrics
ROUTE_DRC=$(jq -r '.route__drc_errors // "N/A"' "$METRICS_FILE")
MAGIC_DRC=$(jq -r '.magic__drc_error__count // "N/A"' "$METRICS_FILE")

# Determine pass/fail
TIMING_PASS=1
DRC_PASS=1
OVERALL_PASS=1

if [[ "$SETUP_VIO" != "0" ]] || [[ "$HOLD_VIO" != "0" ]]; then
    TIMING_PASS=0
    OVERALL_PASS=0
fi

if [[ "$ROUTE_DRC" != "0" ]] || [[ "$MAGIC_DRC" != "0" ]]; then
    DRC_PASS=0
    OVERALL_PASS=0
fi

# Print summary
echo "┌─────────────────────────────────────────┐"
echo "│         TIMING VIOLATIONS SUMMARY       │"
echo "└─────────────────────────────────────────┘"
printf "  Setup Violations:     %6s\n" "$SETUP_VIO"
printf "  Hold Violations:      %6s\n" "$HOLD_VIO"
printf "  Max Slew Violations:  %6s\n" "$MAX_SLEW_VIO"
printf "  Setup WS (Margin):    %8s ns\n" "$SETUP_WS"
printf "  Hold WS (Margin):     %8s ns\n" "$HOLD_WS"
echo ""

echo "┌─────────────────────────────────────────┐"
echo "│              DRC STATUS                 │"
echo "└─────────────────────────────────────────┘"
printf "  Route DRC Errors:     %8s\n" "$ROUTE_DRC"
printf "  Magic DRC Errors:     %8s\n" "$MAGIC_DRC"
echo ""

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Status summary
echo "========================================="
echo "           VERIFICATION STATUS"
echo "========================================="
if [[ $TIMING_PASS -eq 1 ]]; then
    echo -e "${GREEN}TIMING: PASSED${NC}"
else
    echo -e "${RED}TIMING: FAILED${NC}"
fi

if [[ $DRC_PASS -eq 1 ]]; then
    echo -e "${GREEN}DRC:    PASSED (GDS is DRC-clean)${NC}"
else
    echo -e "${RED}DRC:    FAILED${NC}"
fi

echo "========================================="
if [[ $OVERALL_PASS -eq 1 ]]; then
    echo -e "${GREEN}OVERALL: READY FOR FABRICATION${NC}"
else
    echo -e "${RED}OVERALL: NEEDS FIXES${NC}"
fi
echo "========================================="
echo ""

# Verbose mode
if [[ $VERBOSE -eq 1 ]]; then
    echo "┌─────────────────────────────────────────┐"
    echo "│       PER-CORNER TIMING ANALYSIS        │"
    echo "└─────────────────────────────────────────┘"
    echo ""
    
    for CORNER in "nom_tt_025C_1v80" "nom_ss_100C_1v60" "nom_ff_n40C_1v95"; do
        CORNER_SETUP_WS=$(jq -r ".\"timing__setup__ws__corner:$CORNER\" // \"N/A\"" "$METRICS_FILE")
        CORNER_HOLD_WS=$(jq -r ".\"timing__hold__ws__corner:$CORNER\" // \"N/A\"" "$METRICS_FILE")
        CORNER_SETUP_VIO=$(jq -r ".\"timing__setup_vio__count__corner:$CORNER\" // \"N/A\"" "$METRICS_FILE")
        CORNER_HOLD_VIO=$(jq -r ".\"timing__hold_vio__count__corner:$CORNER\" // \"N/A\"" "$METRICS_FILE")
        
        echo "Corner: $CORNER"
        printf "  Setup WS:  %8s ns  (Violations: %s)\n" "$CORNER_SETUP_WS" "$CORNER_SETUP_VIO"
        printf "  Hold WS:   %8s ns  (Violations: %s)\n" "$CORNER_HOLD_WS" "$CORNER_HOLD_VIO"
        echo ""
    done
    
    echo "┌─────────────────────────────────────────┐"
    echo "│          ADDITIONAL METRICS             │"
    echo "└─────────────────────────────────────────┘"
    INST_CNT=$(jq -r '.design__instance__count // "N/A"' "$METRICS_FILE")
    INST_AREA=$(jq -r '.design__instance__area // "N/A"' "$METRICS_FILE")
    UTIL=$(jq -r '.design__instance__utilization // "N/A"' "$METRICS_FILE")
    POWER=$(jq -r '.power__total // "N/A"' "$METRICS_FILE")
    LINT_WARN=$(jq -r '.design__lint_warning__count // "N/A"' "$METRICS_FILE")
    LINT_ERR=$(jq -r '.design__lint_error__count // "N/A"' "$METRICS_FILE")
    
    printf "  Instance Count:       %8s\n" "$INST_CNT"
    printf "  Instance Area:        %8s um2\n" "$INST_AREA"
    printf "  Utilization:          %8s\n" "$UTIL"
    printf "  Total Power:          %8s W\n" "$POWER"
    printf "  Lint Warnings:        %8s\n" "$LINT_WARN"
    printf "  Lint Errors:          %8s\n" "$LINT_ERR"
    echo ""
    
    echo "Reports:"
    echo "  DRC:    $LATEST_RUN/60-magic-drc/reports/drc_violations.magic.rpt"
    echo "  Timing: $LATEST_RUN/54-openroad-stapostpnr/summary.rpt"
    echo ""
fi

# Exit with error code if any check failed
if [[ $OVERALL_PASS -eq 0 ]]; then
    exit 1
fi

exit 0
