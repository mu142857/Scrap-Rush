class_name Progress
extends RefCounted
## 关卡进度：第几关打到过（进入过）。开始菜单的"选择关卡"按这个解锁：第一关一直能选，
## 第二关、第三关第一次走进去以后才能直接选（作者 2026-10-18 定的"打到过才解锁"）。
## 存在 user://progress.cfg，和设置分开。测试时：
##   SCRAP_PROGRESS_PATH=<文件> 直接指定；或者只设了 SCRAP_SETTINGS_PATH，就放在同一个目录的 progress.cfg，
##   不会改到作者真正的存档。
## Game 换场景时调 Progress.reach_scene(path)。

const DEFAULT_PATH := "user://progress.cfg"
## 场景 → 第几关
const SCENE_LEVEL := {
	"res://scenes/test_level.tscn": 1, "res://scenes/boss1.tscn": 1,
	"res://scenes/level2_tube.tscn": 2, "res://scenes/level2.tscn": 2, "res://scenes/boss2.tscn": 2,
	"res://scenes/level3.tscn": 3, "res://scenes/boss3.tscn": 3,
}

static var _loaded := false
static var _reached := 1


static func path() -> String:
	var p := OS.get_environment("SCRAP_PROGRESS_PATH")
	if p != "":
		return p
	var s := OS.get_environment("SCRAP_SETTINGS_PATH")
	if s != "":
		return s.get_base_dir().path_join("progress.cfg")
	return DEFAULT_PATH


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var c := ConfigFile.new()
	if c.load(path()) == OK:
		_reached = clampi(int(c.get_value("progress", "reached", 1)), 1, 3)


## 打到过的最远一关（1~3）
static func reached() -> int:
	_load()
	return _reached


static func unlocked(level: int) -> bool:
	return level <= reached()


## 能不能写进存档：正式导出的游戏、作者在编辑器里按 F5 跑的才写；
## 命令行跑的测试、headless、录像只记在内存里（各会话的测试会直接进第二、三关，不然作者一开游戏就全解锁了）。
## 设了 SCRAP_PROGRESS_PATH / SCRAP_SETTINGS_PATH 的测试写到它们自己的文件，照常写。
static func _may_save() -> bool:
	if OS.get_environment("SCRAP_PROGRESS_PATH") != "" or OS.get_environment("SCRAP_SETTINGS_PATH") != "":
		return true
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path() != "":
		return false
	if OS.has_feature("template"):
		return true
	for a in OS.get_cmdline_args():
		if a == "--editor-pid" or a.begins_with("--remote-debug"):
			return true
	return false


static func reach(level: int) -> void:
	_load()
	if level <= _reached:
		return
	_reached = clampi(level, 1, 3)
	if not _may_save():
		return
	var c := ConfigFile.new()
	c.load(path())
	c.set_value("progress", "reached", _reached)
	c.save(path())


static func reach_scene(scene_path: String) -> void:
	if SCENE_LEVEL.has(scene_path):
		reach(SCENE_LEVEL[scene_path])
