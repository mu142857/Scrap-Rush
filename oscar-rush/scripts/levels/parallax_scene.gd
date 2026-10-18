class_name ParallaxScene
extends Node2D
## 关卡背景视差：Oscar 的场景按图层分组导出（tools/export_art.py 的 SCENE_LAYER_GROUPS），
## 越远的一组跟镜头走得越慢、颜色越暗越偏冷。
## 镜头在关卡正中时各层对齐成原图；往两边走时远层"落后"，露出来的永远是图层内部，不会看到边。
## 竖直方向视差减半，免得背景里的支架和能站的平台上下错开太多。

## 每层：[图片, 跟镜头的比例, 颜色]
var layers: Array = []
## 关卡大小，正中就是各层对齐的位置
var bounds := Rect2(0, 0, 1006, 426)

var _sprites: Array[Sprite2D] = []
var _scales: Array[float] = []


func _ready() -> void:
	# 等镜头这一帧挪完再跟
	process_priority = 100
	for i in layers.size():
		var l: Array = layers[i]
		var s := Sprite2D.new()
		s.texture = l[0]
		s.centered = false
		s.modulate = l[2]
		s.z_index = -20 + i
		add_child(s)
		_sprites.append(s)
		_scales.append(l[1])
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var off := cam.get_screen_center_position() - bounds.get_center()
	for i in _sprites.size():
		var lag := 1.0 - _scales[i]
		# 不取整：镜头本身是平滑移动的（位置带小数），图层取整反而会相对镜头一格一格地跳，
		# 远景跟着抖（2026-10-17 夜间实测：主角走路时远景每帧 -0.63 / +0.37 来回跳）
		_sprites[i].position = Vector2(off.x * lag, off.y * lag * 0.5)
