#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/env.sh"

profile=display-only
clean=false
while (($#)); do
    case "$1" in
        --clean) clean=true; shift ;;
        --profile)
            [[ $# -ge 2 ]] || fail "请指定 --profile display-only 或 composite。"
            profile="$2"
            shift 2
            ;;
        -h|--help) printf 'Usage: %s [--clean] [--profile display-only|composite]\n' "$0"; exit ;;
        *) fail "未知参数 $1" ;;
    esac
done
case "$profile" in display-only|composite) ;; *) fail "未知固件配置 $profile" ;; esac
case "$P4_ROOT" in /mnt/[A-Za-z]/*) fail "请将目录放在 WSL 的 Linux 文件系统中。" ;; esac

mkdir -p "$P4_ROOT/out" "$P4_ROOT/evidence/P2"
exec 9>"$P4_ROOT/out/.build.lock"
flock 9
run_dir=$(mktemp -d "$P4_ROOT/evidence/P2/run-$profile.XXXXXX")
exec > >(tee "$run_dir/build.log") 2>&1
trap 'status=$?; printf "Exit: %s\n" "$status" > "$run_dir/status.txt"; printf "Build log: %s (exit %s)\n" "$run_dir/build.log" "$status"' EXIT

check_revision "$P4_IOT" "$IOT_REV"
check_revision "$IDF_PATH" "$IDF_REV"
submodules=$(git -C "$IDF_PATH" submodule status --recursive)
if grep -E '^[-+U]' <<< "$submodules"; then
    fail "ESP-IDF 子模块状态有误，请运行 scripts/bootstrap.sh。"
fi
git -C "$IDF_PATH" diff --exit-code HEAD --quiet ||
    fail "ESP-IDF checkout 有本地修改，请使用锁定版本的干净 checkout。"
activate_idf
python -c "from importlib.metadata import version; import sys; sys.exit(version('esp-bmgr-assist') != '$BMGR_ASSIST_VERSION')" ||
    fail "esp-bmgr-assist 版本不匹配，请运行 scripts/bootstrap.sh。"
idf.py --version
riscv32-esp-elf-gcc -dumpfullversion

if [[ ! -e "$P4_WORK" ]]; then
    git -C "$P4_IOT" worktree add --detach "$P4_WORK" "$IOT_REV"
fi
check_revision "$P4_WORK" "$IOT_REV"
patch="$P4_ROOT/firmware/patches/0001-lcd-and-usb-diagnostics.patch"
if git -C "$P4_WORK" diff --quiet HEAD --; then
    git -C "$P4_WORK" apply --check "$patch"
    git -C "$P4_WORK" apply "$patch"
fi
git -C "$P4_WORK" diff --binary --no-ext-diff HEAD | cmp -s "$patch" - ||
    fail "工作树包含额外改动，请保留这些改动后用干净的构建工作树重试。"

cd "$P4_EXAMPLE"
out="$P4_ROOT/out/$profile"
[[ ! -L "$out" && "$(realpath -m "$out")" == "$out" ]] || fail "意外的输出目录 $out"
mkdir -p "$out"
if $clean && [[ -f "$out/CMakeCache.txt" ]]; then
    idf.py -B "$out" fullclean
fi
lock="$P4_ROOT/firmware/dependencies.lock"
local_component="$P4_WORK/components/usb/usb_device_uac"
LOCK_SRC="$local_component" python -c 'import os, pathlib, sys; print(pathlib.Path(sys.argv[1]).read_text().replace("@USB_DEVICE_UAC@", os.environ["LOCK_SRC"]), end="")' "$lock" > dependencies.lock

printf 'Generating %s with %s\n' "$BASE_BOARD" "$P4_ROOT/firmware/board"
idf.py bmgr -b "$BASE_BOARD" -a "$P4_ROOT/firmware/board" | tee "$run_dir/board-generate.log"
defaults="sdkconfig.defaults;$P4_ROOT/firmware/sdkconfig.defaults;$P4_ROOT/firmware/sdkconfig.defaults.$profile"
printf 'Building %s in %s\n' "$profile" "$out"
idf.py -B "$out" -D "SDKCONFIG=$out/sdkconfig" -D "SDKCONFIG_DEFAULTS=$defaults" build

diff -u "$lock" <(LOCK_SRC="$local_component" python -c 'import os, pathlib; print(pathlib.Path("dependencies.lock").read_text().replace(os.environ["LOCK_SRC"], "@USB_DEVICE_UAC@"), end="")')
cp dependencies.lock "$run_dir/dependencies.lock"
cp "$out/sdkconfig" "$run_dir/sdkconfig"
"$P4_ROOT/scripts/inspect_build.sh" "$profile" | tee "$run_dir/inspection.txt"
