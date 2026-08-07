# v21 热更新上传说明

## 本地产物

| 文件 | 说明 |
|------|------|
| `deck-and-merge-v21.pck` | 热更新包（Android 预设导出） |
| `version.json` | 远端清单（version=21） |
| `RELEASE.txt` | sha256 / 字节数 |
| `sha256.txt` | sha256sum 一行 |

## 现网目标

- `https://mingge.asia/deck-and-merge/update/deck-and-merge-v21.pck`
- `https://mingge.asia/deck-and-merge/update/version.json`

**`pck_url` 必须是本站直链**（禁止 GitHub Release，手机 302 失败）。

服务器目录：

```text
/var/www/deck-and-merge/update/
```

主机：`111.228.14.193`（mingge.asia）

## 推荐命令

```bash
# 凭据：~/.cursor/mingge-deploy.env + ssh pass 文件
set -a
source ~/.cursor/mingge-deploy.env
set +a
export SSHPASS="${SSHPASS:-$(cat "${SSHPASS_FILE:-$HOME/.cursor/mingge-ssh.pass}")}"
HOST="${MINGGE_SSH_HOST:-111.228.14.193}"
PATH_REMOTE="${MINGGE_SSH_PATH:-/var/www/deck-and-merge/update}"

# 1) 先传 PCK（可用分块 scp）
sshpass -e scp -o StrictHostKeyChecking=accept-new \
  artifacts/pck-v21/deck-and-merge-v21.pck \
  "${MINGGE_SSH_USER}@${HOST}:${PATH_REMOTE}/"

# 2) 校验可达 + sha256
curl -sI "https://mingge.asia/deck-and-merge/update/deck-and-merge-v21.pck" | head
sha256sum artifacts/pck-v21/deck-and-merge-v21.pck
# 期望: b3825a1d25f66d411f51524233240a5d6254f05a2ea7e929faacb4692c49b033

# 3) 再覆盖清单
sshpass -e scp -o StrictHostKeyChecking=accept-new \
  artifacts/pck-v21/version.json \
  "${MINGGE_SSH_USER}@${HOST}:${PATH_REMOTE}/version.json"

curl -sS "https://mingge.asia/deck-and-merge/update/version.json"
```

上传成功后 `version` 应为 **21**，`pck_url` 为本站直链。玩家检查更新下载后，须从多任务彻底划掉再开。

## 基线

- 源 commit：`d6d0a83`（#74 五阶段时代时长加长）
- 未含 U15 重排新修复（导出时 main 尚未合入）
- 未改 `BASE_VERSION`（APK 基线仍为 1）
