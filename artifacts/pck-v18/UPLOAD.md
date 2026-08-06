# v18 热更新上传说明（COMMAND_DECISION）

本环境无 SSH/FTP/Token，**未能上传**到 mingge.asia。请统帅用本目录产物上线。

## 本地产物

| 文件 | 说明 |
|------|------|
| `deck-and-merge-v18.pck` | 热更新包（Android 预设导出） |
| `version.json` | 远端清单 |
| `RELEASE.txt` | sha256 / 字节数 |

## 现网目标

- `https://mingge.asia/deck-and-merge/update/deck-and-merge-v18.pck`
- `https://mingge.asia/deck-and-merge/update/version.json`

服务器目录（按现网 nginx 约定，若不同请以实际根目录为准）：

```text
/var/www/deck-and-merge/update/deck-and-merge-v18.pck
/var/www/deck-and-merge/update/version.json
```

## 推荐命令

```bash
# 1) 先传 PCK
scp artifacts/pck-v18/deck-and-merge-v18.pck \
  USER@mingge.asia:/var/www/deck-and-merge/update/

# 2) 校验可达与哈希（以 RELEASE.txt 为准）
curl -sI "https://mingge.asia/deck-and-merge/update/deck-and-merge-v18.pck" | head
curl -sS "https://mingge.asia/deck-and-merge/update/deck-and-merge-v18.pck" -o /tmp/v18.pck
sha256sum /tmp/v18.pck
cat artifacts/pck-v18/RELEASE.txt

# 3) 再覆盖清单（避免 version 先更新导致 404）
scp artifacts/pck-v18/version.json \
  USER@mingge.asia:/var/www/deck-and-merge/update/version.json

curl -sS "https://mingge.asia/deck-and-merge/update/version.json"
```

rsync 示例：

```bash
rsync -avP artifacts/pck-v18/deck-and-merge-v18.pck \
  USER@mingge.asia:/var/www/deck-and-merge/update/
rsync -avP artifacts/pck-v18/version.json \
  USER@mingge.asia:/var/www/deck-and-merge/update/version.json
```

上传成功后，装有旧内容的客户端应看到远端 `version=18 > installed`，下载后按主菜单提示完全退出再开即可生效。
