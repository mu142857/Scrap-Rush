extends Node2D
## 开场动画（Oscar 画的 开场动画.aseprite）。游戏一打开先播这个，播完直接切到开始界面（菜单一出来就是完整的）。
## 帧是 tools/export_art.py --intro 导出的 art/intro/00.png ……；按任意键、点鼠标、按手柄键跳过。
## 带调试参数启动时直接交给开始界面，开始界面会再转去关卡，测试脚本不用等动画。

const TITLE_SCENE := "res://scenes/title.tscn"
const FRAME_DIR := "res://art/intro/%02d.png"
## 每帧多少秒，照原稿抄的。Oscar 改了帧数或时长，重导以后对着改这里
const DURATIONS: Array[float] = [
	0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1,
	0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1,
	0.1, 0.1, 0.5, 0.1, 0.1, 0.1, 0.1, 0.3,
]
## 第 22 帧喷出一大股蒸汽（原稿里停 0.5 秒的那帧）
const STEAM_FRAME := 22

var _frames: Array[Texture2D] = []
var _sprite: Sprite2D
var _index := 0
var _time := 0.0
var _leaving := false


func _ready() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)
		return
	for i in DURATIONS.size():
		_frames.append(load(FRAME_DIR % i))
	# 原稿透明的地方露出黑底
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(480, 270)
	add_child(bg)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _frames[0]
	add_child(_sprite)


func _process(delta: float) -> void:
	if _leaving or _frames.is_empty():
		return
	_time += delta
	while _time >= DURATIONS[_index]:
		_time -= DURATIONS[_index]
		_index += 1
		if _index >= _frames.size():
			_leave()
			return
		_sprite.texture = _frames[_index]
		if _index == STEAM_FRAME:
			Game.sfx("vent", -4.0)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	if pressed:
		get_viewport().set_input_as_handled()
		_leave()


## 直接切到开始界面，不淡出淡入
func _leave() -> void:
	_leaving = true
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)
