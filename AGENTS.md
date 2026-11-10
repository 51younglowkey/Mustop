# AGENTS.md — Mustop

Mustop 的操作须知。用户说明见 `README.md`。

## 1. 项目边界

- 只做一件事：到点让网易云音乐（`com.netease.163music`）暂停。
- 单文件 Swift 应用 `Sources/main.swift`，AppKit + ApplicationServices，没有依赖。
- 菜单栏收纳的问题（图标被藏、位置不对）归 YoungBar（`../YoungBar`），不要在这里绕。

## 2. 构建与运行

- `make build`：编译 → `build/Mustop.app` → 签名 → 安装到 `~/Applications/Mustop.app`。
- 必须用「YoungBar Local Signing」签名。
  - 退回 ad-hoc 会让辅助功能授权在每次重编译后失效。
  - 不要绕过 `Scripts/build.sh` 直接改 `~/Applications` 里的二进制。
- 网易云正在播放时，`--pause-now` 自检会真的暂停用户的音乐。
  - 跑之前先看网易云 `Controls` 菜单的状态。
  - 跑完如果是自己暂停的，要恢复播放。

## 3. 发布

- 公开仓库：<https://github.com/51younglowkey/Mustop>（MIT）。
- 发版：改 `Info.plist` 的版本号 → `make release` 生成 `dist/Mustop-x.y.zip`（通用二进制）→ `gh release create vX.Y dist/Mustop-x.y.zip`。
- README 中英两版：`README.md`（中文，默认）和 `README.en.md`，插图在 `docs/assets/`，改功能时两份一起改。

## 4. 权限

- 辅助功能（macOS 27：设备控制与数据访问）。
- 授权由用户本人在系统设置里完成，不要绕过。
- 授权状态可以只读查询：

  ```sh
  sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
    "select client,auth_value from access where service='kTCCServiceAccessibility' and client='studio.wuyiyang.mustop'"
  ```

  `auth_value=2` 表示已允许。

## 5. 历史

- 原型叫「定时暂停」（`com.51young.sleeptimer`），2026-11-09 做出，2026-11-10 改名为 Mustop 并独立成项目。
- 当时的完整对话导出在 `docs/origin-conversation.md`（只在本地，已 gitignore，不进公开仓库）。
- 关键结论：
  - 网易云 Mac 版没有 AppleScript。
  - MediaRemote 在 macOS 27 上不生效。
  - 菜单项方案可靠。
  - 首次授权要手动「+」添加。
