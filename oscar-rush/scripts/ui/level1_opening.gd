class_name Level1Opening
extends Control
## 第一关的开场（LevelIntro 的内容）：奥斯卡画的开场帧（art/intro/00~27），这回叠在第一关的画面上播。
## 零件、木桶一层层盖上来把画面关上（"哐"一下冲击），憋住，喷一股蒸汽，再从中间裂开、往两边打开露出第一关，
## 同时镜头从稍近拉回、名字卡"第一关 · 锅炉间"淡入。总长约 4.5 秒（含收黑边），按任意键跳过。
## 关上的那段比原稿（每帧 0.1 秒）快一点，打开后的停顿也短一点，节奏不拖。

const FRAME_DIR := "res://art/intro/%02d.png"
const COUNT := 28
## 盖满整屏的第一帧：这一下"哐"
const SHUT_FRAME := 18
const STEAM_FRAME := 22
const OPEN_FRAME := 23
const CLOSE_STEP := 0.065
const SHUT_HOLD := 0.22
const PRESSURE_STEP := 0.07
const STEAM_HOLD := 0.38
const OPEN_STEP := 0.08
const LAST_HOLD := 0.2

var _sprite: Sprite2D
var _frames: Array[Texture2D] = []


func _ready() -> void:
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in COUNT:
		_frames.append(load(FRAME_DIR % i))
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _frames[0]
	add_child(_sprite)


func _step(i: int, t: float, intro: LevelIntro) -> void:
	if intro.skipped:
		return
	_sprite.texture = _frames[i]
	await get_tree().create_timer(t, true, false, true).timeout


func run(intro: LevelIntro) -> void:
	for i in SHUT_FRAME:
		await _step(i, CLOSE_STEP, intro)
	# 盖满了："哐"
	intro.impact(1.0)
	await _step(SHUT_FRAME, SHUT_HOLD, intro)
	for i in range(SHUT_FRAME + 1, STEAM_FRAME):
		await _step(i, PRESSURE_STEP, intro)
	# 憋住的那口气喷出去
	if not intro.skipped:
		Game.sfx("vent", 2.0, 0.85)
		intro.impact(0.35)
	await _step(STEAM_FRAME, STEAM_HOLD, intro)
	# 裂开：这一刻露出关卡（镜头拉回、名字卡淡入），门还在往两边退
	if not intro.skipped:
		Game.sfx("steam_blast", -10.0, 0.8)
		intro.reveal()
	for i in range(OPEN_FRAME, COUNT):
		await _step(i, OPEN_STEP if i < COUNT - 1 else LAST_HOLD, intro)
