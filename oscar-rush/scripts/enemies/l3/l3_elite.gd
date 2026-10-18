class_name L3Elite
extends EliteBase
## 第三关的精英怪（每种屏幕场景一只：老冰箱、电视壳大寄居蟹……）。贴图和招式都在 cfg 里（见 L3Mob）。
## 平时慢慢走向主角，隔一会儿从 cfg["moves"] 里挑一招，出招前头顶冒红色"!"：
##   charge  横冲过场子，撞到墙或走到台子边停下
##   slam    高高跳向主角，落地往两边贴地打出两颗铆钉（冲击波）
##   spray   扇形打出 3 颗直线弹
##   volley  朝主角抛 2 颗抛物线弹（一远一近）
##   summon  在背后叫出 1 只本场景的小怪（场上最多 2 只叫出来的）
## 帧：0 待机、1 走、2 蓄力、3 出招、4 空中、5 亮相（出场动画和叫小怪时用）。
## 夜间打磨（10-18，照第一关精英）：
## - 死亡演出（EliteBase）：坏掉 1.1 秒再炸成碎块，碎块颜色跟着屏幕色调；挨打顿一格。
## - 预警：整只一闪一闪发白（第三关的贴图着色器会把颜色映射成黑白 / 绿 / 琥珀，发红在那几种屏幕里看不出来，
##   白闪是映射以后才叠上去的，哪种色调都看得见），越到最后闪得越快。
## - 出招前摇标记（红色，不吃色调映射）：冲撞画出冲过去的路线，跳砸标出落点，扇射画出三道射线，抛射标出两个落点。
##   跳砸和抛射在预警开始时就锁定目标，标记就是实际落点：看到标记走开就能躲。
## - 信号串色（SIGNAL_FRINGE）：身后叠一红一青两层错开 1 像素的剪影，像电视信号串色。单色屏幕里精英被映射成
##   和房间一样的色阶，老衣柜混进家具、水塔混进背景的水塔；红和青不在单色色阶里，哪种屏幕都分得出来。
##   作者不喜欢就把 SIGNAL_FRINGE 改成 false。
## 压迫感（10-18 作者："第三关的很多敌人尤其是精英怪，没有啥压迫感"）。预警时长一个都没缩短：
## - 不再"离近了往后退"：走得更快，贴到主角跟前 30~50 像素，追着打。
## - 跳砸、抛射的落点照主角现在的跑法预判一点（LEAD_TIME），落点标记就是预判后的位置，看到标记还是躲得开。
## - 扇射 3 颗 → 5 颗；抛射 2 颗 → 3 颗（预判点 + 两边各一颗夹住），落地烧一小块地（FireZone，1.6 秒）。
## - 血掉到一半狂暴：吼一声、震屏，之后出招间隔 ×0.6、走路和冲撞更快，身上冒火、红边一跳一跳。

enum { WALK, WARN, CHARGE, AIR, SHOOT, SUMMON, RECOVER }

## 2026-10-17 作者试玩：屏幕小、躲不开，所以预警拉长、冲撞变慢、子弹变少变慢、招与招之间歇得更久，离人太近会往后退
const WALK_SPEED := 34.0      # 10-18 压迫感：22 → 34
const CHARGE_SPEED := 140.0
const CHARGE_TIME := 0.9
const WARN_TIME := 0.85
const JUMP_VY := -320.0
const SHOCK_SPEED := 115.0
const BULLET_SPEED := 88.0
const MAX_SUMMONS := 2
## 和主角保持这个距离：近了退，远了走过去（10-18 压迫感：56~96 → 30~50，贴上来打）
const KEEP_NEAR := 30.0
const KEEP_FAR := 50.0
## 预判：落点按主角现在的水平速度再跑这么久来算，最多偏 LEAD_MAX
const LEAD_TIME := 0.45
const LEAD_MAX := 56.0
## 扇射几颗、隔多少度；抛射两边那两颗离中间多远
const SPRAY_SHOTS := 5
const SPRAY_STEP := 15.0
const VOLLEY_SIDE := 40.0
## 狂暴：血量低于这个比例；出招间隔、走路 / 冲撞速度的倍数
const RAGE_HP := 0.5
const RAGE_COOL := 0.6
const RAGE_SPEED := 1.3
const RAGE_CHARGE := 1.15
const COOLDOWN := Vector2(0.35, 0.7)  # 10-18 作者：招和招之间停太久
## 血量在 level3_mobs.gd（生成的，别手改）里，这里统一乘上去
const HP_MULT := 2.3  # 10-18 作者：血不够，三把武器 20～35 秒
## 信号串色：开关和两层的颜色（透明度不高，只是让剪影边上有一圈红 / 青）
const SIGNAL_FRINGE := true
const FRINGE_COLORS := [Color(1.0, 0.25, 0.3, 0.55), Color(0.2, 0.95, 1.0, 0.5)]
const FRINGE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
"""
static var _fringe_shader: Shader

var cfg: Dictionary = {}
var tint := "color"
var mob_name := ""

var _state := WALK
var _timer := 0.0
var _cool := 0.8           # 出场后第一招（10-18 压迫感：2.0 → 0.8）
var _move := ""
var _last_move := ""
var _bag: Array = []          # 这一副还没出的招
var _pattern := ""            # 正在放的招（预警到出完），招和招之间是空的；给 tools/qa/elite_regression.gd 分招数用
var _summons: Array[Node] = []
var _airborne := false
## 预警开始时锁定的目标（主角当时的脚底），跳砸、抛射照这个打
var _aim := Vector2.ZERO
var _tele: Node2D
## 前摇标记：冲撞路线的终点 x、落点（世界坐标）、扇射的出口和方向
var _tele_end_x := 0.0
var _tele_pts: Array[Vector2] = []
var _fringe: Array[Sprite2D] = []
var _rage := false
var _rage_fx: Node2D


func _setup() -> void:
	L3Mob.apply_cfg(self, cfg)
	elite_name = cfg.get("elite_name", "ELITE")
	intro_title = cfg.get("title", "")
	intro_frame = 5
	max_hp = cfg.get("hp", 900.0) * HP_MULT
	contact_damage = 12.0
	death_time = 1.1
	death_frame = 3
	hit_jolt = true
	warn_tint = false


func _after_ready() -> void:
	L3Mob.apply_look(self, tint)
	# 碎块用这块屏幕的色调（彩色屏幕用默认的暖灰）
	if L3Mob.RAMPS.has(tint):
		var r: Array = L3Mob.RAMPS[tint]
		death_colors = [r[1], r[2], r[3], r[4]]
	_tele = Node2D.new()
	_tele.top_level = true
	_tele.z_index = 8
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_tele.material = mat
	_tele.draw.connect(_draw_tele)
	add_child(_tele)
	_rage_fx = Node2D.new()
	_rage_fx.z_index = 7
	var rm := CanvasItemMaterial.new()
	rm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_rage_fx.material = rm
	_rage_fx.draw.connect(_draw_rage)
	add_child(_rage_fx)
	if SIGNAL_FRINGE:
		if _fringe_shader == null:
			_fringe_shader = Shader.new()
			_fringe_shader.code = FRINGE_SHADER
		for c in FRINGE_COLORS:
			var f := Sprite2D.new()
			f.texture = _sprite.texture
			f.hframes = hframes
			f.centered = false
			var fm := ShaderMaterial.new()
			fm.shader = _fringe_shader
			fm.set_shader_parameter("tint", c)
			f.material = fm
			add_child(f)
			move_child(f, _sprite.get_index())          # 放在贴图后面
			_fringe.append(f)


func _tick(delta: float) -> void:
	_timer -= delta
	_cool -= delta
	if not _rage and hp <= max_hp * RAGE_HP and not dying():
		_enrage()
	var p := nearest_player(420.0)
	match _state:
		WALK:
			velocity.x = 0.0
			if p:
				dir = 1 if p.global_position.x > global_position.x else -1
				var dist := absf(p.global_position.x - global_position.x)
				if dist > KEEP_FAR and ground_ahead(12.0) and not is_on_wall():
					velocity.x = dir * WALK_SPEED * speed_mult() * _rage_mult()
				elif dist < KEEP_NEAR:
					# 往后退，但脸还朝着人；背后没地方就站着
					dir = -dir
					if ground_ahead(12.0) and not is_on_wall():
						velocity.x = dir * WALK_SPEED * 0.8
					dir = -dir
			set_frame(int(_time / 0.25) % 2)
			if p and _cool <= 0.0 and is_on_floor():
				_pick_move()
				_state = WARN
				_timer = WARN_TIME
				velocity.x = 0.0
				warn(WARN_TIME)
				p = pick_focus(p)      # 双人时每招轮着盯一个人，预警开始就锁定
				dir = 1 if p.global_position.x > global_position.x else -1
				_aim = _lead(p) if _move == "slam" or _move == "volley" else p.global_position
				_plan_tele()
		WARN:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			set_frame(5 if _move == "summon" else 2)
			if _timer <= 0.0:
				_start_move(p)
		CHARGE:
			velocity.x = dir * CHARGE_SPEED * speed_mult() * (RAGE_CHARGE if _rage else 1.0)
			set_frame(3)
			if _timer <= 0.0 or is_on_wall() or not ground_ahead(16.0):
				velocity.x = 0.0
				Game.add_shake(3.0)
				_recover(1.0)
		AIR:
			set_frame(4)
			if is_on_floor() and _timer < 0.25:
				_land()
		SHOOT:
			set_frame(3)
			if _timer <= 0.0:
				_recover(0.5)
		SUMMON:
			set_frame(5)
			if _timer <= 0.0:
				_recover(0.6)
		RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			set_frame(0)
			if _timer <= 0.0:
				_state = WALK
				_cool = randf_range(COOLDOWN.x, COOLDOWN.y) * interval_mult() * (RAGE_COOL if _rage else 1.0)
	move_and_slide()
	_tele.queue_redraw()
	if _rage:
		_rage_fx.queue_redraw()
	_pattern = "" if _state == WALK or _state == RECOVER else _move


func _pick_move() -> void:
	var moves: Array = cfg.get("moves", ["charge"])
	_summons = _summons.filter(func(n): return is_instance_valid(n) and not n.get("dead"))
	# 10-18：抽签不放回（同 Boss1）。原来纯随机，某一招可能一辈子只放一两次
	if _bag.is_empty():
		_bag = moves.duplicate()
		_bag.shuffle()
		if _bag.size() > 1 and _bag.back() == _last_move:
			_bag.reverse()
	var pick: String = _bag.pop_back()
	# 小怪已经召满了：这张先放回去垫底，换下一张
	if pick == "summon" and _summons.size() >= MAX_SUMMONS:
		var other := _bag.filter(func(m): return m != "summon")
		if other.is_empty():
			other = moves.filter(func(m): return m != "summon" and m != _last_move)
		if other.is_empty():
			other = moves.filter(func(m): return m != "summon")
		if other.is_empty():
			other = ["charge"]
		_bag.erase(other[0])
		_bag.push_front(pick)
		pick = other[0]
	_move = pick
	_last_move = _move


func _start_move(p: Player) -> void:
	match _move:
		"charge":
			_state = CHARGE
			_timer = CHARGE_TIME
			Game.sfx("crack", -10.0, 1.2, 0.05)
		"slam":
			var dx := _aim.x - global_position.x
			velocity = Vector2(clampf(dx / 0.9, -150.0, 150.0), JUMP_VY)
			_state = AIR
			_timer = 0.6
		"spray":
			for i in SPRAY_SHOTS:
				var aim := _spray_dir(i)
				_shoot_at(aim_point() + aim * 100.0)
			_state = SHOOT
			_timer = 0.4
		"volley":
			# 预判点一颗，两边各一颗夹住；落地都烧一小块地
			for x in _volley_offsets():
				var b := _shoot_at(_aim + Vector2(x, 0))
				var z := FireZone.new()
				z.bullet = b
				z.arena = L3Mob.arena
				get_parent().add_child(z)
			_state = SHOOT
			_timer = 0.4
		"summon":
			_summon()
			_state = SUMMON
			_timer = 0.5
		_:
			_recover(0.3)


func _shoot_at(target: Vector2) -> BossBullet:
	var from := aim_point() + Vector2(dir * frame_size.x * 0.3, -4)
	var kind: String = cfg.get("bullet", "rivet")
	if _move == "spray":
		kind = "rivet"
	elif _move == "volley" and kind == "rivet":
		kind = "ember"
	Game.sfx("hit", -12.0, 1.2, 0.1)
	return L3Mob.fire(get_parent(), kind, from, target, BULLET_SPEED)


func _spray_dir(i: int) -> Vector2:
	var a := deg_to_rad((i - (SPRAY_SHOTS - 1) / 2.0) * SPRAY_STEP)
	return Vector2(dir, 0).rotated(a * dir)


func _volley_offsets() -> Array[float]:
	return [-VOLLEY_SIDE, 0.0, VOLLEY_SIDE]


## 预判：主角照现在的水平速度再跑 LEAD_TIME 秒会在哪（只预判一点，最多偏 LEAD_MAX）
func _lead(p: Player) -> Vector2:
	return p.global_position + Vector2(clampf(p.velocity.x * LEAD_TIME, -LEAD_MAX, LEAD_MAX), 0)


func _rage_mult() -> float:
	return RAGE_SPEED if _rage else 1.0


## 血掉到一半：吼一声、震屏、冒一圈火花，之后一直冒火
func _enrage() -> void:
	_rage = true
	Game.add_shake(6.0)
	Game.sfx("jet", -4.0, 0.55)
	Game.sfx("crack", -6.0, 0.7)
	Game.sparks(get_parent(), aim_point(), EnemyBase.LED_HOT, 16, 120.0)
	_flash = 1.0


func _land() -> void:
	Game.add_shake(5.0)
	Game.sfx("land", -6.0, 0.7)
	Game.dust(get_parent(), global_position, 8)
	for s in [-1, 1]:
		var b := BossBullet.spawn(get_parent(), BossBullet.Kind.RIVET, global_position + Vector2(s * 10, -4), Vector2(s * SHOCK_SPEED, 0))
		b.arena = L3Mob.arena
		b.crt = true
	velocity.x = 0.0
	_recover(0.9)


func _summon() -> void:
	var smalls := L3Mob.smalls(cfg.get("scene", ""))
	if smalls.is_empty():
		return
	# 只叫一只，落在自己背后（离人远的那边）
	for s in [-dir]:
		var m := L3Mob.make(smalls[randi() % smalls.size()], tint)
		m.position = global_position + Vector2(s * 24, -frame_size.y * 0.5)
		get_parent().add_child(m)
		_summons.append(m)
		Game.sparks(get_parent(), m.position, Color8(255, 190, 120), 8, 70.0)
	Game.sfx("scrap", -8.0, 1.4)


## 预警开始时把这一招会打到哪里算好，画成标记
func _plan_tele() -> void:
	_tele_pts.clear()
	var space := get_world_2d().direct_space_state
	match _move:
		"charge":
			# 冲过去最远到哪：冲撞距离以内，撞墙停
			var reach := CHARGE_SPEED * speed_mult() * (RAGE_CHARGE if _rage else 1.0) * CHARGE_TIME
			var from := global_position + Vector2(0, -6)
			var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * (reach + body_rect.size.x / 2.0), 0), 1)
			q.exclude = [get_rid()]
			var hit := space.intersect_ray(q)
			_tele_end_x = (hit["position"] as Vector2).x - dir * body_rect.size.x / 2.0 if not hit.is_empty() else global_position.x + dir * reach
		"slam":
			# 起跳速度和 _start_move 一样；重力 900，落回同一高度要 2×320/900 秒
			var vx := clampf((_aim.x - global_position.x) / 0.9, -150.0, 150.0)
			_tele_pts.append(_ground_below(Vector2(global_position.x + vx * 2.0 * -JUMP_VY / gravity, global_position.y)))
		"volley":
			for x in _volley_offsets():
				_tele_pts.append(_ground_below(_aim + Vector2(x, 0)))


func _ground_below(p: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(p + Vector2(0, -40), p + Vector2(0, 80), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return ((hit["position"] as Vector2) if not hit.is_empty() else p).round()


## 前摇标记：预警期间画（一闪一闪，最后 0.25 秒常亮）。红色不吃第三关的色调映射，哪种屏幕都看得见
func _draw_tele() -> void:
	if _state != WARN or dead or dying():
		return
	var red := EnemyBase.LED_COLOR
	var on := _timer < 0.25 or int(_timer * 10.0) % 2 == 0
	var col := Color(red, 0.85 if on else 0.4)
	match _move:
		"charge":
			# 路线：贴地一串往前指的小箭头，终点一道竖线
			var y := roundf(global_position.y) - 1.0
			var x0 := roundf(global_position.x + dir * (body_rect.size.x / 2.0 + 4.0))
			var x1 := roundf(_tele_end_x)
			var x := x0
			while (x1 - x) * dir > 0.0:
				_tele.draw_rect(Rect2(x, y, 1, 1), col)
				_tele.draw_rect(Rect2(x - dir, y - 1, 1, 1), col)
				_tele.draw_rect(Rect2(x - dir, y + 1, 1, 1), col)
				x += dir * 8.0
			_tele.draw_rect(Rect2(x1, y - 8, 1, 8), col)
		"slam", "volley":
			for p in _tele_pts:
				_tele.draw_rect(Rect2(p + Vector2(-5, -1), Vector2(11, 1)), col)
				_tele.draw_rect(Rect2(p + Vector2(-5, -3), Vector2(1, 2)), col)
				_tele.draw_rect(Rect2(p + Vector2(5, -3), Vector2(1, 2)), col)
				var bob := float(int(_timer * 6.0) % 2)
				for i in 3:
					_tele.draw_rect(Rect2(p + Vector2(-i, -8 + i + bob), Vector2(i * 2 + 1, 1)), col)
		"spray":
			var from := aim_point() + Vector2(dir * frame_size.x * 0.3, -4)
			for i in SPRAY_SHOTS:
				var v := _spray_dir(i)
				for k in range(2, 9):
					_tele.draw_rect(Rect2((from + v * k * 5.0).round(), Vector2.ONE), col)


## 预警：整只一闪一闪发白（第三关的着色器把颜色映射成单色，发红看不出来；白闪在映射之后叠，哪种屏幕都看得见）
func _update_visual() -> void:
	super._update_visual()
	# 信号串色：红的往左错一格、青的往右错一格，跟着贴图换帧、翻转
	for i in _fringe.size():
		var f := _fringe[i]
		f.visible = _sprite.visible
		f.frame = _sprite.frame
		f.flip_h = _sprite.flip_h
		f.offset = _sprite.offset
		f.position = _sprite.position + Vector2(-1.0 if i == 0 else 1.0, 0)
		if _rage and not dead:
			# 狂暴：两层都变红，一跳一跳
			var c: Color = FRINGE_COLORS[0]
			c.a = 0.55 + 0.4 * (0.5 + 0.5 * sin(_time * 9.0))
			(f.material as ShaderMaterial).set_shader_parameter("tint", c)
	if _state == WARN and not dead and not dying():
		var k := clampf(1.0 - _timer / WARN_TIME, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(_time * (14.0 + 26.0 * k))
		var mat := _sprite.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("flash", maxf(_flash, pulse * (0.25 + 0.35 * k)))


func _recover(t: float) -> void:
	_state = RECOVER
	_timer = t


## 狂暴时身上冒火：贴图上沿一排 1 像素的火苗往上窜，红 / 橙 / 黄，不吃色调映射
func _draw_rage() -> void:
	if not _rage or dead or dying():
		return
	var top := -float(body_rect.size.y) - 1.0
	var w := int(body_rect.size.x)
	var x0 := int(body_rect.position.x)
	var cols := [EnemyBase.LED_COLOR, EnemyBase.LED_HOT, Color(1.0, 0.8, 0.35)]
	var tick := int(_time * 12.0)
	for i in range(0, w, 3):
		var h := (tick * 7 + i * 13) % 6
		var base := Vector2(x0 + i + (tick + i) % 2, top + 2)
		for k in h:
			var c: Color = cols[mini(k * 3 / maxi(h, 1), 2)]
			c.a = 0.9 - 0.12 * k
			_rage_fx.draw_rect(Rect2(base + Vector2(0, -k), Vector2.ONE), c)
	# 两侧往上飘的火星
	for j in 3:
		var t := fmod(_time * 1.3 + j * 0.37, 1.0)
		var sx := x0 + (j * 17 + int(_time * 3.0) * 5) % maxi(w, 1)
		_rage_fx.draw_rect(Rect2(Vector2(sx, top - 4.0 - t * 14.0).round(), Vector2.ONE), Color(EnemyBase.LED_HOT, 1.0 - t))


## 抛射弹落地后烧的一小块地：跟着子弹，子弹没了（落地、打中人）就在那儿贴地烧 LIFE 秒，站在上面挨烫
class FireZone extends Node2D:
	const LIFE := 1.6
	const HALF := 12.0
	const HEIGHT := 10.0
	const DAMAGE := 8.0
	var bullet: BossBullet
	var arena := Rect2()
	var _last := Vector2.ZERO
	var _t := -1.0

	func _ready() -> void:
		z_index = 6
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
		if is_instance_valid(bullet):
			_last = bullet.global_position

	func _physics_process(delta: float) -> void:
		if _t < 0.0:
			if is_instance_valid(bullet):
				_last = bullet.global_position
				return
			# 子弹飞出场子就不烧
			if arena.size != Vector2.ZERO and not arena.has_point(_last):
				queue_free()
				return
			var q := PhysicsRayQueryParameters2D.create(_last + Vector2(0, -6), _last + Vector2(0, 40), 1)
			var hit := get_world_2d().direct_space_state.intersect_ray(q)
			if hit.is_empty():
				queue_free()
				return
			global_position = (hit["position"] as Vector2).round()
			_t = 0.0
			Game.sfx("vent", -14.0, 1.8, 0.1)
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		for n in get_tree().get_nodes_in_group("player"):
			var p := n as Player
			if p and absf(p.global_position.x - global_position.x) <= HALF and absf(p.global_position.y - global_position.y) <= HEIGHT:
				p.hurt(global_position, DAMAGE * EnemyBase.damage_mult())
		queue_redraw()

	func _draw() -> void:
		if _t < 0.0:
			return
		var fade := 1.0 - maxf(0.0, _t - (LIFE - 0.4)) / 0.4
		var tick := int(_t * 14.0)
		var cols := [EnemyBase.LED_COLOR, EnemyBase.LED_HOT, Color(1.0, 0.8, 0.35)]
		# 贴地两行烧红的底，上面一列列火苗一窜一窜（1 像素一列，最高 7 格）
		draw_rect(Rect2(-HALF, -1, HALF * 2.0 + 1.0, 1), Color(EnemyBase.LED_COLOR, 0.9 * fade))
		draw_rect(Rect2(-HALF + 1.0, -2, HALF * 2.0 - 1.0, 1), Color(EnemyBase.LED_HOT, 0.8 * fade))
		for i in range(-int(HALF) + 1, int(HALF)):
			var edge := 1.0 - absf(i) / HALF
			var h := int(((tick * 5 + i * 7 + 40) % 5 + 3) * (0.4 + 0.6 * edge))
			for k in h:
				var c: Color = cols[mini(k * 3 / maxi(h, 1), 2)]
				c.a = (0.95 - 0.1 * k) * fade
				draw_rect(Rect2(i, -3 - k, 1, 1), c)
