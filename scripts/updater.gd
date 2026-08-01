extends Node
## 应用内 PCK 热更新（无感）。
## 原理：启动时先把本地已下载的补丁包 load_resource_pack 覆盖进虚拟文件系统，
## 随后主场景与所有 class_name 脚本、场景、图片、data/*.json 都会从补丁包读取。
## 后台向服务器查 version.json，发现更高版本就下载新 .pck，下次启动自动生效。
## 限制：autoload 脚本本身（save_manager/audio_manager/updater）在补丁应用前已加载，
##       如需改动它们或权限/引擎/图标，仍需发布新 APK 并同步 bump BASE_VERSION。

signal status_changed(text: String)
signal update_ready(version: int, notes: String)

## 更新清单地址（服务器上的 version.json）。换服务器只改这一行。
const MANIFEST_URL := "https://mingge.asia/deck-and-merge/update/version.json"
## 打进 APK 的基线内容版本。每次发布新 APK 基线时 +1。
const BASE_VERSION := 1

const PATCH_DIR := "user://patch"
const PCK_PATH := "user://patch/game.pck"
const TMP_PATH := "user://patch/game.pck.download"
const STATE_PATH := "user://patch/state.json"
const HTTP_TIMEOUT := 20.0

var installed_version := BASE_VERSION
var _http: HTTPRequest
var _phase := "idle"  # idle / checking / downloading
var _pending_version := 0
var _pending_notes := ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(PATCH_DIR)
	_apply_local_patch()
	_http = HTTPRequest.new()
	_http.timeout = HTTP_TIMEOUT
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func _apply_local_patch() -> void:
	var state := _read_state()
	var pv := int(state.get("pck_version", 0))
	if pv > BASE_VERSION and FileAccess.file_exists(PCK_PATH):
		if ProjectSettings.load_resource_pack(PCK_PATH, true):
			installed_version = pv
		else:
			push_warning("补丁包加载失败，回退到内置版本")
	else:
		# 补丁包比当前 APK 基线还旧（说明用户刚装了更新的整包），清掉避免回退
		if pv > 0 and pv <= BASE_VERSION and FileAccess.file_exists(PCK_PATH):
			DirAccess.remove_absolute(PCK_PATH)
			_write_state({})

func check_for_update(manual := false) -> void:
	if _phase != "idle":
		return
	_phase = "checking"
	status_changed.emit("正在检查更新…" if manual else "")
	var err := _http.request(MANIFEST_URL)
	if err != OK:
		_phase = "idle"
		status_changed.emit("检查更新失败（无法连接）")

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _phase == "checking":
		_handle_manifest(result, code, body)
	elif _phase == "downloading":
		_handle_download(result, code)

func _handle_manifest(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_phase = "idle"
		status_changed.emit("检查更新失败（网络 %d）" % code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_phase = "idle"
		status_changed.emit("检查更新失败（清单格式错误）")
		return
	var manifest: Dictionary = parsed
	var remote_version := int(manifest.get("version", 0))
	var pck_url := str(manifest.get("pck_url", ""))
	var notes := str(manifest.get("notes", ""))
	if remote_version <= installed_version or pck_url == "":
		_phase = "idle"
		status_changed.emit("已是最新版本 v%d" % installed_version)
		return
	_pending_version = remote_version
	_pending_notes = notes
	_phase = "downloading"
	status_changed.emit("发现新版本 v%d，正在下载…" % remote_version)
	_http.download_file = TMP_PATH
	var err := _http.request(pck_url)
	if err != OK:
		_http.download_file = ""
		_phase = "idle"
		status_changed.emit("下载失败（无法连接）")

func _handle_download(result: int, code: int) -> void:
	_http.download_file = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_phase = "idle"
		if FileAccess.file_exists(TMP_PATH):
			DirAccess.remove_absolute(TMP_PATH)
		status_changed.emit("下载失败（网络 %d）" % code)
		return
	if FileAccess.file_exists(PCK_PATH):
		DirAccess.remove_absolute(PCK_PATH)
	var move_err := DirAccess.rename_absolute(TMP_PATH, PCK_PATH)
	if move_err != OK:
		_phase = "idle"
		status_changed.emit("下载完成但写入失败")
		return
	_write_state({"pck_version": _pending_version})
	_phase = "idle"
	status_changed.emit("已下载 v%d，重启游戏生效" % _pending_version)
	update_ready.emit(_pending_version, _pending_notes)

func _process(_delta: float) -> void:
	if _phase == "downloading" and _http != null:
		var total := _http.get_body_size()
		var got := _http.get_downloaded_bytes()
		if total > 0:
			status_changed.emit("下载新版本 v%d… %d%%" % [_pending_version, int(float(got) / float(total) * 100.0)])

func _read_state() -> Dictionary:
	if not FileAccess.file_exists(STATE_PATH):
		return {}
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _write_state(state: Dictionary) -> void:
	var file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state))
