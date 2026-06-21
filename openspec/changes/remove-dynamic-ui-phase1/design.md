# Design: 消除 Scripts/ 动态 UI 创建 - 第一阶段

## 1. ad_system.gd → ad_overlay.tscn

### 当前结构（代码创建）
```
Control (全屏, z_index=100, MOUSE_FILTER_STOP)
├── ColorRect (黑色背景)
├── VLCMediaPlayer (视频播放)
├── Button "跳过" (右上角, StyleBoxFlat)
└── Timer (5秒倒计时)
```

### 目标结构（.tscn）
新建 `Scenes/ad_overlay.tscn`：
- 根节点：`Control` (anchors_preset=15, z_index=100, mouse_filter=STOP)
- `ColorRect` (全屏黑色)
- `VLCMediaPlayer` (全屏)
- `Button` "跳过" (右上角, StyleBoxFlat 样式, 初始 hidden)
- `Timer` (wait_time=5, one_shot=true)

### 脚本改动
- `_init()` 改为 `load("res://Scenes/ad_overlay.tscn").instantiate()`
- 通过 `get_node()` 或导出变量引用子节点
- HTTPRequest 保持代码创建（非 UI 节点）
- 信号连接和逻辑保持不变

## 2. energy_system.gd → energy_display.tscn

### 当前结构（代码创建）
```
HBoxContainer (由外部传入)
├── Label "💎 10" (金色, font_size=15)
└── Button "🎬 看广告" (红色圆角, 脉冲动画)
```

### 目标结构（.tscn）
新建 `Scenes/energy_display.tscn`：
- 根节点：`HBoxContainer` (theme_override_constants/separation=8)
  - `Label` (text="💎 10", font_color=金色, font_size=15)
  - `Button` "🎬 看广告" (custom_minimum_size=100x0, StyleBoxFlat 红色圆角)

### 脚本改动
- `_create_ui()` 改为 `load("res://Scenes/energy_display.tscn").instantiate()`
- 从实例化的场景中获取 Label 和 Button 引用
- 脉冲动画逻辑保持不变
- header.add_child() 改为添加实例化后的场景根节点

## 3. settings_panel.gd → SettingsPanel.tscn 扩展

### 当前动态创建
```gdscript
# _on_clear_cache() 中
var confirm := AcceptDialog.new()
confirm.title = "清除缓存"
confirm.dialog_text = "确定要清除所有缓存文件吗？"
confirm.size = Vector2i(300, 120)
add_child(confirm)
confirm.popup_centered()
confirm.confirmed.connect(_do_clear_cache)
```

### 目标结构
在 `Scenes/SettingsPanel.tscn` 中添加：
```
SettingsPanel (Control)
└── ConfirmDialog (AcceptDialog, unique_id)
    - title = "清除缓存"
    - dialog_text = "确定要清除所有缓存文件吗？"
    - size = Vector2i(300, 120)
```

### 脚本改动
- 添加 `@onready var _confirm_dialog: AcceptDialog = $ConfirmDialog`
- `_on_clear_cache()` 改为 `_confirm_dialog.popup_centered()`
- 信号连接移到 `_ready()` 中
