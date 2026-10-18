class_name Splatter
extends Node2D
## 血溅 / 机油溅（作者 10-18："能做出血溅效果吗？当然我就怕粒子特效过多吃掉性能，而且其实我这里有血有肉的真不多"）。
## 机器怪溅机油（近黑、深褐，偶尔一点反光），人形怪溅血（HitFx.is_flesh 认）。
## 性能：整个场景只有一个节点，一个 _draw 画所有点，每滴不建节点、不用粒子。
## 飞着的点受重力，落到地面高度就停下、摊成一小块斑，几秒后一档一档变淡没掉。
## 同屏最多 MAX_DOTS 个点（网页版减半），超过就把最老的回收。
## 地面高度每次溅只往下打一条射线（不是每滴每帧都查物理）。墙上不留印子。
## 10-18 碰撞会话：原来靠墙、台边溅的点会钻进墙里、停在台子外的半空。现在每次溅再往左右各打一条射线找墙，
## 点飞到墙就贴着墙往下掉；每滴落地那一下再打一条短射线确认脚下真有地，没有就接着往下掉到下面的地。
## 单向平台（第三关第 7 层）也算地。

const MAX_DOTS := 150
const GRAVITY := 520.0
## 地上的斑留几秒（最后 1.5 秒分两档变淡）
const STAIN_LIFE := 5.0
## 飞着的点最多飞多久（底下没地面就飞出屏幕，到点删掉）
const FLY_LIFE := 1.6
## 找地用的层：实心地面 + 单向平台
const GROUND_MASK := 1 | 64
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
## 每滴能飞到的左右边界（溅的那一刻左右最近的墙）
var _lo := PackedFloat32Array()
var _hi := PackedFloat32Array()
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
	var walls := _find_walls(from, pos)
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.UP
	var pal := BLOOD if flesh else OIL
	for i in n:
		var a := deg_to_rad(randf_range(-spread, spread))
		var v := d.rotated(a) * randf_range(60.0, 170.0) * speed
		# 往上挑一点：溅出去是一道弧，不是直线
		v.y -= randf_range(30.0, 90.0)
		s._add(pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)), v, ground, pal[randi() % pal.size()], 2 if randf() < 0.25 else 1,
				walls.x, walls.y)


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
	var q := PhysicsRayQueryParameters2D.create(pos + Vector2(0, -2), pos + Vector2(0, 240), GROUND_MASK)
	var hit := space.intersect_ray(q)
	return (hit["position"] as Vector2).y - 1.0 if not hit.is_empty() else pos.y + 9999.0


## 从溅的地方往左右各打一条射线找墙，返回 (左边能到的 x, 右边能到的 x)；200 像素内没墙就不限
static func _find_walls(from: Node, pos: Vector2) -> Vector2:
	var n2 := from as Node2D
	if n2 == null:
		return Vector2(-INF, INF)
	var space := n2.get_world_2d().direct_space_state
	var out := Vector2(-INF, INF)
	for side in [-1.0, 1.0]:
		var q := PhysicsRayQueryParameters2D.create(pos, pos + Vector2(side * 200.0, 0), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var x: float = (hit["position"] as Vector2).x
			if side < 0.0:
				out.x = x + 0.5
			else:
				out.y = x - 2.5
	return out


func _ready() -> void:
	top_level = true
	z_index = 5


func _add(p: Vector2, v: Vector2, g: float, c: Color, sz: int, lo := -INF, hi := INF) -> void:
	if _pos.size() >= cap():
		_remove(0)
	_pos.append(p)
	_vel.append(v)
	_ground.append(g)
	_col.append(c)
	_age.append(0.0)
	_landed.append(false)
	_size.append(sz)
	_lo.append(lo)
	_hi.append(maxf(hi, lo))
	_redraw_t = 0.0


func _remove(i: int) -> void:
	_pos.remove_at(i)
	_vel.remove_at(i)
	_ground.remove_at(i)
	_col.remove_at(i)
	_age.remove_at(i)
	_landed.remove_at(i)
	_size.remove_at(i)
	_lo.remove_at(i)
	_hi.remove_at(i)


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
			# 飞到墙：贴着墙往下掉
			if p.x < _lo[i] or p.x > _hi[i]:
				p.x = clampf(p.x, _lo[i], _hi[i])
				v.x = 0.0
			if p.y >= _ground[i] and v.y > 0.0:
				var g := _land_at(_pos[i], p.x, _ground[i])
				if g != Vector2.INF:
					p = g
					_landed[i] = true
					_age[i] = 0.0
				else:
					# 这一列没地（飞出了台边）：往下找下面的地，接着掉
					_ground[i] = _ground_from(Vector2(p.x, _ground[i] + 2.0))
			if not _landed[i] and _age[i] > FLY_LIFE:
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


## 点要落到 ground 这一高度时：从上一帧的位置往 (x, ground) 下面一点打一条射线，碰到朝上的面就落在那儿。
## 打不到朝上的面（上一帧已经钻进了比 ground 高一点的台阶、或者撞到台阶侧面）：从上面 16 像素往下再找一次。
## 返回落点；这一列没地（飞出了台边）返回 Vector2.INF
func _land_at(prev: Vector2, x: float, ground: float) -> Vector2:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(prev, Vector2(x, ground + 2.0), GROUND_MASK)
	# 从实心里面打出去的射线会碰到多边形内部的分割线，当成地面落在里面；所以从里面出发直接算"打不到"
	q.hit_from_inside = true
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and (hit["normal"] as Vector2) == Vector2.ZERO:
		hit = {}
	if not hit.is_empty() and (hit["normal"] as Vector2).y < -0.5:
		return Vector2(x, (hit["position"] as Vector2).y - 1.0)
	var top := space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, minf(prev.y, ground) - 16.0), Vector2(x, ground + 2.0), 1))
	if not top.is_empty() and (top["normal"] as Vector2).y < -0.5:
		return Vector2(x, (top["position"] as Vector2).y - 1.0)
	if not hit.is_empty():
		# 撞到墙的侧面：贴着墙落在原来的高度，不钻进去
		var at: Vector2 = hit["position"]
		return Vector2(at.x + (0.5 if (hit["normal"] as Vector2).x > 0.0 else -1.5), ground)
	return Vector2.INF


func _ground_from(p: Vector2) -> float:
	var q := PhysicsRayQueryParameters2D.create(p, p + Vector2(0, 240), GROUND_MASK)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector2).y - 1.0 if not hit.is_empty() else p.y + 9999.0


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
