#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"

mkdir -p "$P4_ROOT/upstream" "$IDF_TOOLS_PATH"
if [[ ! -e "$P4_IOT" ]]; then
    git init -q "$P4_IOT"
    git -C "$P4_IOT" remote add origin "$IOT_URL"
    git -C "$P4_IOT" -c http.sslVerify=true fetch --depth 1 origin "$IOT_REV"
    git -C "$P4_IOT" switch --detach FETCH_HEAD
fi
check_revision "$P4_IOT" "$IOT_REV"
git -C "$P4_IOT" -c http.sslVerify=true submodule update --init --recursive

if [[ ! -e "$IDF_PATH" ]]; then
    [[ "$IDF_PATH" == "$P4_ROOT/upstream/esp-idf-$IDF_TAG" ]] ||
        fail "P4_IDF_PATH 必须指向现有的 $IDF_TAG checkout。"
    git -c http.sslVerify=true clone --depth 1 --branch "$IDF_TAG" "$IDF_URL" "$IDF_PATH"
fi
check_revision "$IDF_PATH" "$IDF_REV"
if git -C "$IDF_PATH" submodule status --recursive | grep '^[-+U]'; then
    git -C "$IDF_PATH" -c http.sslVerify=true submodule update --init --recursive --jobs 8 --depth 1
fi

constraints="$IDF_TOOLS_PATH/espidf.constraints.v5.4.txt"
if [[ ! -s "$constraints" ]]; then
    curl -fsSL https://dl.espressif.com/dl/esp-idf/espidf.constraints.v5.4.txt -o "$constraints.tmp"
    mv "$constraints.tmp" "$constraints"
fi
if [[ ! -x "$IDF_PYTHON_ENV_PATH/bin/python" ]]; then
    python3 -m venv "$IDF_PYTHON_ENV_PATH"
fi
"$IDF_PYTHON_ENV_PATH/bin/python" -m pip install --no-cache-dir -c "$constraints" \
    -r "$P4_ROOT/firmware/python-requirements.lock"
"$IDF_PYTHON_ENV_PATH/bin/python" "$IDF_PATH/tools/idf_tools.py" --non-interactive install --targets esp32p4
activate_idf
idf.py --version
