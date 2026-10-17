class_name CrankPhone
extends EnemyBase
## 手摇电话（策划案第九节 15，"放哨的"）：平时混在地上装死，不动，红灯不亮。
## 主角走近 60 像素以内或者打它一下，它就"铃——"地响，然后往远离主角的方向躲。
## 每响一次，在它身边的天花板上掉下一只爬虫或扑灯蛾（它叫来的同时最多 2 只）；
## 叫来的怪算进它所在的遭遇战，要打死才算清场。不先打掉它，每 5 秒（乘 interval_mult）再响一次。
## 帧：0 装死（灯不亮）、1、2 走路、3、4 铃响（铃抖、摇把转）。贴图由 草图/小怪/export_wire_fuse_phone.py 导出。

enum { DORMANT, RING, AWAKE }

const WAKE_DIST := 60.0
const RING_TIME := 0.7
const RING_INTERVAL := 5.0
const FLEE_SPEED := 38.0
## 主角水平离它这么近就躲
const FLEE_DIST := 90.0
const WALK_FRAME_TIME := 0.12
const MAX_CALLED := 2
const CALL_KINDS := ["crawler", "moth"]
## 叫来的怪：天花板上先冒火花、响一声，过这么久才掉下来（和遭遇战一样）
const DROP_WARN := 0.45
const CEIL_SEARCH := 220.0

var _state := DORMANT
var _timer := 0.0
var _ring_t := 0.0
## 叫来的怪（活着的）和还没掉下来的：{kind, pos, t}
var _called: Array[Node] = []
var _pending: Array = []


func _setup() -> void:
	texture_path = "res://art/enemies/phone.png"
	hframes = 5
	frame_size = Vector2i(18, 22)
	body_rect = Rect2(-5, -18, 10, 18)
	led_pixel = Vector2i(8, 7)
	led_by_frame = {0: Vector2i(-1, -1)}
	max_hp = 100.0
	contact_damage = 10.0


func _tick(delta: float) -> void:
	_timer -= delta
	_tick_pending(delta)
	match _state:
		DORMANT:
			_brake(delta)
			set_frame(0)
			if nearest_player(WAKE_DIST) != null:
				_ring()
		RING:
			_ring_t -= delta
			_brake(delta)
			set_frame(3 + int(_timer / 0.06) % 2)
			if _timer <= 0.0:
				_state = AWAKE
		AWAKE:
			_ring_t -= delta
			_flee(delta)
			if _ring_t <= 0.0:
				_ring()
	move_and_slide()


func _ring() -> void:
	_state = RING
	_timer = RING_TIME
	# 从这一声响起开始算下一声
	_ring_t = RING_INTERVAL * interval_mult()
	Game.sfx("bell", -6.0, 1.0, 0.05)
	Game.add_shake(1.0)
	_call_help()


## 躲开主角：主角在 90 像素以内就往反方向走，走到墙或台子边就停住；远了就站着盯着它
func _flee(delta: float) -> void:
	var p := nearest_player()
	var dx := INF if p == null else p.global_position.x - global_position.x
	if absf(dx) <= FLEE_DIST:
		dir = -1 if dx > 0.0 else 1
		var blocked := is_on_wall() or not ground_ahead()
		if not is_knocked():
			velocity.x = 0.0 if blocked else dir * FLEE_SPEED * speed_mult()
	else:
		if p != null and absf(dx) > 1.0:
			dir = 1 if dx > 0.0 else -1
		_brake(delta)
	if absf(velocity.x) > 2.0:
		set_frame(1 + int(_time / WALK_FRAME_TIME) % 2)
	else:
		set_frame(1)


func _brake(delta: float) -> void:
	if not is_knocked():
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)


## 在身边的天花板上叫一只怪下来（叫来的同时最多 2 只）
func _call_help() -> void:
	_called.assign(_called.filter(func(e): return is_instance_valid(e) and not e.get("dead")))
	if _called.size() + _pending.size() >= MAX_CALLED:
		return
	var spot := _drop_spot()
	if spot == Vector2.INF:
		return
	_pending.append({"kind": CALL_KINDS[randi() % CALL_KINDS.size()], "pos": spot, "t": 0.0})
	Game.sparks(get_parent(), spot + Vector2(0, -12), Color8(255, 190, 120), 6, 60.0, Vector2.DOWN)
	Game.sfx("scrap", -16.0, 1.7, 0.1)


## 落点：身边左右 14～30 像素、中间没有墙（闸门）的地方，往上找天花板，落在天花板下 14 像素
func _drop_spot() -> Vector2:
	var space := get_world_2d().direct_space_state
	var offsets := [16.0, 28.0, -16.0, -28.0, 0.0]
	offsets.shuffle()
	offsets.erase(0.0)
	offsets.append(0.0)
	var mid := global_position + Vector2(0, -10)
	for o in offsets:
		var side := mid + Vector2(o, 0)
		if o != 0.0 and not space.intersect_ray(PhysicsRayQueryParameters2D.create(mid, side, 1)).is_empty():
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(side, side + Vector2(0, -CEIL_SEARCH), 1))
		if hit.is_empty():
			continue
		return Vector2(side.x, (hit["position"] as Vector2).y + 14.0)
	return Vector2.INF


func _tick_pending(delta: float) -> void:
	for q in _pending.duplicate():
		q["t"] += delta
		if q["t"] < DROP_WARN:
			continue
		_pending.erase(q)
		var e := _spawn(q["kind"], q["pos"])
		if e:
			_called.append(e)


## 生成叫来的怪：加进关卡；父节点里有遭遇战就算进它的 _alive，打死才清场
func _spawn(kind: String, pos: Vector2) -> Node2D:
	var path: String = Encounter.TYPES.get(kind, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	var e: Node2D = (load(path) as GDScript).new()
	e.set("respawn_time", 0.0)
	e.position = pos
	get_parent().add_child(e)
	var enc := _my_encounter()
	if enc:
		enc._alive.append(e)
	return e


## 自己所在的遭遇战：先找 _alive 里有自己的；没有就找正在打、场子罩住自己的
func _my_encounter() -> Encounter:
	var parent := get_parent()
	if parent == null:
		return null
	var fallback: Encounter = null
	for c in parent.get_children():
		var enc := c as Encounter
		if enc == null:
			continue
		if enc._alive.has(self):
			return enc
		if enc.started and not enc.cleared and global_position.x >= enc.left and global_position.x <= enc.right:
			fallback = enc
	return fallback


func _on_hurt(_damage: float, _full: bool) -> void:
	if _state == DORMANT:
		_ring()


func _on_die() -> void:
	# 还没掉下来的就不来了
	_pending.clear()


func _on_respawn() -> void:
	_state = DORMANT
	_pending.clear()
