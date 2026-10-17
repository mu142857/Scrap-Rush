class_name L3Elite
extends EliteBase
## 第三关的精英怪（每种屏幕场景一只：老冰箱、电视壳大寄居蟹……）。贴图和招式都在 cfg 里（见 L3Mob）。
## 平时慢慢走向主角，隔一会儿从 cfg["moves"] 里挑一招，出招前头顶冒红色"!"：
##   charge  横冲过场子，撞到墙或走到台子边停下
##   slam    高高跳向主角，落地往两边贴地打出两颗铆钉（冲击波）
##   spray   扇形打出 5 颗直线弹
##   volley  朝主角抛 3 颗抛物线弹（远近不一）
##   summon  叫出 2 只本场景的小怪（场上最多 3 只叫出来的）
## 帧：0 待机、1 走、2 蓄力、3 出招、4 空中、5 亮相（出场动画和叫小怪时用）。

enum { WALK, WARN, CHARGE, AIR, SHOOT, SUMMON, RECOVER }

const WALK_SPEED := 24.0
const CHARGE_SPEED := 175.0
const CHARGE_TIME := 1.1
const WARN_TIME := 0.6
const JUMP_VY := -330.0
const SHOCK_SPEED := 150.0
const BULLET_SPEED := 120.0
const MAX_SUMMONS := 3

var cfg: Dictionary = {}
var tint := "color"
var mob_name := ""

var _state := WALK
var _timer := 0.0
var _cool := 1.2
var _move := ""
var _last_move := ""
var _summons: Array[Node] = []
var _airborne := false


func _setup() -> void:
	L3Mob.apply_cfg(self, cfg)
	elite_name = cfg.get("elite_name", "ELITE")
	intro_title = cfg.get("title", "")
	intro_frame = 5
	max_hp = cfg.get("hp", 900.0)
	contact_damage = 12.0


func _after_ready() -> void:
	L3Mob.apply_look(self, tint)


func _tick(delta: float) -> void:
	_timer -= delta
	_cool -= delta
	var p := nearest_player(420.0)
	match _state:
		WALK:
			if p:
				dir = 1 if p.global_position.x > global_position.x else -1
				if absf(p.global_position.x - global_position.x) > 30.0 and ground_ahead(12.0) and not is_on_wall():
					velocity.x = dir * WALK_SPEED * speed_mult()
				else:
					velocity.x = 0.0
			else:
				velocity.x = 0.0
			set_frame(int(_time / 0.25) % 2)
			if p and _cool <= 0.0 and is_on_floor():
				_pick_move()
				_state = WARN
				_timer = WARN_TIME
				velocity.x = 0.0
				warn(WARN_TIME)
		WARN:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			set_frame(5 if _move == "summon" else 2)
			if _timer <= 0.0:
				_start_move(p)
		CHARGE:
			velocity.x = dir * CHARGE_SPEED * speed_mult()
			set_frame(3)
			if _timer <= 0.0 or is_on_wall() or not ground_ahead(16.0):
				velocity.x = 0.0
				Game.add_shake(3.0)
				_recover(0.8)
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
				_cool = randf_range(1.0, 1.8) * interval_mult()
	move_and_slide()


func _pick_move() -> void:
	var moves: Array = cfg.get("moves", ["charge"])
	_summons = _summons.filter(func(n): return is_instance_valid(n) and not n.get("dead"))
	var choices := moves.filter(func(m): return m != _last_move and not (m == "summon" and _summons.size() >= MAX_SUMMONS))
	if choices.is_empty():
		choices = moves.filter(func(m): return m != "summon")
	if choices.is_empty():
		choices = ["charge"]
	_move = choices[randi() % choices.size()]
	_last_move = _move


func _start_move(p: Player) -> void:
	match _move:
		"charge":
			_state = CHARGE
			_timer = CHARGE_TIME
			Game.sfx("crack", -10.0, 1.2, 0.05)
		"slam":
			var dx := 0.0 if p == null else p.global_position.x - global_position.x
			velocity = Vector2(clampf(dx / 0.9, -150.0, 150.0), JUMP_VY)
			_state = AIR
			_timer = 0.6
		"spray":
			for i in 5:
				var a := deg_to_rad(-30.0 + i * 15.0)
				var aim := Vector2(dir, 0).rotated(a * dir)
				_shoot_at(aim_point() + aim * 100.0)
			_state = SHOOT
			_timer = 0.4
		"volley":
			var target := global_position + Vector2(dir * 80, 0) if p == null else p.global_position
			for i in 3:
				_shoot_at(target + Vector2((i - 1) * 26.0, 0))
			_state = SHOOT
			_timer = 0.4
		"summon":
			_summon()
			_state = SUMMON
			_timer = 0.5
		_:
			_recover(0.3)


func _shoot_at(target: Vector2) -> void:
	var from := aim_point() + Vector2(dir * frame_size.x * 0.3, -4)
	var kind: String = cfg.get("bullet", "rivet")
	if _move == "spray":
		kind = "rivet"
	elif _move == "volley" and kind == "rivet":
		kind = "ember"
	L3Mob.fire(get_parent(), kind, from, target, BULLET_SPEED)
	Game.sfx("hit", -12.0, 1.2, 0.1)


func _land() -> void:
	Game.add_shake(5.0)
	Game.sfx("land", -6.0, 0.7)
	Game.dust(get_parent(), global_position, 8)
	for s in [-1, 1]:
		var b := BossBullet.spawn(get_parent(), BossBullet.Kind.RIVET, global_position + Vector2(s * 10, -4), Vector2(s * SHOCK_SPEED, 0))
		b.arena = L3Mob.arena
	velocity.x = 0.0
	_recover(0.9)


func _summon() -> void:
	var smalls := L3Mob.smalls(cfg.get("scene", ""))
	if smalls.is_empty():
		return
	for s in [-1, 1]:
		var m := L3Mob.make(smalls[randi() % smalls.size()], tint)
		m.position = global_position + Vector2(s * 24, -frame_size.y * 0.5)
		get_parent().add_child(m)
		_summons.append(m)
		Game.sparks(get_parent(), m.position, Color8(255, 190, 120), 8, 70.0)
	Game.sfx("scrap", -8.0, 1.4)


func _recover(t: float) -> void:
	_state = RECOVER
	_timer = t
