# v21 热更新上传说明

## 本地产物

| 文件 | 说明 |
|------|------|
| `deck-and-merge-v21.pck` | 热更新包（Android 预设；含 #74 时长 + #76 重排） |
| `version.json` | 远端清单（version=21） |
| `RELEASE.txt` | sha256 / 字节数 |
| `sha256.txt` | sha256sum 一行 |

## 现网目标

- `https://mingge.asia/deck-and-merge/update/deck-and-merge-v21.pck`
- `https://mingge.asia/deck-and-merge/update/version.json`

**`pck_url` 必须是本站直链**（禁止 GitHub Release，手机 302 失败）。

服务器目录：`/var/www/deck-and-merge/update/`  
主机：`111.228.14.193`（mingge.asia）

## 校验期望

- sha256: `4b38b34610f67ae054de690b083d0baece9ddb8a881c7a5a5751366872d321f2`
- bytes: `43916324`
- version: **21**

## 基线

- 源：`origin/main` `#76`（含 `#74` ERA_DURATION_SEC=[300,480,900,1200,1800] + 重排修复）
- 未改 `BASE_VERSION`（APK 基线仍为 1）
