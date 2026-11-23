# 故障排查

| 现象 | 检查顺序 |
|---|---|
| `idf.py` 缺失或找不到 Python 依赖 | 用 `scripts/bootstrap.sh` 准备项目内的锁定 IDF。旧 venv 的 Python 链接可能指向不同小版本。运行 `scripts/audit_env.sh` 核对工具及子模块 |
| CMake 报 ESP-IDF 组件子模块缺失 | 查看 `git -C upstream/esp-idf-v5.4.4 submodule status --recursive`。补齐未初始化或偏离 gitlink 的子模块后再干净构建 |
| BMGR 找不到板或烧录错误修订版 | 检查是否使用 V1.6 amend、目标是否为 esp32p4、镜像是否为 Rev 3.x。BMGR 生成 target 后通过 `scripts/build.sh --clean` 刷新 |
| 上电黑屏，串口报 panel init / DSI timeout | 断电检查反向 FFC、DSI 与 J3、GPIO27 复位线、GPIO26 PWM 线和 LCD 转接板 J1 电源。对照 [板级审核](BOARD_V16_AUDIT.md) |
| 背光亮但无色条，或色条不正确 | 看生成的 EK79007/DPI 配置、LCD 是否有 `1024x600, framebuffer=RGB565_LE` 和提交日志。横向错位看时序、色序异常看 RGB/BGR 和色深。先留空 HS 口重复测试 |
| 初始化日志出现 `swap_xy` 或 `disp_on_off` 不支持 | Board Manager 0.7.6 的通用初始化会调用这两个 EK79007 面板不提供的操作。若其后出现 LCD 初始化成功、色条提交和可见色条，则记录为已知非致命日志。Rev 3.2 也记录了 PMU 校准 eFuse 缺省，实测启动使用默认值并通过 PSRAM 自检 |
| WSL 无串口或 esptool 无响应 | 只接 Serial/JTAG，按 [烧录手册](WSL_FLASHING.md) 核对唯一 BUSID、设备权限与占用；复位后检查是否仍 attach |
| Windows 无 PnP 条目或仅 FS | 确认连接 HS USB 2.0 Type-C、HS Type-A 空闲、线缆支持数据、换可确认的 USB 2.0 HS 主机口。看串口 `USB Mount: high-speed` 和 Windows 枚举 |
| 设备有枚举但第二屏不出现 | 核对 PID、复合版 Vendor 的 `MI_00`、驱动信任和设备管理器错误。见 [驱动手册](WINDOWS_DRIVER.md) |
| Windows 副屏显示 320×240 或设备报告丢弃 320×240 帧 | 检查是否仍使用早期纯显示固件。当前版在 USB 产品和 Vendor 接口中提供相同的显示参数。核对启动日志中的 USB Mount、Windows 活动分辨率和有效驱动版本 |
| 色条正常，Windows 扩展后冻结或花屏 | 看 Input JPEG headers、LCD submissions、JPEG 错误、draw 错误、队列丢帧、USB Suspend/Resume 及复位原因。记录前后一分钟日志；基线测试后再降低 FPS/JPEG |
| 初次构建出现 board defaults 或 TinyUSB Kconfig 提示 | 旧板默认文件包含本工程未引入的相机、Hosted SDIO，首轮依赖解析时也可能没有音频选项。重复 HS choice 来自示例和同仓库 USB UAC 组件。以最终配置、镜像、ELF 描述符和退出码为准 |

归档现场日志用 `scripts/collect_logs.sh P3 LOG...`，公开前人工检查用户名、设备标识、局域网地址和凭据。原始设备标识仅存私有记录。
