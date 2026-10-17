class_name IntroOverlay
extends CanvasLayer
## 开场动画（Oscar 画的 开场动画.aseprite），叠在开始界面最上面播：
## 前半段是黑底，零件、木桶一层层盖满屏幕，喷一股蒸汽；从 OPEN_FRAME 起中间裂开往两边打开，
## 这时才撤掉黑底，透明的地方露出底下已经摆好的菜单。
## 开始界面在 _ready 里加它，游戏打开只播一次；播完或跳过发 finished，菜单这才能操作。
## 帧是 tools/export_art.py --intro 导出的 art/intro/00.png ……；按任意键、点鼠标、按手柄键跳过。

signal finished

const FRAME_DIR := "res://art/intro/%02d.png"
## 每帧多少秒，照原稿抄的。Oscar 改了帧数或时长，重导以后对着改这里
const DURATIONS: Array[float] = [
	0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1,
	0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1,
	0.1, 0.1, 0.5, 0.1, 0.1, 0.1, 0.1, 0.3,
]
## 第 22 帧喷出一大股蒸汽（原稿里停 0.5 秒的那帧）
const STEAM_FRAME := 22
## 从这帧起开始"打开"（第 18~22 帧整屏盖满，23 帧中间裂开），之前透明的地方是黑的
const OPEN_FRAME := 23

## 本次运行播过没有；从关卡回到开始界面不再播
static var played := false

var _frames: Array[Texture2D] = []
var _sprite: Sprite2D
var _black: ColorRect
var _index := 0
var _time := 0.0
var _done := false


func _ready() -> void:
	played = true
	# 盖在开始界面的文字（第 20 层）上面
	layer = 40
	for i in DURATIONS.size():
		_frames.append(load(FRAME_DIR % i))
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = Vector2(480, 270)
	add_child(_black)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _frames[0]
	add_child(_sprite)


func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	while _time >= DURATIONS[_index]:
		_time -= DURATIONS[_index]
		_index += 1
		if _index >= _frames.size():
			_finish()
			return
		_sprite.texture = _frames[_index]
		_black.visible = _index < OPEN_FRAME
		if _index == STEAM_FRAME:
			Game.sfx("vent", -4.0)


func _input(event: InputEvent) -> void:
	if _done:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	if pressed:
		# 跳过的这一下不能顺手把菜单的 START 也按了
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	_done = true
	finished.emit()
	queue_free()
