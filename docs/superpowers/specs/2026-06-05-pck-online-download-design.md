# PCK 关卡在线下载功能 — 设计文档

**日期**: 2026-06-05
**状态**: 已批准

## 概述

为 GodotLineCollection 添加 PCK 关卡在线下载功能。用户点击关卡时，若本地无缓存则自动从远程 URL 下载 PCK 文件，下载完成后加载关卡。

远程下载 URL 通过 GAS `ConfigService` 获取，以 `{save_id: url}` 字典形式存储在远程配置的 `level_urls` 字段中。

## 架构

```
GAS ConfigService (远程配置)
       │
       ▼
  PCKDownloader.gd (新建, extends RefCounted)
  ├── fetch_level_urls()    →  从GAS获取 {save_id: url}
  ├── download(save_id, url)→  HTTP下载 → user://pck_cache/<save_id>.pck
  ├── is_cached(save_id)    →  检查本地缓存是否存在
  ├── get_cached_path()     →  返回缓存文件全局路径
  └── download_progress / download_completed / download_failed 信号
       │
       ▼
Scripts/LevelManager.gd (改动)
  └── _start_level() → 先检查缓存, 未缓存则触发下载
```

## 核心流程

```
用户点击关卡
  → LevelManager._start_level()
    → PCKDownloader.is_cached(save_id)?
      YES → 直接加载PCK → 切换场景
      NO  → PCKDownloader.download(save_id, url)
              → info_label: "下载中... 45%"
              → 成功 → ProjectSettings.load_resource_pack(cached_path)
                     → get_tree().change_scene_to_file(scene_path)
              → 失败 → info_label: "下载失败，点击重试"
```

## 文件改动

### 1. 新建 `Scripts/PCKDownloader.gd`

`class_name PCKDownloader extends RefCounted`，静态单例模式。

**公开方法：**

- `fetch_level_urls() -> Dictionary`
  - 调用 `ConfigService.get_config()` 获取远程配置
  - 从 `config_resp.data.level_urls` 提取 `{save_id: download_url}` 字典
  - 缓存到 `_url_map` 成员变量
  - 返回 `_url_map`（失败时返回空字典）

- `get_url(save_id: String) -> String`
  - 从 `_url_map` 查找指定 save_id 的下载 URL
  - 未找到返回空字符串

- `is_cached(save_id: String) -> bool`
  - 检查 `user://pck_cache/<save_id>.pck` 是否存在

- `get_cached_path(save_id: String) -> String`
  - 返回缓存文件的绝对路径（未缓存也返回目标路径）

- `download(save_id: String, url: String) -> void`
  - 创建 `HTTPRequest` 节点发起 GET 请求
  - 下载过程中发射 `download_progress(save_id, percent)` 信号
  - 成功：写入 `user://pck_cache/`，发射 `download_completed(save_id, path)`
  - 失败：发射 `download_failed(save_id, error_message)`

- `cancel_download() -> void`
  - 取消正在进行的下载

**信号：**
- `download_progress(save_id: String, percent: float)`
- `download_completed(save_id: String, cached_path: String)`
- `download_failed(save_id: String, error: String)`

**内部成员：**
- `_url_map: Dictionary` — 从 GAS 获取的 `{save_id: url}`
- `_http: HTTPRequest` — 当前下载请求节点
- `_downloading_save_id: String` — 正在下载的关卡 ID
- `_download_body: PackedByteArray` — 累积的下载数据

### 2. 改动 `Scripts/LevelManager.gd`

在 `_ready()` 末尾添加：
```gdscript
PCKDownloader.fetch_level_urls()
```

修改 `_start_level()`：
- 如果 `data.pck_path` 为空但 `save_id` 在 PCKDownloader 的 URL 映射中有对应 URL，则触发下载流程
- 下载期间显示进度到 `info_label`
- 连接 `PCKDownloader.download_completed` → 加载 PCK 并切换场景
- 连接 `PCKDownloader.download_failed` → 显示错误信息，用户可重试

### 3. 不改动 `Scripts/MenuLevelData.gd`

当前 `MenuLevelData` 的 `pck_path` 字段保持本地路径用途。远程 URL 完全通过 GAS 配置下发，不需要在每个关卡数据中存储。

## 数据流

```
GAS ConfigService.get_config()
  → ConfigResp.data = {
      "level_urls": {
        "sample_001": "https://cdn.example.com/levels/sample.pck",
        "level_002": "https://cdn.example.com/levels/level2.pck"
      }
    }
  → PCKDownloader._url_map = level_urls

PCKDownloader.download("sample_001", "https://cdn.example.com/levels/sample.pck")
  → HTTPRequest GET url
  → 每帧检查 HTTPRequest.get_body_size() / HTTPRequest.get_downloaded_bytes()
  → 写入 user://pck_cache/sample_001.pck
  → ProjectSettings.load_resource_pack(cached_path)
  → get_tree().change_scene_to_file(scene_path)
```

## 缓存目录

- 路径：`user://pck_cache/`
- 命名：`<save_id>.pck`
- 首次使用时自动创建目录（`DirAccess.make_dir_recursive_absolute`）

## UI 反馈

- 下载中：`info_label.text = "下载中... %d%%" % percent`
- 下载成功：`info_label.text = ""`（静默切换场景）
- 下载失败：`info_label.text = "下载失败: %s，点击重试" % error`
- 用户再次点击同一关卡即可重试

## 错误处理

- 网络不可用：`download_failed` 信号携带 "网络连接失败"
- HTTP 非 200：`download_failed` 信号携带 HTTP 状态码
- 文件写入失败：`download_failed` 信号携带写入错误
- GAS 配置获取失败：静默降级，`_url_map` 为空，不影响本地关卡加载
- 下载中退出：HTTPRequest 随场景销毁自动取消

## 测试要点

1. 本地关卡（无远程 URL）照常加载，不受影响
2. 远程关卡首次点击 → 下载 → 加载成功
3. 远程关卡二次点击 → 命中缓存 → 直接加载
4. 网络不可用时 → 显示错误，重试后恢复
5. GAS 配置获取失败 → 本地关卡正常工作
