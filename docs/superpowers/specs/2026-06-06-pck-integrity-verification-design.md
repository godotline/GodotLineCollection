# PCK 远端完整性校验设计

## 概述

在加载 PCK 文件前，通过与远端 GAS 配置中的 MD5 哈希值比对来验证文件完整性。
校验失败的处理方式取决于文件来源：缓存/本地文件损坏则重新下载，刚下载的文件损坏则报错终止。

## 远端配置 Schema 变更

`level_urls` 从 `{save_id: "filename.pck"}` 扩展为支持 Dictionary 格式：

```json
{
  "level_urls": {
    "inv": {
      "filename": "inv.pck",
      "md5": "e5b7f1c3a2d4..."
    },
    "sample": {
      "filename": "sample.pck",
      "md5": "9a0b8c7d6e5f..."
    }
  }
}
```

向后兼容：PCKDownloader 同时支持旧的 String 格式（直接当 filename 处理，无 MD5 校验）。

## 涉及文件

- `Scripts/PCKDownloader.gd` — 新增 `get_md5()` 方法，改造 `get_url()` 兼容两种格式
- `Scripts/LevelManager.gd` — 新增 MD5 计算与校验逻辑，改造 `_start_level()` 和 `_on_download_completed()`

## PCKDownloader 改动

### 新增方法：`get_md5(save_id: String) -> String`

获取远端的 MD5 值。如果 `_filename_map[save_id]` 是 Dictionary 且包含 `"md5"` 键则返回其值，
否则返回空字符串（无校验）。

### 改造方法：`get_url(save_id: String) -> String`

新增 `_resolve_filename()` 内部辅助，处理 `_filename_map` 值为 String（旧格式）或 Dictionary（新格式）两种情况。

## LevelManager 改动

### 新增方法

| 方法 | 功能 |
|---|---|
| `_compute_file_md5(path: String) -> String` | 用 `HashingContext` 分块 64KB 读取文件，返回小写 hex MD5 字符串 |
| `_verify_pck_integrity(pck_path: String, save_id: String) -> bool` | 获取远端 MD5，空则跳过返回 true，否则计算文件 MD5 比对 |

### 改造方法：`_start_level()`

移除 `loaded_pcks` 的短路返回，每次启动关卡都走完整校验流程。
校验逻辑由 `_load_pck()` 内调用 `_verify_pck_integrity()` 统一处理。

```
_start_level()
  ├─ 本地 PCK 存在 → _load_pck()
  │     └─ _verify_pck_integrity()
  │           ├── 通过 → 正常加载
  │           ├── 失败且有远端 URL → 重新下载
  │           └── 失败且无远端 URL → 尝试加载（不阻塞，可能是本地自定义PCK）
  │
  ├─ 缓存 PCK 存在 → _load_pck()
  │     └─ _verify_pck_integrity()
  │           ├── 通过 → 正常加载
  │           └── 失败 → 删缓存 → 重新下载
  │
  └─ 无本地/缓存 → 下载 → _on_download_completed()
          ├── MD5 校验通过 → 加载 → 切换场景
          └── MD5 校验失败 → 删缓存 → 报错（不重试）
```

### 改造方法：`_on_download_completed()`

下载完成后立即 `_compute_file_md5()` 校验：
- 校验通过 → 继续现有流程（`load_resource_pack()` → 切换场景）
- 校验失败 → 删除缓存文件 → 报错 "文件完整性校验失败，请联系管理员"
  （不自动重试，因为同一源重下结果一样）

### 改造方法：`_load_pck()`

`_load_pck()` 内部调用 `_verify_pck_integrity()` 做校验。旧版 `loaded_pcks` 快捷路径删除，
每次调用都完整走 PCK 校验 + 加载流程。`loaded_pcks` 仅用于跟踪记录。

## 数据流图

```
用户点击关卡
      │
      ▼
  _start_level()
      │
      ├── 本地 PCK 存在 → _load_pck()
      │     └── _verify_pck_integrity()
      │           ├── 通过 → ProjectSettings.load_resource_pack()
      │           ├── 失败且有远端 URL → 重新下载
      │           └── 失败且无远端 URL → 仍尝试加载（不阻塞）
      │
      ├── 缓存 PCK 存在 → _load_pck()
      │     └── _verify_pck_integrity()
      │           ├── 通过 → 加载
      │           └── 失败 → 删缓存 → 重新下载
      │
      └── 无本地/缓存 → 下载 → _on_download_completed()
              ├── MD5 校验通过 → 加载 → 切换场景
              └── MD5 校验失败 → 删缓存 → 报错（不重试）
```

## 边界情况

1. **远端无 MD5 配置** — 跳过校验，行为同现状
2. **旧格式 `level_urls`（String 值）** — 自动降级，无校验
3. **文件不存在** — 按现有逻辑报错，不入校验
4. **多次失败** — 如果本地/缓存校验失败触发下载，下载又失败 → 报下载错误，不做级联重试
