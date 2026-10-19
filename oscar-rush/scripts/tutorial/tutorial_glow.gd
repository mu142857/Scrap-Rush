class_name TutorialGlow
extends Node2D
## 教学关里马灯脚边一圈淡淡的暖光（代替会过曝的点光源）：三圈像素圆，越往外越淡，跟着马灯走，一点点呼吸。
## 叠加混合，透明度很低，只是让人看得出"灯在这儿、在亮"。

var target: Node2D
var _t := 0.0


func _ready() -> void:
	z_index = 3
	light_mask = 4
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m


func _process(delta: float) -> void:
	_t += delta
	if target and is_instance_valid(target):
		global_position = (target.global_position + Vector2(0, -5)).round()
	queue_redraw()


func _draw() -> void:
	var hp := clampf(Run.crystal_hp / maxf(Run.crystal_max, 1.0), 0.0, 1.0)
	var breathe := 1.0 + 0.04 * sin(_t * 2.2)
	var warm := Color(1.0, 0.72, 0.38)
	for ring in [[46.0, 0.05], [30.0, 0.06], [16.0, 0.08]]:
		var r: float = ring[0] * breathe
		draw_circle(Vector2.ZERO, r, Color(warm, ring[1] * (0.5 + 0.5 * hp)))
