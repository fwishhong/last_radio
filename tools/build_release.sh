#!/usr/bin/env bash
# tools/build_release.sh — Unix/macOS variant of build_release.ps1.
# Same pipeline, same arg shape, same outputs.
#
# Usage:
#   ./tools/build_release.sh --version 0.5.0 --message "Initial v0.5 release"
#   ./tools/build_release.sh --version 0.5.1 --message "Hotfix" --skip-tests
#   ./tools/build_release.sh --skip-export           # tests + versioning only
#
# Override Godot binary: GODOT=/path/to/godot ./tools/build_release.sh ...

set -euo pipefail

GODOT="${GODOT:-godot}"
VERSION="${VERSION:-}"
MESSAGE="${MESSAGE:-}"
SKIP_TESTS=0
SKIP_EXPORT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)    VERSION="$2"; shift 2 ;;
        --message)    MESSAGE="$2"; shift 2 ;;
        --skip-tests) SKIP_TESTS=1; shift ;;
        --skip-export) SKIP_EXPORT=1; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Last Radio v2 release build ==="
echo "Repo: $REPO_ROOT"
echo "Godot: $GODOT"
echo ""

# 1. Sanity
if ! command -v "$GODOT" >/dev/null 2>&1; then
    echo "ERROR: Godot binary '$GODOT' not found. Set GODOT env var to override." >&2
    exit 1
fi
GODOT_VERSION="$($GODOT --headless --version 2>&1 | head -n 1)"
echo "Godot version: $GODOT_VERSION"
EXPECTED_TPL="$(echo "$GODOT_VERSION" | awk -F. '{print $1"."$2}').stable"
TPL_DIR="${HOME}/.local/share/godot/export_templates/${EXPECTED_TPL}"
if [[ ! -d "$TPL_DIR" ]]; then
    echo "WARNING: templates for $EXPECTED_TPL not installed at $TPL_DIR." >&2
fi

# 2. Tests
TESTS=(
    "save_test" "sfx_test" "flow_integration_test" "night_shift_basic_test"
    "night_shift_data_validate" "hotspot_dot_test" "day_effects_test"
    "late_hotspot_enemy_test" "night_report_stats_test" "radio_contact_test"
    "night_shift_full_flow_test" "signal_catalog_test" "i18n_test"
    "save_slots_test" "tutorial_test" "menu_ui_test" "locale_e2e_test"
    "walk_animation_test"
)

if [[ $SKIP_TESTS -eq 0 ]]; then
    echo ""
    echo "--- Running test suite ---"
    FAIL=()
    for t in "${TESTS[@]}"; do
        echo -n "[$t] "
        if OUTPUT="$($GODOT --headless --path . --script "res://tools/$t.gd" 2>&1)"; then
            SUMMARY="$(echo "$OUTPUT" | grep -E 'PASS|FAIL' | tail -n 1)"
            if [[ "$SUMMARY" == *PASS* ]]; then
                echo -e "\033[32m$SUMMARY\033[0m"
            else
                echo -e "\033[31mFAIL\033[0m"
                echo "$OUTPUT"
                FAIL+=("$t")
            fi
        else
            echo -e "\033[31mCRASH\033[0m"
            echo "$OUTPUT"
            FAIL+=("$t")
        fi
    done
    if [[ ${#FAIL[@]} -gt 0 ]]; then
        echo "Test failures: ${FAIL[*]}. Aborting." >&2
        exit 1
    fi
fi

# 3. Versioning
if [[ -z "$VERSION" && -f VERSION ]]; then
    VERSION="$(cat VERSION | tr -d '[:space:]')"
fi
VERSION="${VERSION:-0.0.0}"
echo ""
echo "--- Stamping version $VERSION ---"
printf '%s' "$VERSION" > VERSION
DATE="$(date +%Y-%m-%d)"
{
    echo ""
    echo "## [$VERSION] - $DATE"
    echo ""
    echo "$MESSAGE"
} >> CHANGELOG.md

# 4. Export
if [[ $SKIP_EXPORT -eq 0 ]]; then
    echo ""
    echo "--- Exporting release artifacts ---"
    mkdir -p build

    declare -a TARGETS=(
        "Windows Desktop|build/last_radio_v2_windows_x86_64.exe"
        "macOS|build/last_radio_v2_macos.zip"
        "Linux/X11|build/last_radio_v2_linux_x86_64"
    )

    for entry in "${TARGETS[@]}"; do
        PRESET="${entry%%|*}"
        OUT="${entry##*|}"
        echo "  $PRESET -> $OUT"
        $GODOT --headless --path . --export-release "$PRESET" "$OUT"
    done

    # 5. Verify
    echo ""
    echo "--- Verifying artifacts ---"
    OK=1
    for entry in "${TARGETS[@]}"; do
        OUT="${entry##*|}"
        if [[ -f "$OUT" ]]; then
            SIZE="$(stat -c %s "$OUT" 2>/dev/null || stat -f %z "$OUT")"
            if [[ "$SIZE" -lt 1048576 ]]; then
                echo "  $OUT: ${SIZE} bytes (TOO SMALL)"
                OK=0
            else
                echo "  $OUT: $(awk "BEGIN{printf \"%.1f\", $SIZE/1048576}") MB"
            fi
        else
            echo "  $OUT: MISSING"
            OK=0
        fi
    done
    [[ $OK -eq 1 ]] || { echo "Build FAILED: missing or tiny artifacts."; exit 1; }

    # 6. Checksums
    echo ""
    echo "--- Generating checksums ---"
    : > build/CHECKSUMS.txt
    for entry in "${TARGETS[@]}"; do
        OUT="${entry##*|}"
        [[ -f "$OUT" ]] && sha256sum "$OUT" >> build/CHECKSUMS.txt
    done
fi

echo ""
echo "=== Build complete ==="
