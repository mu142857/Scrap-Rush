class_name HiddenElite
extends EliteBase
## 隐藏关「第四盘·倒带」精英的公共底子（八音盒、雪花球、摄像机；设计：夜间打磨/隐藏关设计.md 5.2）。
## 照第三关精英（l3_elite.gd）的规矩：
## - 走向主角、保持距离；冷却到了从 moves 里抽签不放回出一招（每种招放的次数一样多）；
## - 每招预警 WARN_TIME（0.85 秒），预警时整只一闪一闪发白、地上 / 空中画红色出招标记（_draw_marks）；
## - 血掉到一半"狂暴"：冷却 ×0.6、走路更快、头顶冒火；子类在 _enrage_extra() 里加自己的（八音盒上满弦转速 ×1.6……）；
## - 死亡：EliteBase 的坏掉 1.1 秒 + 顺着最后一下的方向迸碎片（HitFx），隐藏关精英不掉武器。
## 子类要写：_setup()（贴图、血量、名字）、moves、_begin_move(move, p)、_tick_move(delta) -> bool（招放完返回 true）、
## _draw_marks(ci)（预警和出招中的标记，世界坐标）。
## 和隐藏关核心机制"灯照回忆"的接口：光源走 emit_light()，接口文档到了再对（见 夜间打磨/隐藏关接口.md）。

enum { WALK, WARN, ACT, RECOVER, STUN }

const WARN_TIME := 0.85
const COOLDOWN := Vector2(0.45, 0.8)
const RAGE_HP := 0.5
const RAGE_COOL := 0.6
const RAGE_SPEED := 1.3

var moves: Array = []
var walk_speed := 16.0
var keep_near := 40.0
var keep_far := 90.0

var _state := WALK
var _timer := 0.0
var _cool := 0.9
var _move := ""
var _last_move := ""
var _bag: Array = []
var _pattern := ""              # 给 tools/qa/elite_regression.gd 分招数用：预警到出完是招名，招和招之间是空的
var _rage := false
var _marks: Node2D
var _fx: Node2D
var _stun_t := 0.0


func _after_ready() -> void:
	_marks = Node2D.new()
	_marks.top_level = true
	_marks.z_index = 8
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_marks.material = m
	_marks.draw.connect(func() -> void: _draw_marks(_marks))
	add_child(_marks)
	_fx = Node2D.new()
	_fx.z_index = 7
	var m2 := CanvasItemMaterial.new()
	m2.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_fx.material = m2
	_fx.draw.connect(func() -> void: _draw_fx(_fx))
	add_child(_fx)


func _tick(delta: float) -> void:
	_timer -= delta
	_cool -= delta
	if not _rage and hp <= max_hp * RAGE_HP and not dying():
		_rage = true
		Game.add_shake(6.0)
		Game.sfx("jet", -4.0, 0.55)
		Game.sparks(get_parent(), aim_point(), EnemyBase.LED_HOT, 16, 120.0)
		_flash = 1.0
		_enrage_extra()
	var p := nearest_player(420.0)
	match _state:
		WALK:
			_walk(p)
			set_frame(int(_time / 0.25) % 2)
			if p and _cool <= 0.0 and is_on_floor():
				_pick()
				_state = WARN
				_timer = WARN_TIME
				velocity.x = 0.0
				warn(WARN_TIME)
				p = pick_focus(p)
				dir = 1 if p.global_position.x > global_position.x else -1
				_plan(_move, p)
		WARN:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			set_frame(2)
			if _timer <= 0.0:
				_state = ACT
				_begin_move(_move, focus_player())
		ACT:
			if _tick_move(delta):
				_recover(0.5)
		STUN:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			set_frame(4)
			if _timer <= 0.0:
				_recover(0.3)
		RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			set_frame(0)
			if _timer <= 0.0:
				_state = WALK
				_cool = randf_range(COOLDOWN.x, COOLDOWN.y) * interval_mult() * (RAGE_COOL if _rage else 1.0)
	move_and_slide()
	_pattern = "" if _state == WALK or _state == RECOVER or _state == STUN else _move
	_marks.queue_redraw()
	_fx.queue_redraw()


func _walk(p: Player) -> void:
	velocity.x = 0.0
	if p == null:
		return
	dir = 1 if p.global_position.x > global_position.x else -1
	var dist := absf(p.global_position.x - global_position.x)
	var spd := walk_speed * speed_mult() * (RAGE_SPEED if _rage else 1.0)
	if dist > keep_far and ground_ahead(12.0) and not is_on_wall():
		velocity.x = dir * spd
	elif dist < keep_near:
		dir = -dir
		if ground_ahead(12.0) and not is_on_wall():
			velocity.x = dir * spd * 0.8
		dir = -dir


func _pick() -> void:
	if _bag.is_empty():
		_bag = moves.duplicate()
		_bag.shuffle()
		if _bag.size() > 1 and _bag.back() == _last_move:
			_bag.reverse()
	_move = _bag.pop_back()
	_last_move = _move


func _recover(t: float) -> void:
	_state = RECOVER
	_timer = t


## 打晕（八音盒上过头、雪花球玻璃碎……）：t 秒站着不动、挨打照常
func stun(t: float) -> void:
	_state = STUN
	_timer = t
	_pattern = ""
	Game.sfx("clang", -6.0, 0.7)
	Game.sparks(get_parent(), aim_point(), Color(1.0, 0.9, 0.6), 10, 90.0, Vector2.UP)


## 子类覆盖
func _plan(_m: String, _p: Player) -> void:
	pass


func _begin_move(_m: String, _p: Player) -> void:
	pass


func _tick_move(_delta: float) -> bool:
	return true


func _draw_marks(_ci: CanvasItem) -> void:
	pass


func _enrage_extra() -> void:
	pass


## 狂暴时头顶冒火（和第三关精英一样，红 / 橙 / 黄 1 像素火苗，不吃光照）；子类可以接着画自己的
func _draw_fx(ci: CanvasItem) -> void:
	if not _rage or dead or dying():
		return
	var top := -body_rect.size.y - 1.0
	var w := int(body_rect.size.x)
	var x0 := int(body_rect.position.x)
	var cols := [EnemyBase.LED_COLOR, EnemyBase.LED_HOT, Color(1.0, 0.8, 0.35)]
	var tick := int(_time * 12.0)
	for i in range(0, w, 3):
		var h := (tick * 7 + i * 13) % 6
		for k in h:
			var c: Color = cols[mini(k * 3 / maxi(h, 1), 2)]
			c.a = 0.9 - 0.12 * k
			ci.draw_rect(Rect2(Vector2(x0 + i, top + 2 - k), Vector2.ONE), c)


## 预警时整只一闪一闪发白
func _update_visual() -> void:
	super._update_visual()
	if _state == WARN and not dead and not dying():
		var k := clampf(1.0 - _timer / WARN_TIME, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(_time * (14.0 + 26.0 * k))
		var mat := _sprite.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("flash", maxf(_flash, pulse * (0.25 + 0.35 * k)))


## ---- 小工具 ----

## 打一下站在这条线段附近（width 以内）的主角
func hurt_players_on_segment(a: Vector2, b: Vector2, width: float, dmg: float) -> void:
	for n in get_tree().get_nodes_in_group("player"):
		var pl := n as Player
		if pl == null:
			continue
		var c := pl.global_position + Vector2(0, -9)
		var t := clampf((c - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
		if c.distance_to(a.lerp(b, t)) <= width + 4.0:
			pl.hurt(a.lerp(b, t), dmg * damage_mult())


func hurt_players_in_rect(r: Rect2, dmg: float) -> void:
	for n in get_tree().get_nodes_in_group("player"):
		var pl := n as Player
		if pl and r.grow(3.0).has_point(pl.global_position + Vector2(0, -9)):
			pl.hurt(r.get_center(), dmg * damage_mult())


## 从 from 朝 d 打一条射线，碰到墙为止，最远 reach
func ray_end(from: Vector2, d: Vector2, reach: float) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(from, from + d * reach, 1)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector2) if not hit.is_empty() else from + d * reach


func ground_below(p: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(p + Vector2(0, -40), p + Vector2(0, 120), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return ((hit["position"] as Vector2) if not hit.is_empty() else p).round()


## 隐藏关"灯照回忆"的光源：照到的地方回忆木板变实、覆盖层平台化掉（八音盒的光束、摄像机的补光灯）。
## 接口文档还没到：先找 "hidden_light" 组里的系统节点，有 add_light(pos, radius, seconds) / add_segment(a, b, width, seconds) 就调
func emit_light(pos: Vector2, radius: float, seconds: float) -> void:
	for n in get_tree().get_nodes_in_group("hidden_light"):
		if n.has_method("add_light"):
			n.call("add_light", pos, radius, seconds)


func emit_light_segment(a: Vector2, b: Vector2, width: float, seconds: float) -> void:
	for n in get_tree().get_nodes_in_group("hidden_light"):
		if n.has_method("add_segment"):
			n.call("add_segment", a, b, width, seconds)


## 画一段像素虚线（预警标记用）
static func dash(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, on := 3, off := 3) -> void:
	var len := a.distance_to(b)
	var n := int(len)
	for k in n:
		if k % (on + off) < on:
			ci.draw_rect(Rect2(a.lerp(b, float(k) / maxf(len, 1.0)).round(), Vector2.ONE), col)
