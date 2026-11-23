# Windows 11 IDD 集成

Windows 11 已绑定用户安装的 IDD 1.2.25.2（`oem2.inf`），设备状态正常。实测 USB 2.0 High-Speed（480 Mbps），第二屏为 1024×600 扩展桌面。用户确认移入副屏的测试窗口正常显示并刷新。[驱动状态](../evidence/P4/windows-driver-installed.log) · [扩展桌面实测](../evidence/P4/extended-desktop-test.txt)

首次安装后，旧固件在 Windows 表现为 320×240。驱动公开源码从 USB 产品字符串读取显示模式，旧固件只在 Vendor 接口字符串提供参数。当前固件同时提供两处相同元数据，并按驱动约定以 KiB 通告帧长度上限（`Bl292`）；本次实机更新后 Windows 使用 1024×600。[驱动读取逻辑](https://github.com/chuanjinpang/win10_idd_xfz1986_usb_graphic_driver_display/blob/c2de0f56f778904d663d8e2dc5a71b4a6b270ecc/win10_idd_xfz1986_usb_graphic_driver/idd_xfz1986_usb_graphic/usb_transf.cpp) · [旧固件串口证据](../evidence/P4/idf-320x240-before-fix.log)

## 驱动包审核

| 项目 | 结果 |
|---|---|
| 官方链接文件 | `xfz1986_usb_graphic_250224_rc_sign.exe`，SHA256 `268a9f8b9e7f7ef4223ee33386e6396cc1d470026188104aad93d8b96af52501` |
| 已提取 INF | `xfz1986_usb_graphic.inf`，`DriverVer=02/24/2025,1.2.25.2`，平台 `NTamd64` |
| INF 硬件 ID | 复合 `USB\VID_303A&PID_2986&MI_00`，纯显示 `USB\VID_303A&PID_2987` |
| 安装器 Authenticode | 本机 `Valid`，签名者 Airspace Intelligent Technology (Changzhou) Co., Ltd. |
| 驱动目录 Authenticode | 本机 `UnknownError`，时间戳签名和/或证书无法验证或已损坏。目录含 Pikachu Time Sub CA，颁发者 Pikachu Test CA RSA |
| 解包脚本 | 会调用 `PikachuTestCert.exe /SILENT`，随后运行 `dpinst.exe` |

完整记录见 [P4 证据](../evidence/P4/)。来源见 [固定版本驱动说明](https://github.com/espressif/esp-iot-solution/blob/f721a40c032f6168844fe3bd321bc182e2593348/examples/usb/device/usb_extend_screen/windows_driver/README_cn.md) · [乐鑫发布的下载文件](https://dl.espressif.com/AE/esp-iot-solution/xfz1986_usb_graphic_250224_rc_sign.exe)。

请使用乐鑫提供且能通过本机现有信任策略校验的替代包。对候选包核对官方来源、哈希、匹配的 INF 和目录签名；如有 Windows SDK，使用 `signtool verify /v /c driver.cat driver.inf` 复核 Windows 驱动验证策略及文件绑定。保留默认驱动签名策略与 Secure Boot。表中签名结果采集于用户安装之前。已独立确认当前 Windows 上的驱动加载与显示功能。[Microsoft SignTool 文档](https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool)

## 合规驱动包的安装与验证

1. 准备完整可信驱动包后，打开管理员 PowerShell，执行 `pnputil /add-driver .\xfz1986_usb_graphic.inf /install`。设备应绑定该 INF。在安装前后查看设备管理器的 **显示适配器** 和 **监视器**，有错误时记录设备状态和错误代码。
2. 将 V1.6 的 **HS USB 2.0 Type-C** 用数据线接 Windows。该口留在 Windows。HS Type-A 保持空闲。Serial/JTAG 可继续留给 WSL 监视串口。
3. 普通 PowerShell 枚举匹配的硬件 ID，分享输出时隐藏设备实例串号。

   ```powershell
   Get-PnpDevice -PresentOnly |
     Where-Object InstanceId -Match '^USB\\VID_303A&PID_298[67]' |
     ForEach-Object {
       $_ | Format-Table Status,Class,FriendlyName
       (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_HardwareIds).Data
       (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_DriverInfPath).Data
     }
   ```

4. 打开 **设置 → 系统 → 显示**，确认出现第二屏并选 **扩展这些显示器**。选副屏设置横向 1024×600。拖动记事本到副屏，滚动并保存显示设置截图和 LCD 照片。依据 [验收表](ACCEPTANCE.md) 记录拔插和连续运行。
5. 若要撤销驱动，用 `pnputil /enum-drivers` 核实对应原始 INF、发布名称和版本，再拔 HS 线，管理员执行 `pnputil /delete-driver oemNN.inf /uninstall`。只替换为核实后的 oem 编号。[Microsoft PnPUtil 命令](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax)

设备管理器无条目时先查设备端 `USB Mount`、HS 线、供电与接口。硬件 ID 正确而驱动报错时，检查驱动目录信任、架构适配及 `%SystemRoot%\inf\setupapi.dev.log` 中设备对应的安装事件。

可以用 PowerShell 运行 [Windows USB 链路检查脚本](../scripts/verify_windows_usb.ps1)。脚本仅针对纯显示版的设备 ID，通过其上一级集线器读取已协商速率和当前配置值。[Microsoft USB 集线器接口](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/usbioctl/ni-usbioctl-ioctl_usb_get_node_connection_information_ex)

当前实测使用 [30 秒窗口测试脚本](../scripts/smoke_windows_display.ps1)，会将专用测试窗口从主屏移到唯一的 1024×600 副屏，再自动关闭。
