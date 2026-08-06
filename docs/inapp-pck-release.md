# 应用内 PCK 热更新发布指南

玩家端通过 `scripts/updater.gd` 拉取 `https://mingge.asia/deck-and-merge/update/version.json`：当远端 `version` **大于** 本地 `installed_version` 时下载 `pck_url` 指向的 `.pck`，下次启动由 `ProjectSettings.load_resource_pack` 覆盖资源。

## BASE_VERSION 与 APK 基线

| 概念 | 位置 | 含义 |
|------|------|------|
| `BASE_VERSION` | `scripts/updater.gd` | **打进 APK 的内容基线**。仅在发布**新整包 APK** 时递增。 |
| 远端 `version` | 服务器 `version.json` | 热更内容版本。玩家下载条件：`remote > installed`。 |
| `installed_version` | 运行时 | 先取 `BASE_VERSION`；若本地补丁 `pck_version > BASE_VERSION` 且加载成功，则升为补丁版本。 |

**默认热更不要把 `BASE_VERSION` 抬到与远端相同。** 例如 APK 基线仍是 1、远端发 v18 时，旧客户端 `installed=1`、远端 `18`，可以正常下载；若误把 `BASE_VERSION` 改成 18 却不发新 APK，未装补丁的旧包会以为自己已是 18。

补丁比当前 APK 基线更旧时（用户刚装了更新的整包），启动会清掉旧 `user://patch/game.pck`，避免回退。

## 可热更 / 必须新 APK

**热更可覆盖（进 PCK 即可）：**

- `scenes/`、`scripts/`（非 autoload 或虽在包内、但主场景路径加载的脚本）
- `assets/`、`data/*.json`、大部分玩法与 UI

**必须发新 APK，并同步 bump `BASE_VERSION`：**

- autoload：`Updater` / `SaveManager` / `AudioManager`（它们在补丁 `load_resource_pack` **之前**已加载）
- Android 权限、传感器开关（如加速度计）、包名、图标、启动图
- Godot 引擎版本 / 导出模板变更
- `project.godot` 中影响原生层的配置

引导场景 `scenes/boot.tscn` + `scripts/boot.gd` 负责在补丁挂载后再 `change_scene_to_file` 主场景，使补丁内场景/脚本真正生效。

## 发布步骤（可重复）

1. 确保本机 Godot **4.7.x**（与仓库一致，现网日志为 4.7.1），且已安装对应 export templates。
2. 在仓库根目录执行：

```bash
tools/export_patch_pck.sh --version 18 \
  --notes "v18：过关文案、优先打塔、排行榜、摇一摇/重排、清空顶栏、身后还击等"
```

- 默认预设：`Android`（匹配手机包纹理压缩）
- 产出目录：`artifacts/pck-v18/`
  - `deck-and-merge-v18.pck`
  - `version.json`
  - `RELEASE.txt`（含 sha256）

3. 预览不导出：

```bash
tools/export_patch_pck.sh --dry-run --version 18 --notes "..."
```

4. **上传到现网**（需 SSH/FTP/Token；本仓库脚本不写死凭据）：

目标路径（与现网前缀一致）：

- `https://mingge.asia/deck-and-merge/update/deck-and-merge-vN.pck`
- `https://mingge.asia/deck-and-merge/update/version.json`

建议服务器目录（nginx 静态根下，按现网约定）：

```text
/var/www/deck-and-merge/update/deck-and-merge-vN.pck
/var/www/deck-and-merge/update/version.json
```

示例：

```bash
# 先传 PCK，再覆盖清单，避免玩家拉到新 version 却 404
scp artifacts/pck-v18/deck-and-merge-v18.pck \
  USER@mingge.asia:/var/www/deck-and-merge/update/
curl -sI "https://mingge.asia/deck-and-merge/update/deck-and-merge-v18.pck" | head
scp artifacts/pck-v18/version.json \
  USER@mingge.asia:/var/www/deck-and-merge/update/version.json
curl -sS "https://mingge.asia/deck-and-merge/update/version.json"
```

5. 校验：`version.json` 的 `version` / `pck_url` / `notes`；PCK HTTP 200；本地 `sha256sum` 与 `RELEASE.txt` 一致。

## 客户端行为与 UX

- 启动后主菜单后台 `check_for_update(false)`：**无感**，检查中不刷状态文案。
- 主菜单「检查更新」：手动检查，显示进度/结果。
- 下载完成后：状态栏醒目提示 + **确认弹层**「重启游戏后生效」（不强制杀进程；由玩家自行退出再开）。

## version.json 字段

```json
{
  "version": 18,
  "pck_url": "https://mingge.asia/deck-and-merge/update/deck-and-merge-v18.pck",
  "notes": "简短说明"
}
```

`pck_url` 必须保持此前缀：`https://mingge.asia/deck-and-merge/update/<filename>`。
