# ESP32-P4X V1.6 USB 扩展屏

面向 ESP32-P4X-Function-EV-Board V1.6 和套件 7 英寸 1024×600 MIPI DSI LCD。固件基于乐鑫 `usb_extend_screen`，默认构建纯显示版 `303A:2987`。复合版 `303A:2986` 提供 HID 与 UAC 的后续测试入口。

## 复现构建

在 WSL2 的 Linux 文件系统进入本项目。使用 Git、curl、Python 3.11（含 venv）、CMake、Ninja 及现有 ESP-IDF 工具。首次从锁定版本准备依赖，已准备的工作区直接从第二条开始。脚本在 `upstream/` 内准备独立工具环境。已有干净的 v5.4.4 checkout 也可通过 `P4_IDF_PATH` 使用。

```bash
scripts/bootstrap.sh
scripts/build.sh --clean
scripts/inspect_build.sh display-only
```

复合版使用 `scripts/build.sh --clean --profile composite`。二进制、ELF、`flasher_args.json`、有效 `sdkconfig`、`SHA256SUMS` 位于 `out/<配置>/`。依赖版本见 [版本锁](firmware/versions.env) 和 [组件锁](firmware/dependencies.lock)。构建中的板级配置由 Board Manager 生成。

## 接线与验收

- 按 [V1.6 审核](docs/BOARD_V16_AUDIT.md) 接 DSI、GPIO27 复位、GPIO26 背光及 LCD 转接板供电。
- 只透传 **Serial/JTAG** USB 到 WSL。先按 [烧录手册](docs/WSL_FLASHING.md) 识别芯片、修订版、Flash 和 MAC，再烧录并检查开机色条。
- **HS USB Type-C** 保留在 Windows。根据 [驱动手册](docs/WINDOWS_DRIVER.md) 复核驱动并验证扩展模式。当前实机已用 IDD 1.2.25.2 通过 1024×600 短时扩展显示。
- [当前进度](TASKS.md) · [测试表](docs/ACCEPTANCE.md) · [排障](docs/TROUBLESHOOTING.md) · [交接](docs/HANDOFF.md)
