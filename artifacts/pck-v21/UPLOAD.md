# v21 热更新上传说明

## 本地产物

| 文件 | 说明 |
|------|------|
| `deck-and-merge-v21.pck` | 热更新包（Android 预设导出） |
| `version.json` | 远端清单（version=21） |
| `RELEASE.txt` | sha256 / 字节数 |

## 现网目标

- `https://mingge.asia/deck-and-merge/update/deck-and-merge-v21.pck`
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
  artifacts/pck-v21/deck-and-merge-v21.pck \
  ${MINGGE_SSH_USER}@111.228.14.193:/var/www/deck-and-merge/update/

# 2) 校验可达
curl -sI "https://mingge.asia/deck-and-merge/update/deck-and-merge-v21.pck" | head
sha256sum artifacts/pck-v21/deck-and-merge-v21.pck
# 期望: 9d80de235307248f7a3d371ca8f324d9e4b0852956213d46caf7186f644bd96b

# 3) 再覆盖清单
sshpass -p "$MINGGE_SSH_PASS" scp -o StrictHostKeyChecking=accept-new \
  artifacts/pck-v21/version.json \
  ${MINGGE_SSH_USER}@111.228.14.193:/var/www/deck-and-merge/update/version.json

curl -sS "https://mingge.asia/deck-and-merge/update/version.json"
```

上传成功后 `version` 应为 **21**。玩家检查更新下载后，须从多任务彻底划掉再开。
**pck_url 必须是本站直链**（禁止 GitHub Release，会 302）。

## 基线

- 源 commit：`f1d86de`（U15 重排点击反馈修复）
- 未改 `BASE_VERSION`（APK 基线仍为 1）
- 未改战斗经济数值（RESHUFFLE_COST 仍为 200）
