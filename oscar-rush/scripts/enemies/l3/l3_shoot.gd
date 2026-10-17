class_name L3Shoot
extends EnemyBase
## 第三关的射击小怪（咖啡壶、收音机……）：慢慢来回走，看到人就停下、转过去瞄准（枪口发亮那么久），
## 然后开一枪：rivet 直线、ember / note 抛物线。打完歇一会儿再走。
## 帧：0、1 走路，2 瞄准，3 开火（后坐）。贴图、枪口、子弹种类都在 cfg 里（见 L3Mob）。

enum { PATROL, AIM, FIRE, REST }

const WALK_SPEED := 16.0
const SEE_DIST := 150.0
const SEE_HEIGHT := 70.0
const AIM_TIME := 0.9
const FIRE_TIME := 0.25
const REST_TIME := 2.6
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
	max_hp = 100.0
	contact_damage = 8.0


func _after_ready() -> void:
	L3Mob.apply_look(self, tint)
	_cool = randf_range(0.5, 1.5)


func _tick(delta: float) -> void:
	_timer -= delta
	_cool -= delta
	match _state:
		PATROL:
			if is_on_wall() or (is_on_floor() and not ground_ahead(6.0)):
				dir = -dir
			velocity.x = dir * WALK_SPEED * speed_mult()
			set_frame(int(_time / STEP_TIME) % 2)
			_target = nearest_player(SEE_DIST)
			if _target and _cool <= 0.0 and absf(_target.global_position.y - global_position.y) < SEE_HEIGHT:
				dir = 1 if _target.global_position.x > global_position.x else -1
				_state = AIM
				_timer = AIM_TIME
				velocity.x = 0.0
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


func _fire() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var mz: Vector2i = cfg.get("muzzle", Vector2i(-1, -1))
	var from := L3Mob.pixel_world(self, mz) if mz.x >= 0 else aim_point()
	L3Mob.fire(get_parent(), cfg.get("bullet", "rivet"), from, _target.global_position + Vector2(0, -6), BULLET_SPEED)
	Game.sfx("hit", -14.0, 1.6, 0.1)
