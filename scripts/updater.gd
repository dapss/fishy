# Checks GitHub for a newer release and, when the player says so, replaces
# the running exe with the new one and restarts.
#
# Only ever downloads the "fishy.exe" asset of this repo's latest release.
# Windows lets a running exe be renamed (not deleted), so the swap is:
#   fishy.exe -> fishy.old.exe, fishy.new.exe -> fishy.exe, restart.
# If any step fails the old exe is put back. fishy.old.exe is removed on the
# next launch.
extends Node

signal update_found(info: Dictionary)      # {version, notes, page, url, size}
signal up_to_date(version: String)
signal check_failed(reason: String)
signal download_progress(fraction: float)
signal download_failed(reason: String)
signal ready_to_restart

const API_URL := "https://api.github.com/repos/dapss/fishy/releases/latest"
const PAGE_URL := "https://github.com/dapss/fishy/releases/latest"
const ASSET_NAME := "fishy.exe"

var current_version := ""
var busy := false
var _api_url := API_URL
var _http: HTTPRequest
var _info: Dictionary = {}
var _downloading := false
var _auto := false        # debug test hook: download as soon as one is found


func _ready() -> void:
	current_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	# Test hooks, only honoured by debug builds (never by a release exe):
	#   -- --update-url=http://127.0.0.1:8765/latest.json --fake-version=0.1.0
	if OS.is_debug_build():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--update-url="):
				_api_url = arg.trim_prefix("--update-url=")
			elif arg.begins_with("--fake-version="):
				current_version = arg.trim_prefix("--fake-version=")
			elif arg == "--auto-update":
				_auto = true
	_http = HTTPRequest.new()
	# A thread and big chunks: otherwise it reads one 64 KB chunk per frame,
	# which takes minutes at the game's low frame rate.
	_http.use_threads = true
	_http.download_chunk_size = 1 << 20
	_http.request_completed.connect(_on_completed)
	add_child(_http)


func _process(_dt: float) -> void:
	if _downloading and _info.get("size", 0) > 0:
		download_progress.emit(clampf(float(_http.get_downloaded_bytes()) / float(_info.size), 0.0, 1.0))


# Can this copy replace itself? Only an exported game in a folder it can
# write to (not the editor, not Program Files without admin).
func can_self_update() -> bool:
	if not OS.has_feature("template") or OS.get_name() != "Windows":
		return false
	var probe := _exe_dir() + "/.fishy_write_test"
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


func check() -> void:
	if busy:
		return
	busy = true
	_downloading = false
	_http.download_file = ""
	_http.timeout = 20.0
	var err := _http.request(_api_url, _headers())
	if err != OK:
		busy = false
		check_failed.emit("no connection")


func download() -> void:
	if busy or _info.is_empty() or not can_self_update():
		return
	busy = true
	_downloading = true
	_http.download_file = _new_path()
	_http.timeout = 0.0          # big file on a slow connection: no limit
	DirAccess.remove_absolute(_new_path())
	var err := _http.request(_info.url, ["User-Agent: fishy-updater"])
	if err != OK:
		_fail_download("couldn't start the download")


# Swap the exes. Returns true when the new one is in place.
func install() -> bool:
	var exe := OS.get_executable_path()
	var old := _old_path()
	DirAccess.remove_absolute(old)
	if DirAccess.rename_absolute(exe, old) != OK:
		return false
	if DirAccess.rename_absolute(_new_path(), exe) != OK:
		DirAccess.rename_absolute(old, exe)          # put the old one back
		return false
	return true


func restart() -> void:
	OS.create_process(OS.get_executable_path(), [])


# Leftovers from the last update. The old process may still be closing, so
# try again a little later if it's locked.
func cleanup() -> void:
	if not OS.has_feature("template"):
		return
	for p in [_old_path(), _new_path()]:
		if FileAccess.file_exists(p) and DirAccess.remove_absolute(p) != OK:
			get_tree().create_timer(5.0).timeout.connect(func(): DirAccess.remove_absolute(p))


func _on_completed(result: int, code: int, _headers_out: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	if _downloading:
		_downloading = false
		_on_downloaded(result, code)
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		check_failed.emit("no connection" if result != HTTPRequest.RESULT_SUCCESS else "GitHub said %d" % code)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary) or not data.has("tag_name"):
		check_failed.emit("unexpected reply")
		return
	var latest := str(data.tag_name).trim_prefix("v")
	if not is_newer(latest, current_version):
		up_to_date.emit(current_version)
		return
	var info := {
		"version": latest,
		"notes": str(data.get("body", "")),
		"page": str(data.get("html_url", PAGE_URL)),
		"url": "",
		"size": 0,
	}
	for asset in data.get("assets", []):
		if asset is Dictionary and asset.get("name", "") == ASSET_NAME:
			info.url = str(asset.get("browser_download_url", ""))
			info.size = int(asset.get("size", 0))
	_info = info
	update_found.emit(info)
	if _auto:
		download()


func _on_downloaded(result: int, code: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail_download("the download didn't finish")
		return
	var f := FileAccess.open(_new_path(), FileAccess.READ)
	if f == null:
		_fail_download("couldn't read the download")
		return
	var length := f.get_length()
	var head := f.get_buffer(2)
	f.close()
	# Must be exactly what GitHub listed, and a Windows program.
	if length != int(_info.size) or head.get_string_from_ascii() != "MZ":
		_fail_download("the download looks wrong")
		return
	ready_to_restart.emit()


func _fail_download(reason: String) -> void:
	busy = false
	_downloading = false
	DirAccess.remove_absolute(_new_path())
	download_failed.emit(reason)


# "0.10.0" > "0.9.3": compare number by number.
static func is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func _headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: fishy-updater", "Accept: application/vnd.github+json"])


func _exe_dir() -> String:
	return OS.get_executable_path().get_base_dir()


func _new_path() -> String:
	return _exe_dir() + "/fishy.new.exe"


func _old_path() -> String:
	return _exe_dir() + "/fishy.old.exe"
