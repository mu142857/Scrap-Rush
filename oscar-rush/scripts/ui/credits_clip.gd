class_name CreditsClip
extends Control
## 制作人员页上每页播的一小段动画（作者 10-18："显示名字的时候播放一些动画"）。立绘添加会话做的素材和播放器，
## 页面本身（credits_menu.gd）归游戏细节讨论会话。
## 素材：art/credits/<名字>.png，一张精灵图，每帧 FRAME 大小（默认 192×108），10 列一行、从左到右从上到下，
##       12 帧/秒循环。帧是从游戏里录的（立绘添加会话 scratchpad 里的录像场景），或者从现成的图拼的（开场帧、立绘）。
## 用法：var c := CreditsClip.make("mumu_hammer")；c 可能是 null（素材还没有），有的话 add_child、摆位置；
##       scale_px = 2 整数倍放大；淡入淡出改 modulate。

## 每段：帧数、每秒几帧（没写就 12）、帧大小（没写就 192×108）
const CLIPS := {
	"mumu_lamp": {"frames": 36},
	"mumu_hammer": {"frames": 36},
	"mumu_pressure": {"frames": 36},
	"oscar_intro": {"frames": 28, "fps": 8},
	"oscar_run": {"frames": 36},
	"oscar_elite": {"frames": 36},
	"wutong_portraits": {"frames": 40},
	"music_furnace": {"frames": 36},
	"finale": {"frames": 40},
}
const COLS := 10
const FRAME := Vector2i(192, 108)
const DIR := "res://art/credits/"

var clip := ""
## 整数倍放大
var scale_px := 1:
	set(v):
		scale_px = maxi(1, v)
		_resize()
var playing := true

var _tex: Texture2D
var _frames := 1
var _fps := 12.0
var _frame_size := FRAME
var _t := 0.0


## 素材不存在时返回 null
static func make(name: String) -> CreditsClip:
	if not CLIPS.has(name) or not ResourceLoader.exists(DIR + name + ".png"):
		return null
	var c := CreditsClip.new()
	c.clip = name
	return c


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info: Dictionary = CLIPS[clip]
	_tex = load(DIR + clip + ".png")
	_frames = info["frames"]
	_fps = info.get("fps", 12.0)
	_frame_size = info.get("size", FRAME)
	_resize()


func _resize() -> void:
	size = Vector2(_frame_size * scale_px)
	custom_minimum_size = size


func _process(delta: float) -> void:
	if playing:
		_t += delta
		queue_redraw()


## 第几帧（从 0 开始）
func frame() -> int:
	return int(_t * _fps) % maxi(_frames, 1)


## 已经放完了几圈
func loops() -> int:
	return int(_t * _fps) / maxi(_frames, 1)


## 从第一帧重新放
func restart() -> void:
	_t = 0.0
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var f := frame()
	var src := Rect2(Vector2((f % COLS) * _frame_size.x, (f / COLS) * _frame_size.y), Vector2(_frame_size))
	draw_texture_rect_region(_tex, Rect2(Vector2.ZERO, Vector2(_frame_size * scale_px)), src)
