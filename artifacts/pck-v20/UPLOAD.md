# v20 热更新上传说明

## 本地产物

| 文件 | 说明 |
|------|------|
| `deck-and-merge-v20.pck` | 热更新包（Android 预设导出） |
| `version.json` | 远端清单（version=20） |
| `RELEASE.txt` | sha256 / 字节数 |

## 现网目标

- `https://mingge.asia/deck-and-merge/update/deck-and-merge-v20.pck`
- `https://mingge.asia/deck-and-merge/update/version.json`

服务器目录：

```text
/var/www/deck-and-merge/update/
```

主机：`111.228.14.193`（mingge.asia）

## 推荐命令

```bash
# 1) 先传 PCK
sshpass -p "$MINGGE_SSH_PASS" scp -o StrictHostKeyChecking=accept-new \
  artifacts/pck-v20/deck-and-merge-v20.pck \
  ${MINGGE_SSH_USER}@111.228.14.193:/var/www/deck-and-merge/update/

# 2) 校验可达
curl -sI "https://mingge.asia/deck-and-merge/update/deck-and-merge-v20.pck" | head
sha256sum artifacts/pck-v20/deck-and-merge-v20.pck
# 期望: f55965971e17e5e23583555e2b05883f38e4969d69bc29fcb5fe81c8987a0690

# 3) 再覆盖清单
sshpass -p "$MINGGE_SSH_PASS" scp -o StrictHostKeyChecking=accept-new \
  artifacts/pck-v20/version.json \
  ${MINGGE_SSH_USER}@111.228.14.193:/var/www/deck-and-merge/update/version.json

curl -sS "https://mingge.asia/deck-and-merge/update/version.json"
```

上传成功后 `version` 应为 **20**。玩家检查更新下载后，须从多任务彻底划掉再开。

## 基线

- 源 commit：`af7bdb1`（含 #70 REMOVE-CLEAR + #72 TIME-ERA）
- 未改 `BASE_VERSION`（APK 基线仍为 1）
