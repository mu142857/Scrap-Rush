class_name GameCamera
extends Camera2D
## 跟所有玩家的镜头。像素画不缩放，只平移。
## - 构图照空洞骑士：主角在画面下半部，脚在画面约 75% 高处，头顶留大片空间看上面的平台和怪；往移动方向多看 60 像素
## - 跳起来时镜头不上下晃（照 Phage：只跟落地时的高度）
## - 往下掉得快时镜头提前往下看 60 像素，先看到落点
## - 多人时跟所有人的中心，提灯的人权重加倍
## - 2026-10-17：画面放大 2 倍（和开始界面一样），屏幕上只看到 240×135 个游戏像素，
##   站在上层看不到底层。3~4 人时退到 1.5 倍，免得有人被挤出画面。下面的距离都是游戏像素。
## - "camera_focus" 组里的节点（精英怪出场动画时）把镜头往它那边拉一半，主角和它都在画面里；
##   不管怎么拉，玩家都不出画面
## - 主角开了物理插值（见 Settings），镜头在渲染帧里读主角插值后的位置（_pos），
##   不读 global_position，不然物理帧和屏幕帧对不上时主角相对画面一顿一顿地抖

const ZOOM := 2.0
const ZOOM_CROWD := 1.5
const LOOK_AHEAD := 36.0
const LOOK_AHEAD_SPEED := 3.0
const FOCUS_OFFSET := Vector2(0, -34)
const FOLLOW_X_SPEED := 9.0
const FOLLOW_Y_SPEED := 5.0
const FALL_CATCHUP := 16.0
const FALL_LOOK_DOWN := 40.0
const FALL_LOOK_SPEED := 160.0
const EDGE_MARGIN := 12.0
## 有 camera_focus 时，镜头从玩家往它那边挪多少（0.5 = 正中间）
const EXTRA_FOCUS_WEIGHT := 0.5

var bounds := Rect2(0, 0, 480, 270)

var _look := 0.0
var _look_down := 0.0
var _ground_y := 0.0
var _has_ground := false
## 合作时镜头往外拉 / 推回去的快慢
const COOP_ZOOM_SPEED := 3.0
## 合作时所有人四周至少留这么多（游戏像素）：左右、上（头顶）、下（脚下）
const COOP_PAD := Vector2(28, 40)

## 想要的缩放（2，或者 3~4 人时 1.5）；实际 zoom 是它按屏幕倍率对齐以后的值
var _base_zoom := ZOOM
## 关卡的镜头子类自己管缩放（天桥变宽、第三关按屏幕挑倍数）时设成 false
var manages_zoom := true
## 主角上一个、这一个物理帧的位置（_pos 插值用）
var _prev := {}
var _curr := {}


func _ready() -> void:
	# 物理帧里排在主角后面，记到的是主角这一帧动完的位置
	process_physics_priority = 100
	_base_zoom = ZOOM if _players().size() <= 2 else ZOOM_CROWD
	zoom = Vector2.ONE * pixel_zoom(get_viewport(), _base_zoom)
	make_current()


## 把缩放对齐到"一个游戏像素正好占整数个屏幕像素"：窗口不是 480×270 的整数倍时
## （1366×768 是 2.84 倍、网页版跟着浏览器窗口变），zoom 2 会让场景的像素一大一小。
## 这里改用最接近的 k / 屏幕倍率（k 是整数），画面大小差一点点，像素永远是方的、一样大。
## round_down = true 时往小取（视野往大取），用在"必须装下整块屏幕"的地方。
## UI 层（zoom 1）不受影响；要连 UI 也整数倍，设置里开"像素完美"。
static func pixel_zoom(vp: Viewport, z: float, round_down := false) -> float:
	var t := vp.get_screen_transform().get_scale()
	var s := minf(t.x, t.y)
	# 窗口比 480×270 还小（headless 测试的窗口就很小）时不对齐：
	# 不然 1 / s 会把 zoom 算成 7 倍多，画面只剩几十像素，按画面范围算东西的逻辑全被带偏（第二关会话 10-17 夜里报的）
	if s < 1.0:
		return z
	var px := z * s
	var k := floorf(px + 0.001) if round_down else roundf(px)
	return maxf(k, 1.0) / s


## 第一帧直接对准，不从原点滑过来
func snap() -> void:
	_has_ground = false
	_process(0.0)
	global_position = _target_position()


func _process(delta: float) -> void:
	if manages_zoom:
		# 合作时两人拉开，原来的倍数装不下所有人，就往外拉（最远 1 倍）；靠拢后慢慢推回去。停住时照样像素对齐
		var want := minf(_base_zoom, coop_fit_zoom())
		var tgt := pixel_zoom(get_viewport(), want, want < _base_zoom)
		# 往小对齐可能落到 1 倍以下（视野比关卡还大，商店这种一屏的房间会露出外面），最多拉到 1 倍
		tgt = maxf(tgt, 1.0)
		var z := lerpf(zoom.x, tgt, 1.0 - exp(-COOP_ZOOM_SPEED * delta))
		if absf(z - tgt) < 0.002:
			z = tgt
		zoom = Vector2(z, z)
	var players := _players()
	if players.is_empty():
		return
	var lead := _lead(players)
	var k_look := 1.0 - exp(-LOOK_AHEAD_SPEED * delta)
	_look = lerpf(_look, lead.facing * LOOK_AHEAD, k_look)

	var falling := not lead.is_on_floor() and lead.velocity.y > FALL_LOOK_SPEED
	_look_down = move_toward(_look_down, FALL_LOOK_DOWN if falling else 0.0, delta * (180.0 if falling else 90.0))

	var target := _target_position()
	var pos := global_position
	pos.x = lerpf(pos.x, target.x, 1.0 - exp(-FOLLOW_X_SPEED * delta))
	var y_speed := FOLLOW_Y_SPEED * (2.0 if falling else 1.0)
	pos.y = lerpf(pos.y, target.y, 1.0 - exp(-y_speed * delta))

	# 保底：不管镜头追得多慢，玩家都不能出画面
	var half := get_viewport_rect().size * 0.5 / zoom
	for p in players:
		var at := _pos(p)
		pos.y = clampf(pos.y, at.y - half.y + EDGE_MARGIN, at.y - 20.0 + half.y - EDGE_MARGIN)
		pos.x = clampf(pos.x, at.x - half.x + EDGE_MARGIN, at.x + half.x - EDGE_MARGIN)
	global_position = _clamp_to_bounds(pos, half)
	# 震屏按屏幕像素算，放大以后除回去，力度和以前一样
	offset = Game.shake_offset(zoom.x)


func _target_position() -> Vector2:
	var players := _players()
	if players.is_empty():
		return global_position
	var lead := _lead(players)
	var focus := Vector2.ZERO
	var weight := 0.0
	for p in players:
		var w := 2.0 if p.crystal else 1.0
		focus += _pos(p) * w
		weight += w
	focus /= weight

	var target_y: float
	if players.size() == 1:
		var grounded := lead.is_on_floor()
		var lead_y := _pos(lead).y
		if grounded or not _has_ground:
			_ground_y = lead_y
			_has_ground = true
		target_y = _ground_y
		if not grounded and lead_y - _ground_y > FALL_CATCHUP:
			target_y = lead_y - FALL_CATCHUP
	else:
		target_y = focus.y
	var target_x := focus.x + _look
	# 合作两人拉开到要往外拉的时候，对准所有人的正中间、不往前看，不然有人会贴着画面边
	if players.size() > 1 and coop_fit_zoom() < _base_zoom:
		var lo := _pos(players[0])
		var hi := lo
		for p in players:
			lo = lo.min(_pos(p))
			hi = hi.max(_pos(p))
		target_x = (lo.x + hi.x) * 0.5
		target_y = (lo.y + hi.y) * 0.5
	var extra := get_tree().get_nodes_in_group("camera_focus")
	if not extra.is_empty():
		target_x = lerpf(target_x, (extra[0] as Node2D).global_position.x, EXTRA_FOCUS_WEIGHT)
	var half := get_viewport_rect().size * 0.5 / zoom
	return _clamp_to_bounds(Vector2(target_x, target_y + _look_down) + FOCUS_OFFSET, half)


## 主角画在屏幕上的位置（物理插值以后的）。2D 节点没有 get_global_transform_interpolated，
## 所以镜头自己在每个物理帧末尾记下主角的位置（_physics_process，排在主角后面），
## 渲染时按 Engine.get_physics_interpolation_fraction() 在上一帧和这一帧之间插，和引擎画主角的算法一样
func _pos(n: Node2D) -> Vector2:
	if not _curr.has(n):
		return n.global_position
	return (_prev[n] as Vector2).lerp(_curr[n], Engine.get_physics_interpolation_fraction())


func _physics_process(_delta: float) -> void:
	var seen := {}
	for p in _players():
		var now := p.global_position
		var last: Vector2 = _curr.get(p, now)
		# 一帧挪了老远就是瞬移（出管口、重生），不插值
		_prev[p] = now if last.distance_to(now) > 24.0 else last
		_curr[p] = now
		seen[p] = true
	for k in _curr.keys():
		if not seen.has(k):
			_curr.erase(k)
			_prev.erase(k)


## 能把所有玩家（四周留 COOP_PAD）装进画面的最大缩放，不小于 1；单人时返回很大的数（不限制）
func coop_fit_zoom() -> float:
	var players := _players()
	if players.size() < 2:
		return 99.0
	var lo := _pos(players[0])
	var hi := lo
	for p in players:
		var at := _pos(p)
		lo = lo.min(at)
		hi = hi.max(at)
	var need := (hi - lo) + COOP_PAD * 2.0 + Vector2(0, 20)
	var view := get_viewport_rect().size
	return maxf(1.0, minf(view.x / need.x, view.y / need.y))


## 人被瞬移（出气动管、下天桥）以后调：落地高度按人现在的位置重新记，不再追旧房间的地面
func forget_ground() -> void:
	_has_ground = false
	_look_down = 0.0


func _clamp_to_bounds(pos: Vector2, half: Vector2) -> Vector2:
	var out := pos
	if bounds.size.x <= half.x * 2.0:
		out.x = bounds.get_center().x
	else:
		out.x = clampf(out.x, bounds.position.x + half.x, bounds.end.x - half.x)
	if bounds.size.y <= half.y * 2.0:
		out.y = bounds.get_center().y
	else:
		out.y = clampf(out.y, bounds.position.y + half.y, bounds.end.y - half.y)
	return out


func _players() -> Array[Player]:
	var out: Array[Player] = []
	for n in get_tree().get_nodes_in_group("player"):
		if n is Player:
			out.append(n)
	return out


## 镜头的朝向和落地高度跟谁：提灯的人，没人提灯就第一个玩家
func _lead(players: Array[Player]) -> Player:
	for p in players:
		if p.crystal:
			return p
	return players[0]
