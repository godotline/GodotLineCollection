# Tasks: 消除 Scripts/ 动态 UI 创建 - 第一阶段

## Task 1: 创建 ad_overlay.tscn

- [x] 新建 `Scenes/ad_overlay.tscn`
- [x] 根节点 Control: anchors_preset=15, z_index=100, mouse_filter=STOP
- [x] 子节点 ColorRect: 全屏黑色背景
- [x] 子节点 VLCMediaPlayer: 全屏 (插件类型，由代码创建并 add_child)
- [x] 子节点 Button "跳过": 右上角定位, StyleBoxFlat 样式 (dark rounded), 初始 visible=false
- [x] 子节点 Timer: wait_time=5.0, one_shot=true
- [x] 将样式 (StyleBoxFlat) 定义为 sub_resource

## Task 2: 重构 ad_system.gd

- [x] 移除 `_init()` 中所有 UI 创建代码
- [x] `_init()` 改为加载 `ad_overlay.tscn` 并实例化
- [x] 通过节点路径引用子节点 (_skip_btn, _skip_timer)
- [x] HTTPRequest 和 VLCMediaPlayer 保持代码创建 (非 UI / 插件类型)
- [x] 验证所有信号连接和逻辑不变

## Task 3: 将能量显示嵌入 LevelManager.tscn

- [x] 在 LevelManager.tscn Header 中添加 EnergyLabel 和 WatchAdBtn 节点
- [x] 添加 StyleBoxFlat_AdBtn 和 StyleBoxFlat_AdBtnHover 样式资源
- [x] 删除不再需要的 energy_display.tscn

## Task 4: 重构 energy_system.gd

- [x] 移除 `_create_ui()` 和所有 UI 创建代码
- [x] `_init()` 改为接收已有的 Label 和 Button 引用
- [x] 脉冲动画逻辑保持不变
- [x] LevelManager.gd 传入 header_box.get_node("EnergyLabel") 和 header_box.get_node("WatchAdBtn")

## Task 5: 修改 SettingsPanel.tscn

- [x] 在 SettingsPanel.tscn 中添加 AcceptDialog 节点
- [x] 设置 title="清除缓存", dialog_text="确定要清除所有缓存文件吗？", size=Vector2i(300,120)
- [x] 添加 @onready 引用

## Task 6: 重构 settings_panel.gd

- [x] 添加 `@onready var _confirm_dialog: AcceptDialog = $ConfirmDialog`
- [x] `_on_clear_cache()` 改为 `_confirm_dialog.popup_centered()`
- [x] 在 `_ready()` 中连接 `_confirm_dialog.confirmed` 信号到 `_do_clear_cache`

## 验证

- [ ] 在 Godot 编辑器中打开每个场景，确认节点结构正确
- [ ] 运行项目，测试广告播放流程
- [ ] 测试能量显示和看广告按钮
- [ ] 测试设置面板缓存清除确认对话框
