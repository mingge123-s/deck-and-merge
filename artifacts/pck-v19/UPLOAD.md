# v19 热更新上传说明

## 本地产物

| 文件 | 说明 |
|------|------|
| `deck-and-merge-v19.pck` | 热更新包（Android 预设导出） |
| `version.json` | 远端清单（version=19） |
| `RELEASE.txt` | sha256 / 字节数 |

## 现网目标

- `https://mingge.asia/deck-and-merge/update/deck-and-merge-v19.pck`
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
  artifacts/pck-v19/deck-and-merge-v19.pck \
  ${MINGGE_SSH_USER}@111.228.14.193:/var/www/deck-and-merge/update/

# 2) 校验可达
curl -sI "https://mingge.asia/deck-and-merge/update/deck-and-merge-v19.pck" | head
sha256sum artifacts/pck-v19/deck-and-merge-v19.pck

# 3) 再覆盖清单
sshpass -p "$MINGGE_SSH_PASS" scp -o StrictHostKeyChecking=accept-new \
  artifacts/pck-v19/version.json \
  ${MINGGE_SSH_USER}@111.228.14.193:/var/www/deck-and-merge/update/version.json

curl -sS "https://mingge.asia/deck-and-merge/update/version.json"
```

上传成功后 `version` 应为 **19**。玩家检查更新下载后，须从多任务彻底划掉再开。
