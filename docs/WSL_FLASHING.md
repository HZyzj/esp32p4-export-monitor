# V1.6 安全烧录与回滚

1. 查看板背 V1.6 丝印。断电接好 DSI 排线、RST_LCD、PWM 和 LCD 转接板供电。首次接一根数据线到开发板标为 **USB Serial/JTAG** 的 Type-C。显示 HS 口在 Windows 使用，初始化色条前可先留空。接线与端口见 [官方 V1.6 手册](https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32p4/esp32-p4x-function-ev-board/user_guide.html)。
2. 在 Windows PowerShell 中执行 `usbipd list`。用单次拔插确认 V1.6 对应的 BUSID 和产品名，通常为 `303a:1001`。管理员 PowerShell 需要对**这一个 BUSID**执行 `usbipd bind --busid <BUSID>`。在 WSL 打开时执行 `usbipd attach --wsl --busid <BUSID>`。设备可能需要重新 attach。安装和透传步骤见 [Microsoft WSL USB 指南](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)。
3. WSL 中用 `ls -l /dev/serial/by-id/ /dev/ttyACM*` 确认新出现的对应设备，优先采用稳定的 by-id 路径。若无访问权限，在自己的 WSL 会话检查组权限和 udev。关闭占用同一个设备的串口监视器。
4. 在工程根目录执行下列命令。若读取失败，按住 BOOT，按一下 Reset，再释放 BOOT。保留 ACTUAL_MAC 在本地。检查识别文本中 chip 为 ESP32-P4、revision ≥3.1 且 <4.0、Flash 为 16 MB。

   ```bash
   scripts/flash.sh identify /dev/ttyACM0
   scripts/flash.sh flash /dev/ttyACM0 ACTUAL_MAC
   ```

   根据刚才检测结果替换端口和 `ACTUAL_MAC`。第二条命令先校验固件哈希、重读芯片身份和检查端口映射，再运行 `idf.py -p PORT flash monitor`。用 Ctrl+] 退出串口监视器。

5. 首次复位后核对板型、修订版、PSRAM、复位原因和 LCD 色条。拔掉板卡及 LCD 的供电后重新连接，记录第二次完整启动。HS 线接入 Windows 后查看 USB mount。导出记录用 `scripts/collect_logs.sh P3 evidence/P3/private/flash-monitor.XXXXX`，分享前复核脱敏结果。

## 可选原固件备份与回滚

读备份需要先完成第 4 步身份核对。确认未启用 Flash Encryption 或 Secure Boot 后，可在 WSL 从**同一确认串口**读取整片镜像到项目私有目录。

```bash
source scripts/env.sh
activate_idf
umask 077
mkdir -p evidence/P3/private
backup="evidence/P3/private/factory-$(date +%Y%m%d-%H%M%S).bin"
python -m esptool --chip esp32p4 --port /dev/ttyACM0 read_flash 0x0 0x1000000 "$backup"
sha256sum "$backup" > "$backup.sha256"
```

本次已从 COM6 对应的 Rev 3.2 样机读取 16 MB 并通过 SHA256 校验，备份留在 `evidence/P3/private/`。整片备份可能含 NVS 数据。保留在私有目录。回滚首选该 V1.6 的已知原厂固件及官方烧录地址，或者同一块设备的已验证备份。恢复整片备份会覆盖应用及数据，执行前需确认目标 MAC、备份散列、Flash 安全状态及授权。已有项目固件回退可重建相应固定版本并使用设备确认脚本。工程的正常烧录使用构建生成的地址，禁止额外整片擦除。

## Windows 原生备选

需要 ESP-IDF 终端或同一版本 esptool 4.14.0。把所选 `out/<配置>` 里的 `flash_args`、三个 BIN 及其相对目录复制到 Windows。通过设备管理器区分 Serial/JTAG 的 COM 号，若已透传先使用 `usbipd detach --busid <BUSID>`。在 Windows PowerShell 进入该产物目录，替换 COM 号并在读到相同芯片、修订版、Flash 和 MAC 后执行第二条。

```powershell
python -m esptool --chip esp32p4 --port COM7 flash_id
python -m esptool --chip esp32p4 --port COM7 -b 460800 --before default_reset --after hard_reset write_flash '@flash_args'
```

随后用 115200 串口监视器复位看日志。设备在 Windows 和 WSL 之间只能由一边占用 Serial/JTAG。
