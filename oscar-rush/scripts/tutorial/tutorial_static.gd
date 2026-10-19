class_name TutorialStatic
extends Node2D
## 阁楼地上的一片雪花（教学关第 3 步）：踩上去被弹回左边（关卡判定，这里只画、只出声）。
## bridge() 以后上面铺一排木板，雪花关掉。原点在左端的地面上。

const PLANK_PATH := "res://art/hidden/plank_memory.png"
var PLANK: Texture2D = load(PLANK_PATH) if ResourceLoader.exists(PLANK_PATH) else null
## 放映机会话画的雪花带（art/tutorial/static_band.png，48×8，三帧 16×8 横排，每帧能平铺）；没有就用代码画
const BAND_PATH := "res://art/tutorial/static_band.png"
var BAND: Texture2D = load(BAND_PATH) if ResourceLoader.exists(BAND_PATH) else null
var width := 280.0
var bridged := false
var _t := 0.0
var _k := 0.0


func _ready() -> void:
	light_mask = TutorialLevel.NO_LIGHT_MASK
	z_index = -4
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded


func _process(delta: float) -> void:
	_t += delta
	if bridged:
		_k = minf(_k + delta / 0.6, 1.0)
	queue_redraw()


func zap(_x: float) -> void:
	Game.sfx("static", -10.0, 1.3)


func bridge() -> void:
	if bridged:
		return
	bridged = true
	Game.sfx("clang", -8.0, 1.3)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_t * 20.0)
	var h := 8
	if BAND and (not bridged or _k < 1.0):
		var fr := int(_t * 12.0) % 3
		var a := 1.0 - _k
		var x := 0.0
		while x < width:
			var w := minf(16.0, width - x)
			draw_texture_rect_region(BAND, Rect2(x, -8, w, 8), Rect2(fr * 16, 0, w, 8), Color(1, 1, 1, a))
			x += 16.0
	elif not bridged or _k < 1.0:
		for x in range(0, int(width), 2):
			for y in range(0, h, 2):
				if rng.randf() < 0.55:
					var v := rng.randf_range(0.55, 1.0)
					draw_rect(Rect2(x, -y - 2, 2, 2), Color(v, v, v + 0.05, 0.85 * (1.0 - _k)))
		# 雪花上面一道一闪一闪的白边，告诉你"别踩"
		if not bridged:
			draw_rect(Rect2(0, -h - 1, width, 1), Color(1, 1, 1, 0.35 + 0.25 * sin(_t * 8.0)))
	if bridged:
		# 木板从左往右铺过去：用放映机会话画的暖色木板贴图（art/hidden/plank_memory.png，16×6 平铺），没有就用色块
		var len := floorf(width * _k / 16.0) * 16.0
		if PLANK:
			draw_texture_rect(PLANK, Rect2(0, -6, len, 6), true)
		else:
			var n := int(len / 14.0)
			for i in n:
				var bx := i * 14.0
				draw_rect(Rect2(bx, -5, 13, 5), Color8(196, 150, 104))
				draw_rect(Rect2(bx, -5, 13, 1), Color8(226, 186, 136))
