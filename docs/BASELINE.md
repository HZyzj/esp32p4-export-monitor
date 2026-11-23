# 环境与版本基线

工作区位于 WSL2 Ubuntu 的 ext4，`/home/yzj/project/esp32p4-mon`。启用工具前的 Python 为 3.11.15，Git 2.34.1。原任务书保留，以 [原始文件散列](../evidence/P0/original-task.sha256) 记录。任务根目录原本没有可用的 Git 仓库。固定上游位于 `upstream/esp-iot-solution`，构建使用独立工作树 `upstream/usb-display-work`。ESP-IDF checkout、venv、所需新增工具均位于 `upstream/`，复用了已有的匹配 ROM ELF。

| 项目 | 锁定值和说明 |
|---|---|
| 官方示例 | `f721a40c032f6168844fe3bd321bc182e2593348`，官方 master 的 2026-11-19 提交。示例 manifest 版本 0.3.0，无 Git 子模块 |
| 原 ESP-IDF | `1bfe1595fa6bc64dcd5241047dc677cc194ecdaf`，`v5.4.2-610-g1bfe1595fa-dirty`。原 checkout 中 `export.sh` 已有本地修改。默认激活找不到 3.11 venv，旧 3.10 venv 的链接实际进入 Python 3.11 |
| 构建 ESP-IDF | `v5.4.4`，`296b6eab9445fd720e71aecab961e2d3fbca9944`。递归子模块与 Git 锁定一致 |
| RISC-V 工具链 | `esp-14.2.0_20260121`。由 IDF tools manifest 指定 |
| Python | 3.11.15，现场版本见 [Python 依赖锁](../firmware/python-requirements.lock)；Component Manager 2.5.2，esptool 4.14.0 |
| Board Manager | CLI 插件 `esp-bmgr-assist` 0.8.4，组件 `esp_board_manager` 0.7.6，`esp_boards` 0.7.3 |
| LCD 与 USB | EK79007 1.0.4，TinyUSB 0.19.0~3；registry 组件及哈希详见 [组件锁](../firmware/dependencies.lock) |
| Windows IDD | 1.2.25.2，2025-02-24，amd64。散列与本机签名状态见 [P4](../evidence/P4/) |

`idf.py bmgr -l` 在 0.7.6 上成功，见 [板卡列表](../evidence/P0/board-list.log)。`idf.py bmgr -b esp32_p4_function_ev_board -a ...` 生成成功，见 [板级生成日志](../evidence/P1/board-generate.log)。命令、实际退出和复现路径见 [任务记录](../TASKS.md)。

### 维护上游基线

构建脚本验证两个 checkout，工作树仅应用 [项目补丁](../firmware/patches/0001-lcd-and-usb-diagnostics.patch)。项目交付文件的新增差异见 [交付 diff](../evidence/P6/delivery.diff)，现有任务书保持原路径。配置变更见 [有效配置差异](../evidence/P2/sdkconfig-profiles.diff) 和 [关键配置](../evidence/P2/effective-config.txt)。
