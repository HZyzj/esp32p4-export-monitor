#!/usr/bin/env bash
# Source this file from the build and hardware scripts.
P4_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$P4_ROOT/firmware/versions.env"

export IDF_PATH="${P4_IDF_PATH:-$P4_ROOT/upstream/esp-idf-$IDF_TAG}"
export IDF_TOOLS_PATH="${P4_IDF_TOOLS_PATH:-$P4_ROOT/upstream/.idf-tools}"
export IDF_PYTHON_ENV_PATH="$P4_ROOT/upstream/.idf-venv"
export IDF_COMPONENT_CACHE_PATH="$P4_ROOT/upstream/.component-cache"
export ESP_BOARD_MANAGER_DISABLE_AUTO_AMEND=1
P4_IOT="$P4_ROOT/upstream/esp-iot-solution"
P4_WORK="$P4_ROOT/upstream/usb-display-work"
P4_EXAMPLE="$P4_WORK/$EXAMPLE_REL"

fail() {
    printf '%s\n' "$*" >&2
    return 1
}

check_revision() {
    local path="$1" expected="$2" actual
    actual="$(git -C "$path" rev-parse HEAD 2>/dev/null)" ||
        fail "缺少 checkout $path，请先运行 scripts/bootstrap.sh。" || return
    [[ "$expected" == "$actual" ]] ||
        fail "$path 的 HEAD 是 $actual，锁定版本为 $expected。"
}

activate_idf() {
    check_revision "$IDF_PATH" "$IDF_REV" || return
    [[ -x "$IDF_PYTHON_ENV_PATH/bin/python" ]] ||
        fail "缺少项目 Python 环境，请先运行 scripts/bootstrap.sh。" || return
    export PATH="$IDF_PYTHON_ENV_PATH/bin:$PATH"
    # ESP-IDF export scripts reference unset variables in some releases.
    local status=0
    set +u
    source "$IDF_PATH/export.sh" || status=$?
    set -u
    return "$status"
}
