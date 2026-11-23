# 执行状态

此前已达到 **DEVICE_READY**，**Windows 1024×600 扩展桌面实测通过**。后续实机发现断电冷启动黑屏和 USB 不枚举，当前即插即用验收失败。

| 阶段 | 状态 | 命令、退出码与证据 |
|---|---|---|
| P0 环境与基线 | PASS | `scripts/audit_env.sh` → 0，[环境](evidence/P0/env-audit.log)。`git rev-parse HEAD`、递归子模块检查和 `idf.py bmgr -l` → 0，[板卡列表](evidence/P0/board-list.log)。[版本矩阵](docs/BASELINE.md) |
| P1 V1.6 板级配置 | PASS | `idf.py bmgr -b esp32_p4_function_ev_board -a firmware/board`（实际传绝对路径）→ 0，[生成日志](evidence/P1/board-generate.log) 与 [生成配置](evidence/P1/board-config.txt)。覆盖 LCD、GPIO、Rev 3.x 与内存配置 |
| P1 真实 LCD 点亮 | PASS | 用户确认开机色条正常。两次启动记录均为 1024×600 RGB565_LE，见 [串口证据](evidence/P3/com6-flash-startup.log) |
| P2 USB 固件构建与静态检查 | PASS | 兼容修正版纯显示与复合固件均干净构建 → 0；实际 ELF 验证 USB ID、端点及产品与接口共用的显示参数字符串。[纯显示构建](evidence/P4/idd-fix-display-only-build.log) · [复合构建](evidence/P4/idd-fix-composite-build.log) |
| P3 识别、原 Flash 备份、烧录与复位启动 | PASS | COM6（303A:1001，BUSID 1-4）透传 → 0；`scripts/flash.sh identify` → 0，ESP32-P4 Rev 3.2、16 MB Flash；`read_flash` 和备份哈希校验 → 0；`scripts/flash.sh flash … display-only` → 0，三区段写入验证通过，首次启动及额外串口复位均读取到 32 MB PSRAM 和 LCD 初始化。[P3 记录](evidence/P3/hardware-run.txt) |
| P3 USB HS 枚举 | PASS | Windows `Get-PnpDevice` → 0，识别到纯显示设备。Windows USB 集线器只读查询 → 0，报告 480 Mbps High-Speed。[枚举](evidence/P4/windows-2987-enumeration.log) · [速度](evidence/P4/windows-2987-speed.log) |
| P3 整机断电冷启动 | FAILED | 用户报告恢复主板和 LCD 供电后仍黑屏，正常复位后 COM6 消失。ROM 可在 BOOT 下载模式通讯，原发布固件三处校验通过。DIO／40 MHz 诊断完整复位后仍无 USB。已按用户选择恢复发布版并校验。[冷启动记录](evidence/P3/cold-start-summary.txt) |
| P4 驱动离线审核 | PASS | 下载、提取 INF/CAT、计算 SHA256 → 0，[INF](evidence/P4/inf-matches.txt)、[散列验证](evidence/P4/hash-check.log)。PowerShell `Get-AuthenticodeSignature` → 0，安装器 Valid，驱动目录 UnknownError，[本机验证](evidence/P4/windows-signature.log) |
| P4 Windows 安装与扩展模式 | PASS | 用户安装 IDD 1.2.25.2，Windows 绑定 `oem2.inf`，设备正常。旧固件获得 320×240 模式，串口确认丢弃尺寸不匹配的帧。更新应用分区 → 0 后，Windows 为 1024×600 扩展副屏。窗口移入和 30 秒动态刷新由用户目视确认。[现场记录](evidence/P4/extended-desktop-test.txt) |
| P5 短时显示、触摸、性能及稳定性 | TODO | 色条与短时 Windows 扩展显示通过。已刷入触控版，用户确认 1024×600 副屏触摸落点及双指缩放正常。完整边缘及五指、实体拔插 10 次和两小时连续运行待执行。[触控记录](evidence/P5/display-touch.txt) · [验收表](docs/ACCEPTANCE.md) |
| P6 自动化、回归和交付 | PASS | `scripts/bootstrap.sh` → 0，[依赖准备](evidence/P6/bootstrap.log)；纯显示兼容修正版重复干净构建，七项 SHA256 相同，[回归](evidence/P6/idd-fix-reproducibility.log)。`bash -n`、脱敏、缺串口拒绝与补丁检查，[脚本证据](evidence/P6/script-checks.log) |

构建期间处理了旧 Python 环境链接、ESP-IDF 个别子模块请求超时和构建清理顺序。早期 `--clean` 调用在 BMGR 后移除了管理组件，导致 CMake 回落到 esp32。脚本已改为先清理再生成，之后两种配置都构建成功。最终 CMake 的已知信息包括首次分阶段解析条件组件的重跑、未使用的相机及 Hosted SDIO 默认项和示例/UAC 共享的 HS choice；编译器未报告源代码警告。见 [环境记录](evidence/P0/) 和 [排障](docs/TROUBLESHOOTING.md)。
