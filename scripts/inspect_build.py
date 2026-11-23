import hashlib
import json
import sys
from pathlib import Path

from elftools.elf.elffile import ELFFile


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def descriptor_bytes(elf, name):
    symbols = elf.get_section_by_name(".symtab")
    symbol, = symbols.get_symbol_by_name(name)
    section = elf.get_section(symbol["st_shndx"])
    offset = symbol["st_value"] - section["sh_addr"]
    return section.data()[offset:offset + symbol["st_size"]]


def verify_usb(elf_path, profile, pid):
    touch_enabled = profile != "display-only"
    with elf_path.open("rb") as stream:
        elf = ELFFile(stream)
        device = descriptor_bytes(elf, "desc_device")
        config = descriptor_bytes(elf, "desc_fs_configuration")
        strings = descriptor_bytes(elf, "string_desc_arr")
        pointer_size = elf.elfclass // 8
        touch_report = descriptor_bytes(elf, "desc_hid_report") if touch_enabled else b""
    require(len(device) == 18 and device[:2] == bytes([18, 1]), "USB device descriptor malformed")
    require(int.from_bytes(device[8:10], "little") == 0x303A, "USB VID differs")
    require(int.from_bytes(device[10:12], "little") == pid, "USB PID differs")
    require(device[15] == 2 and len(strings) >= 5 * pointer_size
            and strings[2 * pointer_size:3 * pointer_size] == strings[4 * pointer_size:5 * pointer_size],
            "USB product and vendor interface must share the display metadata")
    require(int.from_bytes(config[2:4], "little") == len(config), "USB configuration length differs")
    interfaces = {}
    vendor_endpoints = {}
    hid_endpoints = {}
    hid_report_length = None
    offset = 0
    interface = None
    while offset < len(config):
        length, kind = config[offset:offset + 2]
        require(2 <= length <= len(config) - offset, "USB descriptor length invalid")
        desc = config[offset:offset + length]
        if kind == 4:
            interface = desc[2]
            interfaces[interface] = desc[5]
            if interface == 0:
                require(desc[8] == 4, "Vendor interface string index differs")
        if kind == 5 and interface == 0:
            require(desc[3] & 3 == 2, "USB vendor endpoint is not bulk")
            vendor_endpoints[desc[2]] = int.from_bytes(desc[4:6], "little")
        if interface == 1 and kind == 0x21:
            require(length == 9 and desc[6] == 0x22, "USB HID descriptor malformed")
            hid_report_length = int.from_bytes(desc[7:9], "little")
        if interface == 1 and kind == 5:
            require(desc[3] & 3 == 3, "USB HID endpoint is not interrupt")
            hid_endpoints[desc[2]] = int.from_bytes(desc[4:6], "little")
        offset += length
    require(config[4] == len(interfaces), "Interface count differs")
    require(interfaces.get(0) == 0xFF and vendor_endpoints == {0x01: 512, 0x81: 512},
            f"Vendor HS descriptor differs: {interfaces}, {vendor_endpoints}")
    expected_classes = {0xFF}
    if touch_enabled:
        expected_classes.add(3)
        require(interfaces.get(1) == 3 and hid_endpoints == {0x82: 512},
                f"Unexpected HID interface or endpoints: {interfaces}, {hid_endpoints}")
        require(hid_report_length == len(touch_report) and touch_report.startswith(bytes.fromhex("05 0d 09 04 a1 01"))
                and bytes.fromhex("09 55") in touch_report, "HID touchscreen report descriptor differs")
    if profile == "composite":
        expected_classes.add(1)
    require(set(interfaces.values()) == expected_classes, f"Unexpected USB interfaces: {interfaces}")
    print(f"USB ELF descriptor: 303A:{pid:04X}, classes={interfaces}, vendor bulk OUT 01 / IN 81 at 512 B")
    if touch_enabled:
        print(f"USB HID touchscreen: interface 1, interrupt IN 82 at 512 B, {len(touch_report)} B report descriptor")


def main():
    root, profile = Path(sys.argv[1]), sys.argv[2]
    out = root / "out" / profile
    sdkconfig = (out / "sdkconfig").read_text().splitlines()
    config = dict(line.split("=", 1) for line in sdkconfig if line.startswith("CONFIG_"))
    touch_enabled = profile != "display-only"
    pid = 0x2986 if touch_enabled else 0x2987
    expected = {
        "CONFIG_IDF_TARGET": '"esp32p4"',
        "CONFIG_ESP32P4_REV_MIN_FULL": "300",
        "CONFIG_ESP32P4_REV_MAX_FULL": "399",
        "CONFIG_ESPTOOLPY_FLASHSIZE_16MB": "y",
        "CONFIG_SPIRAM": "y",
        "CONFIG_SPIRAM_MODE_HEX": "y",
        "CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG": "y",
        "CONFIG_APP_REPRODUCIBLE_BUILD": "y",
        "CONFIG_TINYUSB_RHPORT_HS": "y",
        "CONFIG_ESP_BOARD_DEV_DISPLAY_LCD_SUPPORT": "y",
    }
    for key, value in expected.items():
        require(config.get(key) == value, f"{key} expected {value}, found {config.get(key)}")
    for key in ["CONFIG_ESP32P4_SELECTS_REV_LESS_V3", "CONFIG_SECURE_BOOT", "CONFIG_SECURE_FLASH_ENC_ENABLED"]:
        require(config.get(key) != "y", f"{key} must be disabled")
    require((config.get("CONFIG_HID_TOUCH_ENABLE") == "y") == touch_enabled,
            f"HID touch setting differs for {profile}")
    require((config.get("CONFIG_UAC_AUDIO_ENABLE") == "y") == (profile == "composite"),
            f"USB audio setting differs for {profile}")
    if touch_enabled:
        require(config.get("CONFIG_ESP_BOARD_DEV_LCD_TOUCH_SUB_I2C_SUPPORT") == "y"
                and config.get("CONFIG_ESP_LCD_TOUCH_MAX_POINTS") == "5",
                "Expected a five-contact I²C touch controller")
    require(int(config["CONFIG_TUSB_VID"], 16) == 0x303A, "Configured VID differs")
    require(int(config["CONFIG_TUSB_PID"], 16) == pid, "Configured PID differs")
    print(f"Profile: {profile} | ESP32-P4 revision 3.00–3.99 | 16 MB flash | Hex PSRAM | Serial/JTAG console")
    print(f"Advertised JPEG quality: {config['CONFIG_USB_EXTEND_SCREEN_JPEG_QUALITY']}; "
          f"FPS cap: {config['CONFIG_USB_EXTEND_SCREEN_MAX_FPS']}")
    elf = out / "usb_touch_screen.elf"
    verify_usb(elf, profile, pid)
    meta = json.loads((out / "flasher_args.json").read_text())
    require(meta["extra_esptool_args"]["chip"] == "esp32p4", "Flash chip differs")
    require(meta["flash_settings"]["flash_size"] == "16MB", "Flash capacity differs")
    print(f"Flash settings: {json.dumps(meta['flash_settings'], sort_keys=True)}")
    for address, path in meta["flash_files"].items():
        print(f"{address} {path}")
    files = [*meta["flash_files"].values(), "flasher_args.json", "flash_args", "sdkconfig", elf.name]
    hashes = []
    for name in files:
        path = out / name
        require(path.is_file() and path.resolve().is_relative_to(out.resolve()), f"Missing or invalid {path}")
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        print(f"{len(data):>9} B  {digest}  {path}")
        hashes.append(f"{digest}  {name}")
    (out / "SHA256SUMS").write_text("\n".join(hashes) + "\n")


if __name__ == "__main__":
    main()
