# 交接

**CODE_READY**。V1.6 的纯显示和复合配置已用锁定的官方示例与 ESP-IDF v5.4.4 构建。纯显示版再次干净构建，产物清单的七个 SHA256 完全一致。

- [烧录包](../out/esp32-p4x-v16-usb-display.zip) 含两种配置、三份烧录二进制、烧录参数、ELF、有效配置及散列。
- [构建复现](../README.md) · [版本基线](BASELINE.md) · [阶段证据](../TASKS.md) · [板级审核](BOARD_V16_AUDIT.md)

**已在实机烧录纯显示版**。Windows COM6（303A:1001，BUSID 1-4）已透传为 WSL `/dev/ttyACM0`。芯片实测 ESP32-P4 Rev 3.2、16 MB Flash。烧录前核对了 MAC 和安全状态，保存了完整的原 Flash 备份并校验 SHA256。写入的三个区段均通过验证。两次启动均通过 32 MB PSRAM 自检并提交 1024×600 RGB565_LE 色条，用户确认实显正常。[烧录与启动证据](../evidence/P3/com6-flash-startup.log) · [现场记录](../evidence/P3/hardware-run.txt)

**Windows 1024×600 扩展桌面实测通过**。用户安装了 IDD 1.2.25.2。修正 USB 产品和 Vendor 接口字符串后，仅重写应用分区，Windows 从初始 320×240 回退模式切到 1024×600，设备挂载于 USB High-Speed。跨屏测试窗口运行约 30 秒，用户确认副屏显示且计时持续更新。[Windows 日志](../evidence/P4/windows-1024x600-smoke.log) · [实机测试](../evidence/P4/extended-desktop-test.txt)

**完整 MVP 验收待完成**。实体 USB 拔插 10 次及 2 小时连续运行尚未执行。

后续断电测试出现黑屏且 USB 无枚举。ROM 下载模式可以连接。校验了发布版的 bootloader、分区表和应用三个区段，均与构建产物一致。DIO／40 MHz 诊断版的引导及应用写入已校验，完整复位后 Windows 仍看不到活动 COM6。现场暂无 3.3 V USB‑TTL 无法读取 UART0 的最早启动日志。当前故障原因待定位。[冷启动记录](../evidence/P3/cold-start-summary.txt) · [验收表](ACCEPTANCE.md)

用户选择回退发布版。已恢复 bootloader 和纯显示应用并通过写入校验，沿用原分区表。随后的 ROM 热启动命令报 SPI 配置错误，COM6 仍处于 ROM 下载模式。[回退记录](../evidence/P3/cold-rollback-release.log) · [热启动证据](../evidence/P3/cold-rollback-warm-launch.log)
