#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"
if (( $# < 2 )) || [[ ! "$1" =~ ^P[0-6]$ ]]; then
    printf 'Usage: %s P0..P6 LOG [LOG...]\n' "$0" >&2
    exit 2
fi
stage="$1"
shift
for path in "$@"; do [[ -f "$path" && -r "$path" ]] || fail "无法读取日志 $path"; done
dest=$(mktemp -d "$P4_ROOT/evidence/$stage/collected-XXXXXX")
python3 - "$dest" "$P4_ROOT" "$@" <<'PY'
import re
import sys
from pathlib import Path

dest, root, *sources = sys.argv[1:]
for index, source in enumerate(sources, start=1):
    data = Path(source).read_text(encoding="utf-8", errors="replace")
    data = data.replace(root, "<project>").replace(str(Path.home()), "<user-home>")
    data = re.sub(r"(?i)(?<![a-f0-9])(?:[a-f0-9]{2}[:-]){5}[a-f0-9]{2}(?![a-f0-9])", "<MAC>", data)
    data = re.sub(r"(?im)^([^\n]*(?:serial(?: number)?|chip id|device instance(?: id)?|token|password|secret|api[_ -]?key)\s*[=:]).*$",
                  r"\1 <redacted>", data)
    data = re.sub(r"(?i)(USB\\VID_[\da-f]{4}&PID_[\da-f]{4}(?:&MI_[\da-f]{2})?\\)\S+",
                  r"\1<instance>", data)
    data = re.sub(r"/dev/serial/by-id/\S+", "/dev/serial/by-id/<instance>", data)
    data = re.sub(r"(?i)(https?://)[^/\s:@]+:[^/\s@]+@", r"\1<credentials>@", data)
    (Path(dest) / f"log-{index:02}.txt").write_text(data, encoding="utf-8")
PY
printf '脱敏日志位于 %s。公开前请核对内容。\n' "$dest"
