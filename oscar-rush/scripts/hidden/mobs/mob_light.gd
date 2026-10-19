extends RefCounted
## 隐藏关「第四盘·倒带」小怪用的"光"（总机台/留声机会话 10-18）。
## 五种小怪查光、啃灯都只走这里：剧情会话的隐藏关接口（夜间打磨/隐藏关接口.md）到了以后，只改这个文件对接。
## 现在的临时做法：
## - 光源 = 马灯（Crystal，提着或放在地上，半径 Crystal.LIGHT_RADIUS，被磁粉蛾啃会变小）
##   + 加进 "hidden_light" 组的节点（有 light_radius 属性就按它，没有按 40）。
## - 情绪越高光圈越小（设计稿 2.1）：平静 ×1、烦躁 ×0.95、愤怒 ×0.85、失控 ×0.7。

const BITE_STEP := 0.1
const BITE_MAX := 5


## pos 在不在任何光里
static func lit(at: Node, pos: Vector2) -> bool:
	if at == null or not at.is_inside_tree():
		return false
	for c in at.get_tree().get_nodes_in_group("crystal"):
		var n := c as Node2D
		if n and lamp_center(n).distance_to(pos) <= lamp_radius(n):
			return true
	for l in at.get_tree().get_nodes_in_group("hidden_light"):
		var n := l as Node2D
		if n == null:
			continue
		var r = n.get("light_radius")
		if n.global_position.distance_to(pos) <= (float(r) if r != null else 40.0):
			return true
	return false


## 最近的一盏马灯（磁粉蛾扑它）
static func nearest_lamp(from: Node2D) -> Node2D:
	var best: Node2D = null
	var bd := INF
	for c in from.get_tree().get_nodes_in_group("crystal"):
		var n := c as Node2D
		if n == null:
			continue
		var d := lamp_center(n).distance_to(from.global_position)
		if d < bd:
			bd = d
			best = n
	return best


static func lamp_center(lamp: Node2D) -> Vector2:
	return lamp.global_position + Vector2(0, -5)


## 马灯现在照多远：基础半径 × 被啃掉的 × 情绪
static func lamp_radius(lamp: Node2D) -> float:
	var bites := int(lamp.get_meta("moth_bites", 0))
	return Crystal.LIGHT_RADIUS * (1.0 - BITE_STEP * bites) * emotion_mult()


static func emotion_mult() -> float:
	var e := Run.emotion
	if e >= 75.0:
		return 0.7
	if e >= 50.0:
		return 0.85
	if e >= 25.0:
		return 0.95
	return 1.0


## 磁粉蛾啃一口（d = +1）/ 松口或死了还回来（d = -1）：每口 -10%，最多啃掉一半。灯的光也跟着变小
static func bite(lamp: Node2D, d: int) -> void:
	if not is_instance_valid(lamp):
		return
	var n := clampi(int(lamp.get_meta("moth_bites", 0)) + d, 0, 99)
	lamp.set_meta("moth_bites", n)
	# 实际起作用的口数封顶 BITE_MAX（多出来的蛾子啃不动，但还记着，打死时一只只还）
	lamp.set_meta("moth_bites", n)
	var eff := mini(n, BITE_MAX)
	lamp.set_meta("moth_bites_eff", eff)
	for ch in lamp.get_children():
		if ch is PointLight2D:
			if not lamp.has_meta("moth_base_scale"):
				lamp.set_meta("moth_base_scale", (ch as PointLight2D).texture_scale)
			(ch as PointLight2D).texture_scale = float(lamp.get_meta("moth_base_scale")) * (1.0 - BITE_STEP * eff)
			break
