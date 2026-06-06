# LevelManager 预览图布局重设计

## 概览

调整关卡选择界面的预览图区域布局，将左右切换箭头从与图片并列改为悬浮在图片左右边缘，使预览图宽度与下方 Info 区域对齐，实现轮播图风格的视觉效果。

## 当前布局

```
PreviewRow (HBoxContainer)
  ├── LeftArrow ("<" 按钮, 50×50)
  ├── PreviewClip (Control, stretch_ratio=5, 图片容器)
  └── RightArrow (">" 按钮, 50×50)
```

箭头与预览图水平并列，图片宽度被箭头挤压。

## 目标布局

```
PreviewRow (Control)  ← 普通容器，不再自动排列子节点
  ├── PreviewClip (PRESET_FULL_RECT, 填满整个 PreviewRow)
  ├── LeftArrow (锚定左边缘、垂直居中，悬浮在图片上方)
  └── RightArrow (锚定右边缘、垂直居中，悬浮在图片上方)
```

### 行为

- `PreviewRow` 的宽度保持与以下元素一致（同属于 `Margin/VBox`，自动对齐）:
  - 顶栏 `Header`
  - 底部 `Info`（包含标题、作者、按钮）
  - 底栏 `Bottom`
- `PreviewClip` 填满 `PreviewRow` 全宽 — 图片展开至与下方"详细信息"按钮的容器区域同宽。
- `LeftArrow` 锚定在 `PreviewRow` 左边缘、垂直居中，z-index 高于 `PreviewClip`
- `RightArrow` 锚定在 `PreviewRow` 右边缘、垂直居中，z-index 高于 `PreviewClip`
- 箭头按钮加半透明背景色，确保在任何图片上都清晰可见
- 箭头在关卡数 <= 1 时隐藏（已有 `left_arrow.visible` / `right_arrow.visible` 逻辑）
- `CounterLabel`（"1 / 5"）保持在 `Preview` VBox 中原位

## 要修改的文件

| 文件 | 改动 |
|------|------|
| `Scenes/LevelManager.tscn` | `PreviewRow` 由 `HBoxContainer` → `Control`；箭头锚点改为相对定位；添加箭头背景样式 |
| `Scripts/LevelManager.gd` | 节点路径不变，代码无需修改 |

## 不修改的部分

- `@onready` 节点路径不变（`preview_clip`、`left_arrow`、`right_arrow` 仍为 `PreviewRow` 的子节点）
- `_animate_switch()` 淡入淡出逻辑不变
- `_create_panels()` 中 `_slide_wrap` 和 `_panel` 的创建逻辑不变
- `_position_panels()` 中 `_panel.size = preview_clip.size` 不变
- `_update_display()` 中箭头显隐逻辑不变
