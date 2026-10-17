class_name Encounter
extends Node2D
## 遭遇战（策划案第九节，照 Phage 的 back_alley_ambush.gd）：
## 主角走进场子中间 → 两边的废铁闸门砸下来锁住 → 怪一波一波从天花板的管子里掉下来
## （每只先在落点冒火花、响一声，0.45 秒后才掉，不会凭空砸在人头上）→ 一波死光，歇一下来下一波
## → 最后一波打完，闸门升起，场子中间掉 1 个零件。
## 每场最后一波放一个精英怪（种类名在 ELITES 里）；脚本还没写好的种类自动跳过。
## 打完一场就是一个存档点（Run.save_checkpoint）：马灯碎了或按 R，重载整个场景，人站回最近打完那场的出口一侧，
## 存档点之前打完的遭遇战直接是打完的样子（闸门不落、不再掉零件），会照常发 finished（比如第一关的桥照样伸出来）。
## 用法：new() 以后填 left/right/ceil_y/floor_left/floor_right/waves/hazards，再 add_child 进关卡。

## 打完（闸门升起的那一刻）发出
signal finished

## 怪的种类 → 脚本。脚本文件不存在的种类自动跳过
const TYPES := {
	"crawler": "res://scripts/enemies/crawler.gd",
	"moth": "res://scripts/enemies/moth.gd",
	"kettle": "res://scripts/enemies/kettle.gd",
	"shaver": "res://scripts/enemies/shaver.gd",
	"flea": "res://scripts/enemies/flea.gd",
	# 精英怪
	"cuckoo": "res://scripts/enemies/cuckoo.gd",
	"sewing": "res://scripts/enemies/sewing.gd",
	"register": "res://scripts/enemies/register.gd",
	"piano": "res://scripts/enemies/piano.gd",
	"vacuum": "res://scripts/enemies/vacuum.gd",
	"roller": "res://scripts/enemies/roller.gd",
	# 第二关（"声音"：电话交换局 + 老电影院）的小怪
	"wire_snake": "res://scripts/enemies/wire_snake.gd",
	"fuse": "res://scripts/enemies/fuse_beetle.gd",
	"phone": "res://scripts/enemies/phone.gd",
	"scavenger": "res://scripts/enemies/scavenger.gd",
	"slide": "res://scripts/enemies/slide_projector.gd",
	"reel": "res://scripts/enemies/film_reel.gd",
	# 第二关的精英怪
	"switchboard": "res://scripts/enemies/switchboard.gd",
	"gramophone": "res://scripts/enemies/gramophone.gd",
	"projector": "res://scripts/enemies/projector.gd",
}
## 精英怪：登场情绪 +10（策划案第八节）；落在场子里离主角远的那一头，预警更久、火花更大
const ELITES := ["cuckoo", "sewing", "register", "piano", "vacuum", "roller", "switchboard", "gramophone", "projector"]
const ELITE_WARN_TIME := 1.0
## 打完一场马灯回这么多血
const CLEAR_HEAL := 12.0
const WARN_TIME := 0.45
const WAVE_GAP := 0.8
const GATE_W := 8.0
const SLAM_TIME := 0.12
const RISE_TIME := 0.6
const LABEL_COLOR := Color8(255, 211, 138)

## 场子左右边界（闸门的位置）、天花板的 y、两扇闸门脚下地面的 y
var left := 0.0
var right := 0.0
var ceil_y := 0.0
var floor_left := 0.0
var floor_right := 0.0
## 每一波是一组种类名，比如 [["crawler", "shaver"], ["moth", "moth"]]
var waves: Array = []
## 场子里一开始就摆好的机关（比如汽壶），[种类名, 位置]；不算在"清场"里
var hazards: Array = []

var started := false
var cleared := false
## 可选：自定义某种怪怎么出场（比如压路机坐在伸出来的桥上开出来）。
## 签名 func(kind: String, x: float) -> Node2D：返回怪（自己负责加进场景）就用它，返回 null 走默认的从天花板掉下来。
var spawn_hook: Callable

var _wave := -1
var _alive: Array[Node] = []
## 还没落下来的怪：{kind, x, t}；t 从负的延迟往上数，到 0 冒预警火花，到 WARN_TIME 落下。
## 不用 await：关卡重载时协程会醒在已经释放的节点上
var _queue: Array = []
var _gap := 0.0
var _gates: Array[Gate] = []
var _label: Label
var _label_t := 0.0
## 进场时主角在场子哪一边：打完后存档点放在另一边（出口那侧）
var _entered_left := true
var _key := ""


func _ready() -> void:
	for h in hazards:
		var e := _make(h[0])
		if e:
			e.position = h[1]
			get_parent().add_child.call_deferred(e)
	_gates.append(_add_gate(left, floor_left))
	_gates.append(_add_gate(right, floor_right))
	_key = "%d:%d:%d" % [roundi(left), roundi(right), roundi(ceil_y)]
	if Run.is_cleared(_key):
		started = true
		cleared = true
		finished.emit.call_deferred()

	_label = Label.new()
	_label.label_settings = Hud.small_text(LABEL_COLOR)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(120, 12)
	# 字放在地面上方 72 像素（不低于天花板）：镜头放大 2 倍时只看得到地面上方约 100 像素，
	# 原来挂在天花板下面，上层场子的天花板在画面外，AMBUSH / CLEAR 根本看不到
	_label.position = Vector2((left + right) / 2.0 - 60.0, maxf(ceil_y + 6.0, minf(floor_left, floor_right) - 72.0))
	_label.visible = false
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_label.material = unshaded
	_label.z_index = 20
	add_child(_label)


func _physics_process(delta: float) -> void:
	_tick_label(delta)
	if cleared:
		return
	if not started:
		if _player_inside():
			_start()
		return
	if not _queue.is_empty():
		_tick_queue(delta)
		return
	for e in _alive.duplicate():
		if not is_instance_valid(e) or e.get("dead"):
			_alive.erase(e)
	if not _alive.is_empty():
		return
	_gap += delta
	if _gap < WAVE_GAP:
		return
	_gap = 0.0
	if _wave + 1 < waves.size():
		_spawn_wave(_wave + 1)
	else:
		_finish()


func _player_inside() -> bool:
	# 往地面下面多包 2 像素：脚底刚好踩在地面那一行（y == floor）时 has_point 不算在里面
	var zone := Rect2(left + 24.0, ceil_y, right - left - 48.0, maxf(floor_left, floor_right) - ceil_y + 2.0)
	for p in get_tree().get_nodes_in_group("player"):
		if zone.has_point((p as Node2D).global_position):
			return true
	return false


func _start() -> void:
	started = true
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_entered_left = (players[0] as Node2D).global_position.x < (left + right) / 2.0
	for g in _gates:
		g.slam()
	Game.add_shake(4.0)
	Game.sfx("crack", -4.0, 0.7, 0.05)
	_show_label("AMBUSH!")
	_gap = WAVE_GAP * 0.5


func _spawn_wave(i: int) -> void:
	_wave = i
	var kinds: Array = waves[i]
	var xs := _spawn_xs(kinds.size())
	for k in kinds.size():
		var x: float = xs[k]
		if kinds[k] in ELITES:
			x = _far_x()
		_queue.append({"kind": kinds[k], "x": x, "t": -k * 0.18, "warned": false})


## 落点：在场子里散开，离主角至少 40 像素
func _spawn_xs(n: int) -> Array:
	var px := (left + right) / 2.0
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		px = (players[0] as Node2D).global_position.x
	var out := []
	for k in n:
		var x := 0.0
		for _try in 12:
			x = randf_range(left + 18.0, right - 18.0)
			if absf(x - px) >= 40.0 and out.all(func(o): return absf(o - x) >= 14.0):
				break
		out.append(x)
	return out


## 场子里离主角远的那一头
func _far_x() -> float:
	var players := get_tree().get_nodes_in_group("player")
	var px := (left + right) / 2.0 if players.is_empty() else (players[0] as Node2D).global_position.x
	var margin := 40.0
	return right - margin if px < (left + right) / 2.0 else left + margin


func _tick_queue(delta: float) -> void:
	for q in _queue.duplicate():
		q["t"] += delta
		var x: float = q["x"]
		var elite: bool = q["kind"] in ELITES
		if q["t"] >= 0.0 and not q["warned"]:
			q["warned"] = true
			# 预警：管子口冒火花、响一声；精英怪动静更大
			if elite:
				Game.sparks(get_parent(), Vector2(x, ceil_y + 2.0), Color8(255, 120, 80), 20, 90.0, Vector2.DOWN)
				Game.sfx("crack", -8.0, 0.8)
				Game.add_shake(2.0)
			else:
				Game.sparks(get_parent(), Vector2(x, ceil_y + 2.0), Color8(255, 190, 120), 6, 60.0, Vector2.DOWN)
				Game.sfx("scrap", -16.0, 1.7, 0.1)
		if q["t"] >= (ELITE_WARN_TIME if elite else WARN_TIME):
			_queue.erase(q)
			if spawn_hook.is_valid():
				var hooked: Node2D = spawn_hook.call(q["kind"], x)
				if hooked:
					_alive.append(hooked)
					if elite:
						Run.add_emotion(10.0)
					continue
			var e := _make(q["kind"])
			if e == null:
				continue
			e.position = Vector2(x, ceil_y + 14.0)
			get_parent().add_child(e)
			_drop_below_ceiling(e, x)
			_alive.append(e)
			if elite:
				Run.add_emotion(10.0)


## 出生高度：原来一律放在天花板下 14 像素，高个子的怪（总机台 46、留声机 45、放映机 52……）
## 一出生头就嵌进天花板，被物理挤到天花板上面去：血条出来了，房间里看不到怪（2026-10-17）。
## 现在加进场景以后（_ready 里才知道碰撞框、贴图多大）按怪的个头往下挪：
## 头顶（碰撞框和贴图里更高的那个）离天花板 SPAWN_HEADROOM；天花板往上探一下实际的位置；脚不低于地面。
const SPAWN_HEADROOM := 3.0


func _drop_below_ceiling(e: Node2D, x: float) -> void:
	var top := -14.0
	var fs = e.get("frame_size")
	if fs is Vector2i or fs is Vector2:
		top = minf(top, -float(fs.y))
	for c in e.get_children():
		var cs := c as CollisionShape2D
		if cs and cs.shape is RectangleShape2D:
			top = minf(top, cs.position.y - (cs.shape as RectangleShape2D).size.y / 2.0)
	var floor_y := minf(floor_left, floor_right)
	# 从地面往上找第一块挡头的东西（场子的天花板可能比 ceil_y 低）
	var ceiling := ceil_y
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, floor_y - 2.0), Vector2(x, ceil_y - 1.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		ceiling = maxf(ceiling, hit["position"].y)
	var feet := minf(ceiling + SPAWN_HEADROOM - top, floor_y)
	e.global_position = Vector2(x, maxf(feet, ceil_y + 14.0))
	e.reset_physics_interpolation()
	# 有的怪在 _ready 里记下出生点（死了从那儿复活），跟着改
	if "_home" in e:
		e.set("_home", e.global_position)


func _make(kind: String) -> Node2D:
	var path: String = TYPES.get(kind, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	var e: Node2D = (load(path) as GDScript).new()
	e.set("respawn_time", 0.0)
	return e


func _finish() -> void:
	cleared = true
	finished.emit()
	for g in _gates:
		g.rise()
	Game.sfx("ready", -6.0)
	# 清场回血（策划案第七节"关卡内回血"）：和 CHECKPOINT 一起出
	Run.heal_crystal(CLEAR_HEAL)
	_show_label(tr("CLEAR   LANTERN +%d") % int(CLEAR_HEAL))
	var part := Part.new()
	part.position = Vector2((left + right) / 2.0, ceil_y + 20.0)
	get_parent().add_child.call_deferred(part)
	# 存档点：场子里出口那一侧，离闸门 28 像素，悬空 16 像素落下来（不会卡进地里）
	var exit_right := _entered_left
	var x := right - 28.0 if exit_right else left + 28.0
	var y := (floor_right if exit_right else floor_left) - 16.0
	Run.save_checkpoint(_key, Vector2(x, y))


func _show_label(text: String) -> void:
	_label.text = text
	_label.visible = true
	_label_t = 1.6


func _tick_label(delta: float) -> void:
	if _label_t <= 0.0:
		return
	_label_t -= delta
	_label.modulate.a = clampf(_label_t / 0.4, 0.0, 1.0)
	_label.visible = _label_t > 0.0


func _add_gate(x: float, floor_y: float) -> Gate:
	var g := Gate.new()
	g.height = floor_y - ceil_y
	g.position = Vector2(x, ceil_y)
	add_child(g)
	return g


## 废铁闸门：平时缩在天花板里（看不见、不挡路），开打时砸下来，打完升回去
class Gate:
	extends StaticBody2D

	var height := 60.0
	var _shape: CollisionShape2D
	var _drop := 0.0          # 0 = 收在天花板里，1 = 落到底

	func _ready() -> void:
		collision_layer = 1
		_shape = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(GATE_W, height)
		_shape.shape = r
		_shape.position = Vector2(0, height / 2.0)
		_shape.disabled = true
		add_child(_shape)
		visible = false
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded
		z_index = 5

	func slam() -> void:
		visible = true
		_shape.set_deferred("disabled", false)
		var tw := create_tween()
		tw.tween_method(_set_drop, 0.0, 1.0, SLAM_TIME).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): Game.dust(get_parent().get_parent(), global_position + Vector2(0, height), 4))

	func rise() -> void:
		_shape.set_deferred("disabled", true)
		var tw := create_tween()
		tw.tween_method(_set_drop, 1.0, 0.0, RISE_TIME).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func(): visible = false)

	func _set_drop(v: float) -> void:
		_drop = v
		queue_redraw()

	func _draw() -> void:
		# 只画落下来的那一截（上面那截还在天花板里）。
		# 闸门不吃场景压暗（_ready 里设了 unshaded），不然深灰的门叠在深灰的背景上根本看不见
		var h := height * _drop
		var x0 := -GATE_W / 2.0
		draw_rect(Rect2(x0, 0, GATE_W, h), Color8(52, 47, 44))
		for bx in [1, 4, 6]:
			draw_rect(Rect2(x0 + bx, 0, 1, h), Color8(104, 96, 88))
		var y := h - 12.0
		while y > 0.0:
			draw_rect(Rect2(x0, y, GATE_W, 1), Color8(80, 72, 66))
			y -= 14.0
		draw_rect(Rect2(x0, 0, 1, h), Color8(128, 118, 108))
		# 底部一截琥珀色斜纹警示条 + 一颗红灯
		if h > 10.0:
			for i in 8:
				var yy := h - 9.0 + i
				for xx in range(int(GATE_W)):
					if (xx + i) % 4 < 2:
						draw_rect(Rect2(x0 + xx, yy, 1, 1), Color8(214, 150, 60))
					else:
						draw_rect(Rect2(x0 + xx, yy, 1, 1), Color8(40, 34, 30))
			draw_rect(Rect2(-1, h - 13.0, 2, 2), Color(1.0, 0.28, 0.18))
		# 底下一排锯齿
		for i in int(GATE_W / 2.0):
			draw_rect(Rect2(x0 + i * 2, h - 1, 1, 2), Color8(90, 70, 58))


## 零件（策划案第十节的货币）。打完遭遇战掉在场子中间，碰到就捡
class Part:
	extends Area2D

	var _t := 0.0
	var _vy := -60.0
	var _floor_hit := false

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(10, 10)
		cs.shape = r
		add_child(cs)
		body_entered.connect(_on_body)
		var glow := PointLight2D.new()
		glow.texture = Game.light_texture()
		glow.color = Color(1.0, 0.8, 0.5)
		glow.energy = 0.8
		glow.texture_scale = 0.5
		add_child(glow)
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = unshaded

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _floor_hit:
			_vy = minf(_vy + 500.0 * delta, 200.0)
			var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, _vy * delta + 4.0), 1)
			if get_world_2d().direct_space_state.intersect_ray(q).is_empty():
				global_position.y += _vy * delta
			else:
				_floor_hit = true
				Game.sfx("land", -14.0, 1.8)
		queue_redraw()

	func _on_body(b: Node) -> void:
		if not b is Player:
			return
		Run.add_part()
		Game.sfx("lantern_pick", -4.0, 1.6)
		Game.sparks(get_parent(), global_position, Color(1.0, 0.85, 0.55), 10, 70.0)
		queue_free()

	func _draw() -> void:
		# 一个小齿轮，上下浮一点
		var o := Vector2(0, -3 + roundf(sin(_t * 4.0)))
		var dark := Color8(150, 112, 70)
		var lit := Color8(255, 211, 138)
		draw_rect(Rect2(o + Vector2(-2, -2), Vector2(5, 5)), lit)
		for d in [Vector2(-1, -4), Vector2(-1, 3), Vector2(-4, -1), Vector2(3, -1)]:
			draw_rect(Rect2(o + d, Vector2(3, 1) if absf(d.y) > 2 else Vector2(1, 3)), dark)
		draw_rect(Rect2(o, Vector2(1, 1)), dark)
