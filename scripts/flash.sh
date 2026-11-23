#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"

usage() {
    printf 'Usage: %s identify PORT\n       %s flash PORT EXPECTED_MAC [display-only|display-touch|composite]\n' "$0" "$0"
}
if [[ "${1:-}" == --help ]]; then usage; exit; fi
if (( $# < 2 || $# > 4 )); then usage >&2; exit 2; fi
mode="$1"
port="$2"
expected_mac="${3:-}"
profile="${4:-display-only}"
case "$mode" in
    identify) [[ $# == 2 ]] || fail "identify 只接收端口。" ;;
    flash)
        [[ "$expected_mac" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] ||
            fail "请输入已识别设备的完整 MAC。"
        case "$profile" in display-only|display-touch|composite) ;; *) fail "未知固件配置 $profile" ;; esac
        ;;
    *) usage >&2; exit 2 ;;
esac
real_port="$(readlink -e "$port")" || fail "找不到串口 $port，请连接并透传 V1.6 Serial/JTAG。"
[[ -c "$real_port" && "$real_port" =~ ^/dev/tty(ACM|USB)[0-9]+$ && -r "$real_port" && -w "$real_port" ]] ||
    fail "要求有读写权限的 USB 稳定串口路径。"
activate_idf >&2

if [[ "$mode" == flash ]]; then
    out="$P4_ROOT/out/$profile"
    (
        cd "$out"
        sha256sum --strict --check SHA256SUMS
    )
fi

private="$P4_ROOT/evidence/P3/private"
umask 077
mkdir -p "$private"
identity=$(mktemp "$private/identity.XXXXXX")
python -m esptool --chip auto --port "$real_port" flash_id | tee "$identity"
grep -Eiq '^Chip is ESP32-P4.*\(revision v3\.[1-9][0-9]*\)' "$identity" ||
    fail "需要实际识别到 ESP32-P4 修订版 v3.1 或更新的 v3.x。"
grep -Eiq '^Detected flash size:[[:space:]]*16[[:space:]]*MB' "$identity" ||
    fail "目标 Flash 容量与 V1.6 的 16 MB 不符。"
if [[ "$mode" == identify ]]; then
    printf '目标身份已读出。原始记录位于 %s\n' "$identity"
    exit
fi
actual_mac="$(sed -nE 's/^MAC:[[:space:]]*(([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}).*/\1/p' "$identity")"
[[ "${actual_mac,,}" == "${expected_mac,,}" && "$(readlink -e "$port")" == "$real_port" ]] ||
    fail "芯片 MAC 或串口当前映射与已确认的设备不一致。"

cd "$P4_EXAMPLE"
defaults="sdkconfig.defaults;$P4_ROOT/firmware/sdkconfig.defaults;$P4_ROOT/firmware/sdkconfig.defaults.$profile"
log=$(mktemp "$private/flash-monitor.XXXXXX")
idf.py -B "$out" -D "SDKCONFIG=$out/sdkconfig" -D "SDKCONFIG_DEFAULTS=$defaults" \
    -p "$real_port" flash monitor |& tee "$log"
