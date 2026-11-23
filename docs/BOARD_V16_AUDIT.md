# ESP32-P4X V1.6 板级审核

目标为 ESP32-P4X-Function-EV-Board V1.6、ESP32-P4NRW32X 和套件 7 英寸 MIPI DSI LCD。Board Manager 0.7.6 配合 `esp_boards` 0.7.3 列出 43 项，其中旧定义对应 v1.5.2，`esp32_p4x_c5_function_ev` 对应另一块板。使用旧定义加 [V1.6 amend](../firmware/board/board_amend.yaml)，生成代码记录见 [P1](../evidence/P1/)。[V1.6 用户手册](https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32p4/esp32-p4x-function-ev-board/user_guide.html) · [Board Manager 旧版参考](https://docs.espressif.com/projects/esp-board-manager/en/latest/references/boards/esp32_p4_function_ev_board.html)

| 项目 | V1.6 官方资料 | 锁定旧定义与本项目配置 | 风险及验证 |
|---|---|---|---|
| 芯片与内存 | V1.6 资料标注 Rev 3.1 或以上，SPI Flash 16 MB，PSRAM 32 MB | 旧定义 16 MB、Hex PSRAM 200 MHz。amend 明确启用 Rev ≥3.0 路径和 16 MB。镜像头范围 3.00–3.99 | 烧录仅在实际识别到 V1.6、3.1–3.99 和 16 MB 后执行。以 boot log 核对 PSRAM |
| DSI 布线与电源 | DSI 连 LCD 转接板 J3，使用反向 FFC。LCD 转接板 J1 独立 USB 供电；采用主板 5 V 供电时，按手册接 5 V/GND | DSI bus 0、双 lane、1000 Mbps/lane。内部 LDO3 2500 mV 用于 D-PHY。LCD 转接板的 5 V 独立于 D-PHY LDO | 上电前检查 FFC 方向和 DSI/CSI 标签，查看屏幕初始化和背光 |
| LCD 与初始化 | 套件 7 英寸 1024×600，资料附 EK79007AD 和 LCD 转接板原理图 | 使用固定版 EK79007 驱动、虚拟通道 0、DPI 48 MHz、H porch/pulse 120/10/120、V 20/1/20、RGB565_LE、1 个 DPI FB，保留 DMA2D | 手册确认面板型号和连接，时序来自已锁定的同套件板级定义。实机通过色条确认色序、横屏和边界 |
| LCD 复位与背光 | J1 GPIO27→转接板 J6 RST_LCD、GPIO26→J6 PWM | GPIO27 低有效；GPIO26 由 LEDC 驱动并在初始化后开启。amend 显式指定两脚 | 两根杜邦线均需接。转接板供电或 PWM 缺失可造成黑屏 |
| 触摸 I²C 与复位 | V1.6 手册确认电容触摸；板头有 GPIO7/8 | GT911、I²C0 SDA7/SCL8，候选 7 位地址 0x5D/0x14；无专用复位和中断 GPIO，轮询读取 | 触控版在实机从 0x5D 读到 GT911 产品 ID 并完成初始化。[实机证据](../evidence/P5/display-touch.txt) |
| USB 连接 | FS Type-C、Serial/JTAG Type-C、HS Type-C 各有用途。HS Type-A 与 HS Type-C 共享控制器 | 显示切到 OTG UTMI HS，日志和烧录走 Serial/JTAG。HS Type-A 留空 | P3 确认串口，P4 在 Windows 插 HS Type-C 并核对描述符和速度 |
| 其他外设 | V1.6 带网口、microSD、CSI、音频 | 旧定义的 EMAC TXD1 和 BOOT 共用 GPIO35。amend 跳过 Ethernet、BOOT、SD 和 CSI 设备，未改动屏相关线路 | 最终生成报告无 IO 冲突。复合版的触摸及音频仍需实测 |

资料见 [V1.6 硬件说明与接线](https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32p4/esp32-p4x-function-ev-board/user_guide.html) · [V1.6 芯片与 Flash 规格](https://docs.espressif.com/projects/arduino-esp32/en/latest/boards/ESP32-P4X-Function-EV-Board.html) · [LCD 转接板原理图](https://dl.espressif.com/dl/schematics/esp32-p4-function-ev-board-lcd-subboard-schematics.pdf) · [LCD 模组规格](https://dl.espressif.com/dl/schematics/display_datasheet.pdf)

## 内存与静态 USB 核验

可见 DPI 帧 1,228,800 B。硬件 JPEG 解码预留三帧，每帧按 1024×608×2 B 分配，合计 3,735,552 B。六个输入缓冲合计 1,800,000 B。三项约 6.45 MiB，实际 PSRAM 占用还包括对齐、堆、任务和其他对象。IDF 的 JPEG 输入和输出分配使用 PSRAM。启动日志报告可用 PSRAM 堆，板载 32 MB 的运行证据取自 IDF PSRAM 初始化行。

三个版本均使用官方 Vendor 协议。Vendor 接口为 0，EP1 OUT 和 EP1 IN，HS 包长各 512 B。纯显示版 303A:2987 提供 Vendor 接口。触控版 303A:2986 增加 HID 接口 1，复合版在相同 PID 下进一步提供 UAC。对 303A:2986，IDD 绑定 `MI_00`。通过 ELF 中实际编译的描述符进行校验。设备实际连接速度通过 `USB Mount: high-speed` 与 Windows USB 枚举确认。

## 上电色条

将显示用 HS 线暂时拔开，给开发板和 LCD 转接板供电，复位一次。应看到从左到右红、绿、蓝、白、黑、黄、青、品红八条色带，横屏铺满。串口上应显示 `resolution=1024x600, framebuffer=RGB565_LE` 和 `LCD boot pattern submitted`。拍摄可辨别边缘与颜色的照片，配合上电日志记入 P1。本次串口两次记录色条提交，用户确认 LCD 实显示正常。该轮证据由用户目视确认与串口日志组成。见 [P3 实测](../evidence/P3/hardware-run.txt)。
