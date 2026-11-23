#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"
profile="${1:-display-only}"
case "$profile" in display-only|composite) ;; *) fail "未知固件配置 $profile" ;; esac
exec "$IDF_PYTHON_ENV_PATH/bin/python" "$P4_ROOT/scripts/inspect_build.py" "$P4_ROOT" "$profile"
