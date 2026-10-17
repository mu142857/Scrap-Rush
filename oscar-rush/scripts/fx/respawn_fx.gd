class_name RespawnFx
extends Node2D
## 重生动画（2026-10-17 作者试玩要的）：马灯碎了、从存档点（或关卡开头、Boss 房开头）重来时放一遍，总长约 1.2 秒。
##   0.00  画面全黑，慢慢亮回来
##   0.10  每个主角站的地方，一束暖色的光从上往下打下来
##   0.40  光柱最亮的一下：马灯"噗"地重新点燃，人从光里出现，冒一圈火星
##   0.40~ 人能动了（带着受伤无敌的闪烁，刚出来不会被秒）
##   1.20  光柱收掉，节点自己删掉
## 由 Run.start_level 在重载后、人摆好以后加进当前场景（Run._play_respawn）。只管画面，不管人站哪。

const TOTAL := 1.2
const FADE_TIME := 0.45
const BEAM_START := 0.1
const BEAM_DROP := 0.25
const APPEAR := 0.4
const BEAM_END := 1.1
const BEAM_HEIGHT := 70.0
const BEAM_WIDTH := 7
## 出来以后的无敌时间（玩家那边会照这个闪烁）
const SPAWN_INVULN := 1.4
const WARM := Color(1.0, 0.82, 0.55)
const CORE := Color(1.0, 0.97, 0.88)

var _t := 0.0
var _spots: Array[Vector2] = []
var _players: Array[Node2D] = []
var _hidden: Array[CanvasItem] = []
var _appeared := false
var _fade: ColorRect
var _lights: Array[PointLight2D] = []


func _ready() -> void:
	z_index = 40
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	process_mode = Node.PROCESS_MODE_ALWAYS

	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Node2D
		_players.append(p)
		_spots.append(p.global_position.round())
		# 人先藏起来、定住，等光柱打下来再出现
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
		_hidden.append(p)
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = WARM
		l.energy = 0.0
		l.texture_scale = 2.5
		l.position = p.global_position + Vector2(0, -10)
		add_child(l)
		_lights.append(l)
	# 手里提着的马灯跟人一起藏
	for c in get_tree().get_nodes_in_group("crystal"):
		var carrier = c.get("carrier")
		if carrier != null and _players.has(carrier):
			(c as CanvasItem).visible = false
			_hidden.append(c)

	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	Game.sfx("lantern_pick", -10.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	_fade.color.a = clampf(1.0 - _t / FADE_TIME, 0.0, 1.0)
	if not _appeared and _t >= APPEAR:
		_appear()
	for i in _lights.size():
		_lights[i].energy = _beam_strength() * 2.2
	queue_redraw()
	if _t >= TOTAL:
		_release()
		queue_free()


func _appear() -> void:
	_appeared = true
	_release()
	for i in _players.size():
		var p := _players[i]
		if is_instance_valid(p):
			p.set("_invuln", maxf(p.get("_invuln") if p.get("_invuln") != null else 0.0, SPAWN_INVULN))
		Game.sparks(get_parent(), _spots[i] + Vector2(0, -8), WARM, 10, 60.0)
		Game.dust(get_parent(), _spots[i], 4)
	Game.sfx("ready", -6.0, 0.8)
	Game.add_shake(1.5)


## 把藏起来、定住的人和马灯放出来（出现时、或者动画被打断时）
func _release() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
			n.process_mode = Node.PROCESS_MODE_INHERIT
	_hidden.clear()


func _exit_tree() -> void:
	_release()


## 光柱亮度 0~1：打下来时渐亮，出现那一下最亮，之后慢慢收
func _beam_strength() -> float:
	if _t < BEAM_START:
		return 0.0
	if _t < APPEAR:
		return lerpf(0.4, 1.0, (_t - BEAM_START) / (APPEAR - BEAM_START))
	return clampf(1.0 - (_t - APPEAR) / (BEAM_END - APPEAR), 0.0, 1.0)


func _draw() -> void:
	var a := _beam_strength()
	if a <= 0.0:
		return
	# 光柱从上往下落：BEAM_DROP 秒内下沿从头顶落到脚底
	var drop := clampf((_t - BEAM_START) / BEAM_DROP, 0.0, 1.0)
	for s in _spots:
		var p := s - global_position
		var bottom := p.y - BEAM_HEIGHT * (1.0 - drop)
		var top := p.y - BEAM_HEIGHT
		var h := bottom - top
		if h <= 0.0:
			continue
		var half := float(BEAM_WIDTH / 2)
		# 外圈淡、里圈亮、正中一条最亮；越往上越淡（一格一格画，保持像素感）
		var rows := int(h)
		for r in rows:
			var y := bottom - 1 - r
			var up := float(r) / BEAM_HEIGHT
			var k := a * (1.0 - up * 0.7)
			draw_rect(Rect2(p.x - half, y, BEAM_WIDTH, 1), Color(WARM, 0.25 * k))
			draw_rect(Rect2(p.x - 1, y, 3, 1), Color(WARM, 0.55 * k))
			draw_rect(Rect2(p.x, y, 1, 1), Color(CORE, 0.9 * k))
		# 落地的一圈光斑
		if drop >= 1.0:
			var w := 9 + int(4.0 * a)
			draw_rect(Rect2(p.x - w / 2, p.y - 1, w, 1), Color(CORE, 0.8 * a))
			draw_rect(Rect2(p.x - w / 2 - 2, p.y, w + 4, 1), Color(WARM, 0.45 * a))
