#!/usr/bin/env bash
# 导出应用内热更新用 .pck，并生成 version.json。
# 用法:
#   tools/export_patch_pck.sh --version 18 [--notes "..."] [--preset Android] [--out-dir artifacts/pck-v18]
#   tools/export_patch_pck.sh --help
#   tools/export_patch_pck.sh --dry-run --version 18
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION=""
NOTES=""
PRESET="Android"
OUT_DIR=""
PCK_BASENAME=""
BASE_URL="https://mingge.asia/deck-and-merge/update"
GODOT_BIN="${GODOT_BIN:-godot}"
DRY_RUN=0
SKIP_EXPORT=0

usage() {
	cat <<'EOF'
导出 Deck & Merge 热更新 PCK + version.json

必需:
  --version N          内容版本号（写入 version.json；玩家端 remote>installed 才下载）

可选:
  --notes TEXT         更新说明（默认按版本生成简短 notes）
  --preset NAME        Godot 导出预设名（默认 Android，匹配现网手机包纹理）
  --out-dir DIR        输出目录（默认 artifacts/pck-vN）
  --pck-name FILE      PCK 文件名（默认 deck-and-merge-vN.pck）
  --base-url URL       pck_url 前缀（默认 https://mingge.asia/deck-and-merge/update）
  --godot PATH         Godot 可执行文件（默认 $GODOT_BIN 或 godot）
  --dry-run            只打印将执行的步骤与将生成的 version.json，不调用 Godot
  --skip-export        假定 PCK 已存在于 out-dir，只（重）写 version.json
  -h, --help           显示帮助

示例:
  tools/export_patch_pck.sh --version 18 \
    --notes "v18：过关文案、优先打塔、排行榜、摇一摇/重排、清空顶栏、身后还击等"

注意:
  - BASE_VERSION（scripts/updater.gd）是 APK 内置基线，热更发布不要随意抬高。
  - 改 autoload / 权限 / 引擎 / 图标 必须发新 APK 并同步 bump BASE_VERSION。
  - 上传需另备 SSH/FTP/Token；本脚本只产出可发布文件。
EOF
}

default_notes() {
	local v="$1"
	printf 'v%s：内容热更新（详见发布说明）。' "$v"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--version) VERSION="${2:-}"; shift 2 ;;
		--notes) NOTES="${2:-}"; shift 2 ;;
		--preset) PRESET="${2:-}"; shift 2 ;;
		--out-dir) OUT_DIR="${2:-}"; shift 2 ;;
		--pck-name) PCK_BASENAME="${2:-}"; shift 2 ;;
		--base-url) BASE_URL="${2:-}"; shift 2 ;;
		--godot) GODOT_BIN="${2:-}"; shift 2 ;;
		--dry-run) DRY_RUN=1; shift ;;
		--skip-export) SKIP_EXPORT=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*)
			echo "未知参数: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

if [[ -z "$VERSION" ]]; then
	echo "错误: 必须提供 --version" >&2
	usage >&2
	exit 2
fi
if ! [[ "$VERSION" =~ ^[0-9]+$ ]]; then
	echo "错误: --version 必须是正整数" >&2
	exit 2
fi

OUT_DIR="${OUT_DIR:-artifacts/pck-v${VERSION}}"
PCK_BASENAME="${PCK_BASENAME:-deck-and-merge-v${VERSION}.pck}"
NOTES="${NOTES:-$(default_notes "$VERSION")}"
PCK_PATH="${OUT_DIR}/${PCK_BASENAME}"
MANIFEST_PATH="${OUT_DIR}/version.json"
PCK_URL="${BASE_URL%/}/${PCK_BASENAME}"

# 转义 JSON 字符串（去掉参数自带的尾随换行）
json_escape() {
	python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n"), ensure_ascii=False)[1:-1])' <<<"$1"
}

NOTES_ESCAPED="$(json_escape "$NOTES")"

write_manifest() {
	mkdir -p "$OUT_DIR"
	cat >"$MANIFEST_PATH" <<EOF
{
  "version": ${VERSION},
  "pck_url": "${PCK_URL}",
  "notes": "${NOTES_ESCAPED}"
}
EOF
}

echo "== in-app PCK patch export =="
echo "version:  $VERSION"
echo "preset:   $PRESET"
echo "out_dir:  $OUT_DIR"
echo "pck:      $PCK_PATH"
echo "pck_url:  $PCK_URL"
echo "godot:    $GODOT_BIN"
echo "dry_run:  $DRY_RUN"
echo "notes:    $NOTES"

if [[ "$DRY_RUN" -eq 1 ]]; then
	mkdir -p "$OUT_DIR"
	write_manifest
	echo
	echo "[dry-run] 将执行:"
	echo "  mkdir -p $(dirname "$PCK_PATH") build"
	echo "  $GODOT_BIN --headless --path \"$ROOT\" --export-pack \"$PRESET\" \"$PCK_PATH\""
	echo "  生成 $MANIFEST_PATH"
	echo
	echo "[dry-run] version.json 预览:"
	cat "$MANIFEST_PATH"
	echo
	echo "[dry-run] 上传示例（需凭据）:"
	echo "  scp \"$PCK_PATH\" \"$MANIFEST_PATH\" USER@mingge.asia:/var/www/deck-and-merge/update/"
	echo "  # 或先传 pck，确认可达后再覆盖 version.json"
	exit 0
fi

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
	echo "错误: 找不到 Godot 可执行文件: $GODOT_BIN" >&2
	echo "请安装 Godot 4.7.x 或设置 GODOT_BIN=/path/to/godot" >&2
	exit 1
fi

mkdir -p "$OUT_DIR" build

if [[ "$SKIP_EXPORT" -eq 0 ]]; then
	echo "== Godot --export-pack =="
	# 相对 project.godot 的路径；脚本已 cd 到 ROOT
	"$GODOT_BIN" --headless --path "$ROOT" --export-pack "$PRESET" "$PCK_PATH"
else
	echo "== skip-export：使用已有 PCK =="
fi

if [[ ! -f "$PCK_PATH" ]]; then
	echo "错误: 未生成 PCK: $PCK_PATH" >&2
	exit 1
fi

write_manifest

SHA256="$(sha256sum "$PCK_PATH" | awk '{print $1}')"
SIZE="$(wc -c <"$PCK_PATH" | tr -d ' ')"
{
	echo "version=${VERSION}"
	echo "pck=${PCK_BASENAME}"
	echo "pck_url=${PCK_URL}"
	echo "sha256=${SHA256}"
	echo "bytes=${SIZE}"
	echo "preset=${PRESET}"
	echo "generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"${OUT_DIR}/RELEASE.txt"

echo
echo "== 完成 =="
echo "manifest: $MANIFEST_PATH"
cat "$MANIFEST_PATH"
echo
echo "sha256:   $SHA256"
echo "bytes:    $SIZE"
echo "meta:     ${OUT_DIR}/RELEASE.txt"
echo
echo "上传目标（现网前缀）:"
echo "  ${BASE_URL%/}/${PCK_BASENAME}"
echo "  ${BASE_URL%/}/version.json"
echo "建议顺序: 先上传 PCK 并 curl 校验，再覆盖 version.json。"
