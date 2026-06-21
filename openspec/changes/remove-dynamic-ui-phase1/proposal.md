# Proposal: 消除 Scripts/ 动态 UI 创建 - 第一阶段

## 背景

`Scripts/` 目录下的脚本大量使用 `Control.new()`、`Button.new()`、`Label.new()` 等方式动态创建 UI，而不是将 UI 定义在 `.tscn` 场景文件中。这导致：
- UI 结构不可见于编辑器，难以维护和迭代
- 样式（StyleBoxFlat）散落在代码中，无法统一管理
- 团队协作时 UI 变更容易遗漏

## 目标

将以下三个文件的 UI 从代码创建改为 `.tscn` 场景文件：

| 文件 | 当前问题 | 改动范围 |
|------|----------|----------|
| `ad_system.gd` | `_init()` 中构建整个广告覆盖层 UI（6 个节点） | 新建 `ad_overlay.tscn`，重写 `_init()` |
| `energy_system.gd` | `_create_ui()` 中构建能量显示和按钮（2 个节点） | 新建 `energy_display.tscn`，重写 `_create_ui()` |
| `settings_panel.gd` | `_on_clear_cache()` 动态创建 AcceptDialog | 在现有 `SettingsPanel.tscn` 中添加 AcceptDialog 节点 |

## 范围

- **包含**：创建场景文件、重构脚本加载逻辑、保留所有现有功能和信号
- **不包含**：`_populate_sources()` 的动态创建（运行时数据，保持现状）

## 成功标准

- 三个文件不再有 UI 节点的 `.new()` 调用（除 HTTPRequest、Timer 等非 UI 节点外）
- 所有 UI 样式定义在 `.tscn` 场景文件中
- 功能和信号行为与重构前完全一致
