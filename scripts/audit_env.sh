#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"
uname -a
(cd "$P4_ROOT" && pwd)
findmnt -n -o FSTYPE,TARGET -T "$P4_ROOT"
git --version
python3 --version
for executable in cmake ninja lsusb; do
    command -v "$executable" || true
done
for port in /dev/ttyACM* /dev/ttyUSB* /dev/serial/by-id; do
    [[ ! -e "$port" ]] || printf 'Available: %s\n' "$port"
done
if command -v lsusb >/dev/null; then
    lsusb -t
fi
printf 'IDF repository: %s\n' "$IDF_PATH"
check_revision "$P4_IOT" "$IOT_REV"
check_revision "$IDF_PATH" "$IDF_REV"
python="$IDF_PYTHON_ENV_PATH/bin/python"
[[ -x "$python" ]] || fail "缺少项目 Python 环境。"
"$python" "$IDF_PATH/tools/idf.py" --version
"$python" -c 'from importlib.metadata import version; print("\n".join(f"{p}=={version(p)}" for p in ("esp-bmgr-assist", "idf-component-manager", "esptool")))'
git -C "$IDF_PATH" submodule status --recursive
