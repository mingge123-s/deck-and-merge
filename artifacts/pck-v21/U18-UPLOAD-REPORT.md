# U18 ops report: overwrite hotupdate package v21

- **STATUS**: DONE
- **UNIT**: U18
- **TASK**: overwrite live `deck-and-merge-v21.pck` with #76 complete package
- **BASE HEAD**: `b9ffed3613941c40f89505dab18ee7dff9530409` (includes merged #76)

## SHA compare

| | sha256 | bytes | notes |
|--|--------|-------|-------|
| BEFORE (wrong / U17-only duration) | `b3825a1d25f66d411f51524233240a5d6254f05a2ea7e929faacb4692c49b033` | `42454012` | 仅五时代时长 |
| AFTER (#76 complete) | `4b38b34610f67ae054de690b083d0baece9ddb8a881c7a5a5751366872d321f2` | `43916324` | 重排点击反馈 + 五时代时长 |

## Local checks

- `sha256.txt` / local pck == `4b38b346…`
- repo `version.json` notes include reshuffle + duration; live notes also append clear-patch hint

## Upload

- Chunked scp (4MiB x 11) → server assemble → sha verify → atomic replace
- Then overwrite `version.json` (site-direct `pck_url`, version remains 21)

## Public verification

```text
curl -sS https://mingge.asia/deck-and-merge/update/version.json
→ version=21
→ notes contains 重排点击必有反馈 + 五时代时长 + 完整包含重排修复

curl GET https://mingge.asia/deck-and-merge/update/deck-and-merge-v21.pck
→ HTTP 200
→ bytes=43916324
→ sha256=4b38b34610f67ae054de690b083d0baece9ddb8a881c7a5a5751366872d321f2
→ NOT b3825a1d…
```
