# ESP32-P4X-Function-EV-Board V1.6 USB Windows 扩展副屏开发任务书

> 文档版本：1.0（2026-11-23）  
> 执行对象：Codex CLI / OpenCode / 兼容的自主编程 Agent  
> 工作语言：中文；代码与日志按工程惯例  
> 项目代号：P4-USB-DISPLAY

## 0. Agent 开始执行指令（必须遵守）

你是本项目的主开发 Agent。读取本任务书后，**立即从 P0 环境审计开始实际执行**，不得仅复述任务、反复输出计划、或把可以通过命令核实的信息交给用户确认。对能自动完成的步骤持续推进，直到达成真实硬件验收或触及明确的外部阻塞。每完成一个阶段，记录命令、退出码、证据路径和状态；若用户尚未提供开发板的实际 USB 访问能力，在所有可离线完成的任务结束后标记 `BLOCKED_EXTERNAL`，提供最短的人工操作指令，不得假装完成。保留原工程的可回滚基线。

不允许对宿主系统进行危险改动：未经单独授权，不得重刷未知 USB 设备、擦除 Flash/NVS、修改 Windows 启动/驱动签名策略、关闭 Secure Boot、运行 `bcdedit /set testsigning on`、安装来源不明的驱动、删除仓库外文件。对串口和烧录操作先识别目标，必须有唯一可验证的设备标识。安装第三方组件前核对来源及版本。不能访问 Windows GUI 时，输出明确可执行的 Windows 操作并将相应验收标记为待人工验证。

## 1. 背景与固定硬件条件

- 开发板：**Espressif ESP32-P4X-Function-EV-Board V1.6**（不是旧版 1.4 / 1.5.2）。
- 主芯片标识：ESP32-P4NRW32X，板载 32 MB PSRAM，实际芯片 revision 用 `esptool` 或启动日志确认；官方 V1.6 文档称 rev 3.1 或以上。
- 屏幕：开发套装配套 **7 英寸 1024 × 600 MIPI-DSI LCD**；触摸功能需要实际识别控制器与连线。
- 主开发机：Windows 11 + WSL2 Ubuntu；ESP-IDF 开发环境已经存在、能够使用，**不得无故重装**。
- 编译、自动化、版本管理放在 WSL2 Linux 文件系统，不能将 Linux 构建树放在 `/mnt/c/`。
- Windows 主机安装官方签名 IDD 驱动，运行扩展屏；USB Serial/JTAG 用于烧录和日志，独立 USB 2.0 HS Type-C 作为显示数据链路（480 Mbps），不能将显示设备透传给 WSL2。
- ESP32-P4X V1.6 与 `esp32_p4_function_ev_board` 板级定义可能存在差异；**禁止默认两者完全兼容**。

## 2. 项目目标与范围

### 2.1 必须交付（MVP）

1. 可重复构建的 ESP-IDF 设备固件，支持 V1.6 及其 1024×600 LCD。
2. Windows 11 安装官方预编译签名 IDD 驱动后，USB HS 设备能枚举，系统能识别第二显示器。
3. Windows 选择“扩展这些显示器”后可将应用窗口拖到 LCD，画面正确，连续显示，且不会异常复位。
4. 有完备的设备枚举、LCD 输出、性能、稳定性诊断与故障排查文件。
5. 有一键编译脚本、带设备确认的烧录步骤、配置版本清单、回滚方案、交付手册。

### 2.2 次级目标（MVP 之后）

- 触摸输入及 Windows 显示屏映射（若屏幕触摸硬件支持）。
- 画质 / 帧率 / USB 带宽与延迟调优（官方宣称 ESP32-P4 1024×600@60FPS，**仅作参考目标，不当作当前板卡已验收性能**）。
- USB 断开重连、睡眠唤醒、长时间连续运行测试。
- 可选音频、背光、快捷配置脚本。

### 2.3 明确不做

- 不自行开发新的 Windows 显示驱动，除非官方驱动经事实验证确实不适用，且获得额外授权。
- 不修改 USB 协议或自造虚拟显示解决方案，优先复用官方示例。
- 不把 ESP32-P4 当作原生 HDMI/DisplayPort 输入器件；它作为 USB 图像接收及显示设备。
- 首版不开发无线投屏、不开发独立 LVGL 监控面板、不做多屏拼接。

## 3. 官方依据（启动时实际检查最新代码）

- 官方示例：https://github.com/espressif/esp-iot-solution/tree/master/examples/usb/device/usb_extend_screen
- 官方示例 README：https://github.com/espressif/esp-iot-solution/blob/master/examples/usb/device/usb_extend_screen/README.md
- Windows 驱动说明：https://github.com/espressif/esp-iot-solution/blob/master/examples/usb/device/usb_extend_screen/windows_driver/README_cn.md
- V1.6 板卡手册：https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32p4/esp32-p4x-function-ev-board/user_guide.html
- Board Manager 旧版参考：https://docs.espressif.com/projects/esp-board-manager/en/latest/references/boards/esp32_p4_function_ev_board.html

官方示例当前文档所述事项（须在仓库固定 commit 上复核）：
- 工程路径 `examples/usb/device/usb_extend_screen`。
- 使用 `pip install esp-bmgr-assist`、`idf.py bmgr -l`、`idf.py bmgr -b esp32_p4_function_ev_board`；`bmgr` 自动设置 target，**不要再次 `set-target` 覆盖**。
- Board Manager 必须提供横向 `display_lcd`，RGB565 或 RGB888 framebuffer；可选 `lcd_touch`、`lcd_brightness`、`audio_dac`/`audio_adc`。
- 官方最大 FPS 与 JPEG 参数分别为 `CONFIG_USB_EXTEND_SCREEN_MAX_FPS` 和 `CONFIG_USB_EXTEND_SCREEN_JPEG_QUALITY`；实际选项须以本次 checkout 源码为准。
- P4 Rev <3.0 与 >=3.0 的固件配置不兼容；V1.6 不应启用 `CONFIG_ESP32P4_SELECTS_REV_LESS_V3`。
- Windows VID/PID：复合设备 `USB\\VID_303A&PID_2986`，纯显示设备 `USB\\VID_303A&PID_2987`。不得未核验配置就随意更换；以下载的官方签名驱动 INF 和实际描述符一致性为准。

## 4. 仓库管理与目录结构

工程根目录优先选择 `~/projects/p4-usb-display/`，若当前目录已有 git 仓库，先说明并在该仓库独立工作树或子目录操作，**不得覆盖已有文件**。建议结构：

```text
p4-usb-display/
├── README.md
├── AGENTS.md
├── TASKS.md
├── upstream/                    # 固定版本的官方仓库或 submodule
├── firmware/                    # 板卡差异补丁、配置/脚本；不复制无关源码
│   ├── board/                   # 自定义板卡或 Board Manager amend（若需）
│   ├── sdkconfig.defaults
│   └── patches/
├── scripts/
│   ├── audit_env.sh
│   ├── build.sh
│   ├── inspect_build.sh
│   └── collect_logs.sh
├── docs/
│   ├── BASELINE.md
│   ├── BOARD_V16_AUDIT.md
│   ├── WSL_FLASHING.md
│   ├── WINDOWS_DRIVER.md
│   ├── TROUBLESHOOTING.md
│   ├── ACCEPTANCE.md
│   ├── HANDOFF.md
│   └── DECISIONS.md
└── evidence/                    # 按里程碑归档日志/截图/输出
```

必须保存上游 Git commit hash、ESP-IDF 版本和 commit、Board Manager 版本、实际 `sdkconfig` 差异、驱动包版本、生成文件散列 (SHA256)。禁用密钥/令牌入库；日志清理设备序列号等无关敏感值后公开。

## 5. 阶段任务（按依赖执行）

### P0 — 基线审计（优先级 P0）

**自动执行：**
- `uname -a`, `pwd`, `git --version`, `python3 --version`, `idf.py --version`；定位当前 ESP-IDF 路径和激活脚本。
- 识别 WSL2 环境，并确认工程根目录在 Linux FS。
- 检查已安装依赖，不要重复全局安装；优先使用 ESP-IDF 自带 Python 环境。
- 下载官方仓库或复用现有 checkout，`git rev-parse HEAD` 锁定 commit，递归子模块按官方要求准备。
- 读取本 commit 的 `README.md`、`idf_component.yml`、Kconfig、USB 描述符、板级定义，核对例程依赖与板卡支持情况。
- 执行 `idf.py bmgr -l`，检查是否有明确的 P4X V1.6 板级定义；记录不存在时的证据。

**产物：** `docs/BASELINE.md`、`docs/DECISIONS.md`、`evidence/P0/`。

**验收：** 明确 IDF / 固件 / bmgr 版本矩阵，当前工程能执行配置命令；缺组件时记录精确原因。

### P1 — V1.6 板级差异审核与 LCD 点亮（优先级 P0，依赖 P0）

**自动执行：**
- 对照 V1.6 官方硬件手册与 `esp32_p4_function_ev_board` 实际定义，审查 LCD 时序、MIPI DSI、初始化、电源、GPIO27 RST_LCD、GPIO26 PWM/背光、触摸 I2C 与复位、PSRAM、USB HS 端口分配。
- 不能仅因两个型号相似就声称兼容；构建**差异表**，每个差异注明官方出处和风险。
- 如支持 V1.6 专用板卡，直接选用；否则优先创建 Board Manager amend 或独立板级定义，避免直接修改上游源代码。
- 配置 RGB565 作为初始 framebuffer 方案；如官方配置不同，记录保持官方默认的理由。
- 若可接入硬件，先运行独立 LCD 基础测试（色条/颜色填充），查看正确分辨率、稳定显示及背光。

**可用基础命令：**
```bash
# 在官方示例目录，确保已激活 ESP-IDF
python -m pip install esp-bmgr-assist
idf.py bmgr -l
idf.py bmgr -b esp32_p4_function_ev_board
idf.py menuconfig
idf.py build
```
`esp32_p4_function_ev_board` 只是兼容性起点。若需更换板卡，先按官方 README 执行 `idf.py bmgr -x`、`idf.py fullclean` 等并重新生成配置。

**产物：** `docs/BOARD_V16_AUDIT.md`、板级配置或补丁、LCD 实测证据（若已接入）。

**验收：** V1.6 配置有清晰来源，静态配置无已知引脚冲突，构建完成；LCD 实测独立记录，未接设备不得声称通过。

### P2 — USB 扩展屏设备固件（优先级 P0，依赖 P1）

**自动执行：**
- 尽可能原样复用官方 `usb_extend_screen` 的 JPEG 解码、USB 传输和主循环逻辑。
- 审核 USB HS 控制器选择、Endpoint 配置、VID/PID/接口描述符、各类功能的条件编译、framebuffer 内存预算。
- 第一版优先显示基本功能；如果因复合设备音频/触摸导致不稳定，可构建明确命名的 display-only 诊断变体，但必须同步核对 `PID=0x2987` 与 Windows INF 的匹配，不能仅改 PID 而忽略描述符与功能编译。
- 确保 Rev 3.x 配置，不启用 pre-3.0 兼容选项。
- 添加合理日志，避免每帧打印；保留错误计数、USB 枚举、JPEG 失败、帧率统计、PSRAM 状态。

**产物：** 固件 `.bin`、对应烧录元信息 `flasher_args.json`（如构建产生）、配置 diff、生成文件 SHA256、构建日志。

**验收：** 干净构建成功；无未经解释的警告/错误；设备启动、USB HS 枚举、LCD 实显均需独立硬件测试证据。

### P3 — 安全烧录与设备端验证（优先级 P0，依赖 P2）

**自动执行（仅在设备可访问且身份唯一时）：**
- 识别 USB Serial/JTAG 对应串口；确认 `esptool` 识别芯片、revision、flash，输出识别日志。
- 在烧录前保存固件构建及配置文件；如果可以安全备份当前 Flash 且容量、权限充足，可建议备份，但不强制覆盖。
- 明确记录真实使用的端口和目标 MAC/芯片标识，确保不误刷其他设备。
- 使用 `idf.py -p PORT flash monitor`；**不要执行 `erase-flash`**。
- 断电重启、串口确认 LCD + USB 初始化，记录复位原因及错误。
- 若串口被 Windows 占用，提供 Windows 原生烧录和 WSL2 `usbipd-win` 透传二选一操作说明；不要擅自夺取用户的其他 USB 设备。

**产物：** `docs/WSL_FLASHING.md`、`evidence/P3/`（识别/烧录/启动日志）。

**验收：** 设备标识正确、实际烧录成功、启动稳定、LCD 显示正确；若硬件不可达，状态 `BLOCKED_EXTERNAL`，并提供恰好所需的接线/命令。

### P4 — Windows 11 IDD 驱动集成（优先级 P0，依赖 P3）

**可自动完成的部分：**
- 审核官方 `windows_driver/README_cn.md` 的驱动下载、签名、VID/PID 和安装说明；记录实际下载链接与哈希；不得声称未验证的第三方包已安装。
- 生成用户可执行的 `docs/WINDOWS_DRIVER.md`，包含驱动安装、设备管理器、PowerShell `Get-PnpDevice`/设备硬件 ID 检查、显示设置、显控排障和恢复卸载方法。
- 如 Agent 具有 Windows 命令执行权限，可读取系统状态与枚举证据，但驱动安装需依系统权限和用户授权策略进行，不得默默关闭驱动签名检查。
- USB HS 显示 Type-C 留在 Windows，**不通过 usbipd 透传到 WSL2**。

**人工/设备侧操作：** 下载并安装乐鑫链接的预编译签名驱动；将 USB HS Type-C 接 Windows；设备管理器和显示设置查看结果。

**产物：** 驱动安装手册、VID/PID 记录、设备枚举证据、Windows 第二显示器截图（如可取得）。

**验收：** Windows 11 无驱动错误，真实出现第二显示器，1024×600 正常，能选“扩展”而非仅复制。未获得 Windows 验证不可宣称通过。

### P5 — 触摸、性能与稳定性（优先级 P1，依赖 P4）

设计并执行以下可复现测试（若暂无硬件，生成执行清单和待填记录，标记 `NOT_RUN`）：

| 测试编号 | 测试项 | 通过标准 |
|---|---|---|
| T01 | 横屏 1024×600 | 画面无错行、裁剪、明显色彩错误 |
| T02 | Windows 扩展桌面 | 能拖动记事本/终端窗口并持续刷新 |
| T03 | 静态+滚动+视频 | 记录帧率/延迟/负载，不预设必达 60FPS |
| T04 | 触摸（硬件支持时） | 正确映射至第二屏，多点测试（如适用） |
| T05 | USB 拔插 10 次 | 无不可恢复设备故障；记录每次结果 |
| T06 | 连续运行 2 小时 | 无异常重启、持续花屏、USB 永久失联 |
| T07 | Windows 睡眠唤醒 | 记录恢复成功率与异常 |
| T08 | 带宽/质量参数 | 比较至少两档 FPS/JPEG 质量及主观可读性 |

初始调优基线可设 RGB565、1024×600、默认 JPEG 质量和官方默认 FPS；先在基线上完成稳定性验证，再逐项修改。禁止未经实测发布帧率/端到端延迟数字。

**产物：** `docs/ACCEPTANCE.md`、测试表、性能日志和配置建议。

### P6 — 自动化、回归和最终交付（优先级 P1，依赖 P0–P5 已可执行部分）

- `scripts/audit_env.sh`：只读环境、版本及工具检查。
- `scripts/build.sh`：激活现有 IDF，检查仓库提交/依赖，执行可复现构建；支持 `--clean` 和清晰的出错提示，不覆盖未知文件。
- `scripts/inspect_build.sh`：输出产物路径、大小、SHA256、Flash 参数、目标版本，校验 `sdkconfig` 关键项。
- `scripts/collect_logs.sh`：整理本项目日志到 `evidence/`，避免提交个人敏感信息。
- `README.md`：从零复现的最短路径。
- `docs/HANDOFF.md`：已完成、未完成、明确阻塞、下一条可执行命令。
- 给每个修改生成 git diff；允许建立安全的本地提交，但**不允许自动 force push / 自动覆盖远端仓库**。

**验收：** 任意一个新的 Agent 可只凭 README + 本任务书 + 锁定依赖复现编译并判断测试进度。

## 6. 状态机、Agent 自治与防止原地踏步

任务状态只能是：`TODO`、`RUNNING`、`PASS`、`FAILED`、`BLOCKED_EXTERNAL`、`BLOCKED_TECHNICAL`、`SKIPPED`。不要把未测试的内容记为 PASS。

运行规则：
1. 按依赖选择最高优先级且可执行的任务，直接调用工具；每个阶段不超过一次纯文字规划。
2. 每一轮操作都必须产生至少一个真实可验证变化：文件 diff、构建产物、测试结果、明确的外部事实或新的排障证据。
3. 相同报错最多重复 2 次，第三次必须改变诊断方法或记录阻塞，不允许无限循环。
4. 遇到问题按以下顺序检查：日志 → 具体版本 → 源码/配置 → 官方文档 → 最小复现实验；禁止凭猜测大面积重构。
5. 外部阻塞时继续处理其他不依赖硬件的任务；全部可执行工作完成后输出阻塞报告，**不得声称继续后台运行**。
6. 使用最小必要权限；硬件重刷、驱动安装与系统更改按第 0 节安全限制执行。
7. 每次运行维护 `TASKS.md`、`docs/HANDOFF.md`，保证 Agent 中断后可恢复。

进度回复格式：
```text
[阶段] Pn / [状态] PASS|FAILED|BLOCKED_...
真实变更：<提交/文件/配置>
验证证据：<命令、退出码、日志路径>
风险/阻塞：<具体事实>
下一步：<下一条真正能执行的操作>
```

## 7. 最终交付验收门槛

**代码完成（CODE_READY）**：固定版本 + 干净构建成功 + 配置可复现 + 自动化脚本成功 + 文档完整。此状态不等于可用显示器。

**硬件功能完成（DEVICE_READY）**：CODE_READY + V1.6 真实烧录/启动 + LCD 1024×600 实显 + USB HS 枚举。

**产品级 MVP 完成（MVP_ACCEPTED）**：DEVICE_READY + Windows IDD 正常 + 第二显示器扩展桌面实测通过 + T01/T02/T05/T06 通过。

**增强完成（ENHANCED）**：MVP_ACCEPTED + 触摸（若支持）、质量优化和可选音频验收。

任何阶段不得以“文档已编写”“代码已改”“编译已成功”替代 USB Windows 双屏的真实验收。

## 8. 启动 Agent 的第一条执行提示

```text
请读取当前项目中的 ESP32_P4_USB_Extended_Display_AGENT_TASK.md 并以其为最高项目级开发任务约束。立即从 P0 执行，使用已有 WSL2 ESP-IDF 环境，不要重新安装系统或无故重构官方工程。优先锁定官方 usb_extend_screen commit，审计 ESP32-P4X V1.6 与旧版板级定义的差异，执行可用的编译与静态检查，并持续完成所有可自动完成的阶段。所有硬件和 Windows 实测状态必须有证据，不要伪造。遇到外部设备不可访问时记录 BLOCKED_EXTERNAL，同时推进其他无依赖任务。维护 TASKS.md 和 docs/HANDOFF.md，最终报告文件、命令、测试和实际阻塞。
```
