class_name Splatter
extends Node2D
## 血溅 / 机油溅（作者 10-18："能做出血溅效果吗？当然我就怕粒子特效过多吃掉性能，而且其实我这里有血有肉的真不多"）。
## 机器怪溅机油（近黑、深褐，偶尔一点反光），人形怪溅血（HitFx.is_flesh 认）。
## 性能：整个场景只有一个节点，一个 _draw 画所有点，每滴不建节点、不用粒子。
## 飞着的点受重力，落到地面高度就停下、摊成一小块斑，几秒后一档一档变淡没掉。
## 同屏最多 MAX_DOTS 个点（网页版减半），超过就把最老的回收。
## 地面高度每次溅只往下打一条射线（不是每滴每帧都查物理）。墙上不留印子。

const MAX_DOTS := 150
const GRAVITY := 520.0
## 地上的斑留几秒（最后 1.5 秒分两档变淡）
const STAIN_LIFE := 5.0
## 飞着的点最多飞多久（底下没地面就飞出屏幕，到点删掉）
const FLY_LIFE := 1.6
const OIL: Array[Color] = [Color8(30, 26, 24), Color8(54, 46, 38), Color8(40, 34, 30), Color8(96, 82, 58)]
const BLOOD: Array[Color] = [Color8(132, 18, 22), Color8(176, 30, 32), Color8(104, 12, 18), Color8(150, 22, 26)]

static var _inst: Splatter
## 总开关（性能测试时关掉对比；真卡的时候也能一键关）
static var enabled := true

## 每个点：位置、速度、落地高度、颜色、年龄（落地后从 0 重新算）、落地没有、大小（1 或 2）
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _ground := PackedFloat32Array()
var _col: Array[Color] = []
var _age := PackedFloat32Array()
var _landed: Array[bool] = []
var _size := PackedByteArray()
var _redraw_t := 0.0


static func cap() -> int:
	return MAX_DOTS / 2 if OS.has_feature("web") else MAX_DOTS


## 从 pos 往 dir 方向溅 n 滴。flesh：血；否则机油。spread：散开的角度（度）
static func spray(from: Node, pos: Vector2, dir: Vector2, n: int, flesh: bool, speed := 1.0, spread := 40.0) -> void:
	if not enabled or n <= 0 or not is_instance_valid(from) or not from.is_inside_tree():
		return
	var s := _instance_for(from)
	if s == null:
		return
	if OS.has_feature("web"):
		n = maxi(1, n / 2)
	var ground := _find_ground(from, pos)
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.UP
	var pal := BLOOD if flesh else OIL
	for i in n:
		var a := deg_to_rad(randf_range(-spread, spread))
		var v := d.rotated(a) * randf_range(60.0, 170.0) * speed
		# 往上挑一点：溅出去是一道弧，不是直线
		v.y -= randf_range(30.0, 90.0)
		s._add(pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)), v, ground, pal[randi() % pal.size()], 2 if randf() < 0.25 else 1)


static func _instance_for(from: Node) -> Splatter:
	var scene := from.get_tree().current_scene
	if scene == null:
		return null
	if is_instance_valid(_inst) and _inst.is_inside_tree() and _inst.get_parent() == scene:
		return _inst
	_inst = Splatter.new()
	scene.add_child(_inst)
	return _inst


## 从溅的地方往下打一条射线找地面（单向平台也算）；底下 240 像素内没地就当没有
static func _find_ground(from: Node, pos: Vector2) -> float:
	var n2 := from as Node2D
	if n2 == null:
		return pos.y + 9999.0
	var space := n2.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(pos + Vector2(0, -2), pos + Vector2(0, 240), 1)
	var hit := space.intersect_ray(q)
	return (hit["position"] as Vector2).y - 1.0 if not hit.is_empty() else pos.y + 9999.0


func _ready() -> void:
	top_level = true
	z_index = 5


func _add(p: Vector2, v: Vector2, g: float, c: Color, sz: int) -> void:
	if _pos.size() >= cap():
		_remove(0)
	_pos.append(p)
	_vel.append(v)
	_ground.append(g)
	_col.append(c)
	_age.append(0.0)
	_landed.append(false)
	_size.append(sz)
	_redraw_t = 0.0


func _remove(i: int) -> void:
	_pos.remove_at(i)
	_vel.remove_at(i)
	_ground.remove_at(i)
	_col.remove_at(i)
	_age.remove_at(i)
	_landed.remove_at(i)
	_size.remove_at(i)


func _process(delta: float) -> void:
	if _pos.is_empty():
		return
	var flying := false
	var i := _pos.size() - 1
	while i >= 0:
		_age[i] += delta
		if _landed[i]:
			if _age[i] > STAIN_LIFE:
				_remove(i)
				_redraw_t = 0.0
		else:
			flying = true
			var v := _vel[i]
			v.y += GRAVITY * delta
			var p := _pos[i] + v * delta
			if p.y >= _ground[i] and v.y > 0.0:
				p.y = _ground[i]
				_landed[i] = true
				_age[i] = 0.0
			elif _age[i] > FLY_LIFE:
				_remove(i)
				i -= 1
				continue
			_vel[i] = v
			_pos[i] = p
		i -= 1
	# 有在飞的点就每帧重画；只剩地上的斑时每 0.25 秒画一次（淡出是一档一档的，不用每帧）
	_redraw_t -= delta
	if flying or _redraw_t <= 0.0:
		_redraw_t = 0.25
		queue_redraw()


func _draw() -> void:
	for i in _pos.size():
		var p := _pos[i].round()
		var c := _col[i]
		if not _landed[i]:
			# 飞着：一格，大滴两格（顺着速度拖一格）
			draw_rect(Rect2(p, Vector2.ONE), c)
			if _size[i] == 2:
				draw_rect(Rect2(p - _vel[i].normalized().round(), Vector2.ONE), c)
			continue
		# 地上的斑：摊开成 2~3 格宽、1 格高；最后 1.5 秒分两档变淡
		var left := STAIN_LIFE - _age[i]
		if left < 0.75:
			c.a *= 0.35
		elif left < 1.5:
			c.a *= 0.65
		draw_rect(Rect2(p + Vector2(-1, 0), Vector2(2 + _size[i], 1)), c)
