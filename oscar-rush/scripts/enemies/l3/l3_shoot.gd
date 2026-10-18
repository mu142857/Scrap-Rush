class_name L3Shoot
extends EnemyBase
## 第三关的射击小怪（咖啡壶、收音机……）：慢慢来回走，看到人就停下、转过去瞄准（枪口发亮那么久），
## 然后开一枪：rivet 直线、ember / note 抛物线。打完歇一会儿再走。
## 帧：0、1 走路，2 瞄准，3 开火（后坐）。贴图、枪口、子弹种类都在 cfg 里（见 L3Mob）。

enum { PATROL, AIM, FIRE, REST }

## 2026-10-18 作者试玩"没有压迫感"：看得更远（整块屏幕）、瞄得快一点、两枪之间短一点（2.6 → 1.6 秒），
## 看到人以后不再来回乱走，而是保持一个开枪的距离（离太近往后退，太远往前凑）
const WALK_SPEED := 16.0
const KEEP_SPEED := 26.0
const SEE_DIST := 260.0
const SEE_HEIGHT := 70.0
## 想和人保持的水平距离
const KEEP_NEAR := 70.0
const KEEP_FAR := 130.0
const AIM_TIME := 0.7
const FIRE_TIME := 0.25
const REST_TIME := 1.6
const STEP_TIME := 0.22
const BULLET_SPEED := 85.0

var cfg: Dictionary = {}
var tint := "color"
var mob_name := ""

var _state := PATROL
var _timer := 0.0
var _cool := 0.0
var _target: Player = null


func _setup() -> void:
	L3Mob.apply_cfg(self, cfg)
	contact_damage = 8.0


func _after_ready() -> void:
	L3Mob.apply_look(self, tint)
	_cool = randf_range(0.5, 1.5)
	# 夜间打磨：挨打顿一格、死时抖一下碎几块（见 elite_fx.gd，和第二关的小怪一样）
	EliteFx.attach_small(self, 6)


func _tick(delta: float) -> void:
	_timer -= delta
	_cool -= delta
	match _state:
		PATROL:
			_target = nearest_player(SEE_DIST)
			if _target and absf(_target.global_position.y - global_position.y) < SEE_HEIGHT:
				_keep_range()
			else:
				if is_on_wall() or (is_on_floor() and not ground_ahead(6.0)):
					dir = -dir
				velocity.x = dir * WALK_SPEED * speed_mult()
			set_frame(int(_time / STEP_TIME) % 2 if absf(velocity.x) > 2.0 else 0)
			if _target and _cool <= 0.0 and absf(_target.global_position.y - global_position.y) < SEE_HEIGHT:
				dir = 1 if _target.global_position.x > global_position.x else -1
				_state = AIM
				_timer = AIM_TIME
				velocity.x = 0.0
				EliteFx.mark(self, AIM_TIME)
		AIM:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			set_frame(2)
			if _timer <= 0.0:
				_fire()
				_state = FIRE
				_timer = FIRE_TIME
		FIRE:
			set_frame(3)
			if _timer <= 0.0:
				_state = REST
				_timer = 0.3
		REST:
			set_frame(0)
			if _timer <= 0.0:
				_state = PATROL
				_cool = REST_TIME * interval_mult()
	if is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	move_and_slide()


## 看到人、还在冷却：脸一直朝着人，离太近往后退、太远往前凑；脚下没地或撞墙就站住
func _keep_range() -> void:
	var dx := _target.global_position.x - global_position.x
	var face := 1 if dx > 0.0 else -1
	var move := 0.0
	if absf(dx) < KEEP_NEAR:
		move = -face
	elif absf(dx) > KEEP_FAR:
		move = face
	dir = face
	if move != 0.0:
		var from := global_position + Vector2(move * 8.0, -2)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), 1)
		if get_world_2d().direct_space_state.intersect_ray(q).is_empty() or (is_on_wall() and signf(get_wall_normal().x) != move):
			move = 0.0
	velocity.x = move_toward(velocity.x, move * KEEP_SPEED * speed_mult(), 300.0 * get_physics_process_delta_time())


func _fire() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var mz: Vector2i = cfg.get("muzzle", Vector2i(-1, -1))
	var from := L3Mob.pixel_world(self, mz) if mz.x >= 0 else aim_point()
	L3Mob.fire(get_parent(), cfg.get("bullet", "rivet"), from, _target.global_position + Vector2(0, -6), BULLET_SPEED)
	Game.sfx("hit", -14.0, 1.6, 0.1)
