class_name Coach
extends CanvasLayer
## 新手提示：第一次需要某个动作的时候，屏幕下方弹一条短提示，做到了（或过一会儿）就淡掉。
## 每条一局只出一次（重来、换关都不再出）。Hud 自己会建一个。
##   move    第一关开头：移动、跳
##   shoot   第一次有怪靠近：按住蓄力、松手射
##   lantern 马灯第一次掉血：它就是你的命（箭头指左上角的灯）
##   drop    第一次打完遭遇战：放下马灯的利弊
##   low     马灯第一次掉到三成以下：小心，商店能修
##   tube    第二关开场的气动管冲刺：上 / 下换管（tube_run.gd 调用 _want("tube")，换两次就收）
## 另外：每次存档（打完遭遇战）左上角闪一下 CHECKPOINT；从存档点重来时提示一句。

const WARM := Color8(255, 211, 138)
const BOX := Rect2(20, 226, 440, 18)
const FIRST_LEVEL := "res://scenes/test_level.tscn"
## 人在屏幕下沿时提示框挪到这里（血条下面）
const TOP_Y := 30.0

## 这一局已经出过的提示
static var seen := {}

var _queue: Array[String] = []
var _tip := ""
var _tip_t := 0.0
var _alpha := 0.0
var _done := false
var _label: Label
var _box: Control
var _toast: Label
var _toast_t := 0.0
var _start_x := 0.0
var _jumped := false
var _poll := 0.0
var _last_hp := -1.0
## 别的地方塞进来的一次性提示：{编号: 文字}（比如每个 Boss 开打时的打法提示）
var _custom := {}
## 有精英正在登场（名字卡在屏幕上方）
var _card_on := false
## 场上有活着的精英（屏幕底部有它的血条）
var _elite_on := false


func _ready() -> void:
	layer = 11
	_box = Control.new()
	_box.position = BOX.position
	_box.size = BOX.size
	_box.draw.connect(_draw_box)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_label = Label.new()
	_label.label_settings = Hud.small_text(WARM)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2.ZERO
	_label.size = BOX.size
	_box.add_child(_label)
	_box.modulate.a = 0.0

	_toast = Label.new()
	_toast.label_settings = Hud.small_text(WARM)
	# 放在左上角零件数（parts_counter，y 26~42）下面：原来 y 24 和零件数叠成一团（质检 63 号，10-18）
	_toast.position = Vector2(8, 44)
	_toast.size = Vector2(120, 12)
	_toast.text = "CHECKPOINT"
	_toast.modulate.a = 0.0
	add_child(_toast)

	_last_hp = Run.crystal_hp
	Run.crystal_changed.connect(_on_crystal_changed)
	Run.checkpoint_saved.connect(_on_checkpoint)
	# "打完一场 / 灯油会回血"的提示只听真正的回血，不看血量变多（重来、商店修灯也会让血量变多）
	Run.crystal_healed.connect(func(_amount: float): _want("heal"))
	Run.resumed.connect(_on_resumed)
	# 换输入设备时，正在显示的提示当场换成新设备的键名
	Controls.device_changed.connect(func(_p: bool) -> void:
		if _tip != "":
			_label.text = _text(_tip))
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == FIRST_LEVEL:
		_want("move")


func _scheme() -> String:
	return Run.players[0]["input"]


func _text(tip: String) -> String:
	var s := _scheme()
	match tip:
		"move":
			return tr("%s  Move      %s  Jump") % [Controls.key_name(s, "move"), Controls.key_name(s, "jump")]
		"shoot":
			var k := Controls.key_name(s, "attack")
			# 每把武器一句，写在武器登记表里（WeaponRegistry 的 coach）
			return tr(str(WeaponRegistry.value(Upgrades.weapon, "coach", "Hold %s to charge,  release to shoot.  Watch the ring fill"))) % k
		"lantern":
			return "Hits crack the lantern. It's your light - and your life"
		"drop":
			return tr("%s  Put the lantern down: you take the hits, but moths go for it") % Controls.key_name(s, "crystal")
		"low":
			return "The lantern is almost out. The shop can mend it"
		"heal":
			return "Clearing a fight and lamp oil from wrecks mend the lantern"
		"resumed":
			return "Back at the last cleared fight"
		"tube":
			# 第二关开场的气动管冲刺（tube_run.gd 触发）
			return tr("%s / %s  Switch tube up / down") % [Controls.key_name(s, "jump"), Controls.key_name(s, "down")]
	return _custom.get(tip, "")


## 外面塞一条一次性提示进来（key 用来记"出过了"，一局只出一次；text 已经翻译好）
func want_text(key: String, text: String) -> void:
	_custom[key] = text
	_want(key)


## 射击提示每把武器各出一次（商店里换了武器，下一关第一次遇到怪时再教一遍新武器的按法）
func _seen_key(tip: String) -> String:
	return "shoot:" + Upgrades.weapon if tip == "shoot" else tip


## 排队等着出（同一时间只出一条）
func _want(tip: String) -> void:
	if seen.has(_seen_key(tip)) or _queue.has(tip) or _tip == tip:
		return
	if tip != "resumed":
		seen[_seen_key(tip)] = true
	_queue.append(tip)


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.15
		_watch()
	if _tip == "" and not _queue.is_empty():
		_tip = _queue.pop_front()
		_tip_t = 0.0
		_done = false
		_label.text = _text(_tip)
		if _tip == "move":
			var p := _lead()
			_start_x = p.global_position.x if p else 0.0
			_jumped = false
	if _tip != "":
		# 精英登场的名字卡也在屏幕上方正中：名字卡在的时候提示先藏起来、不计时，免得两段字叠在一起
		if not _card_on:
			_tip_t += delta
		if _finished():
			_done = true
		var target := 0.0 if (_done or _card_on) else 1.0
		_alpha = move_toward(_alpha, target, delta * (2.5 if _done else 5.0))
		if _done and _alpha <= 0.0:
			_tip = ""
	else:
		_alpha = move_toward(_alpha, 0.0, delta * 3.0)
	_box.modulate.a = _alpha
	# 有人走到屏幕下沿（第一关最底层地面就贴着底边），提示框挪到上面去，别挡脚
	var low := false
	for p in get_tree().get_nodes_in_group("player"):
		if (p as Node2D).get_global_transform_with_canvas().origin.y > BOX.position.y - 8.0:
			low = true
			break
	# 精英战时屏幕底部是精英的血条和名字，提示框也挪上去
	var y := TOP_Y if (low or _elite_on) else BOX.position.y
	if y == TOP_Y:
		y = _below_signs(y)
	_box.position.y = move_toward(_box.position.y, y, delta * 600.0)
	_box.queue_redraw()
	if _toast_t > 0.0:
		_toast_t -= delta
		# 新手提示框挪到画面上方（TOP_Y 30~48）时，存档点提示让到它下面
		_toast.position.y = 44.0 if _box.position.y > 100.0 else _box.position.y + BOX.size.y + 4.0
		_toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0) * (0.6 + 0.4 * absf(sin(_toast_t * 8.0)))


## 正在出提示（Hud 这时把底下那行按键大全藏起来，不然两行字叠在一起）
func busy() -> bool:
	return _alpha > 0.0 or not _queue.is_empty() or _tip != ""


## 这条提示什么时候算"学会了"
func _finished() -> bool:
	match _tip:
		"move":
			var p := _lead()
			if p:
				if p.velocity.y < -60.0 and not p.is_on_floor():
					_jumped = true
				if _jumped and absf(p.global_position.x - _start_x) > 40.0:
					return _tip_t > 1.5
			return _tip_t > 12.0
		"shoot":
			return Input.is_action_just_released("%s_attack" % _scheme()) and _tip_t > 0.8 or _tip_t > 9.0
		"resumed":
			return _tip_t > 2.5
		"tube":
			var run := get_tree().current_scene
			var n: int = run.get("_switches") if run and run.get("_switches") != null else 0
			return n >= 2 and _tip_t > 1.0 or _tip_t > 8.0
	return _tip_t > 6.0


## 每 0.15 秒看一眼：有没有怪靠近、马灯血量
func _watch() -> void:
	# 屏幕中间的大横幅（Hud.show_banner）在的时候也让开，同一时间只出一段字（10-18 作者：不要有文字重叠）
	_card_on = get_parent() != null and get_parent().has_method("banner_on") and get_parent().call("banner_on")
	# 关卡开场（LevelIntro）的名字卡、精英名字卡在的时候也让开、不计时（10-18 游戏细节讨论会话：开场放开暂停以后提示会和名字卡叠字）
	if not get_tree().get_nodes_in_group("name_card").is_empty():
		_card_on = true
	_elite_on = false
	for e in get_tree().get_nodes_in_group("enemy"):
		# Boss 房：屏幕底部是 Boss 血条，提示框也挪到上面
		if e.has_method("start_fight") and not e.get("dead"):
			_elite_on = true
		if e.has_method("in_intro") and not e.get("dead"):
			_elite_on = true
			if e.call("in_intro"):
				_card_on = true
	if not seen.has(_seen_key("shoot")):
		var p := _lead()
		if p:
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Node2D and not e.get("dead") and (e as Node2D).global_position.distance_to(p.global_position) < 130.0:
					_want("shoot")
					break


func _on_crystal_changed(hp: float, max_hp: float) -> void:
	if _last_hp >= 0.0 and hp < _last_hp - 0.01:
		_want("lantern")
		if hp / maxf(max_hp, 1.0) < 0.3:
			_want("low")
	_last_hp = hp


func _on_checkpoint() -> void:
	_toast_t = 1.6
	Game.sfx("ui_confirm", -12.0, 1.2)
	if seen.has("lantern") or seen.has(_seen_key("shoot")):
		_want("drop")


func _on_resumed() -> void:
	_want("resumed")


## 提示框放在屏幕上方时，别压住关卡里的路线提示牌（字在箭头尖上方约 30 像素）：撞上了就挪到箭头下面
func _below_signs(y: float) -> float:
	for n in get_tree().get_nodes_in_group("hint_sign"):
		var sign := n as Node2D
		if sign == null or float(sign.get("_alpha")) < 0.05:
			continue
		var at := sign.get_global_transform_with_canvas().origin
		if absf(at.x - 240.0) < 220.0 and at.y - 34.0 < y + BOX.size.y and at.y + 4.0 > y:
			y = at.y + 10.0
	return minf(y, BOX.position.y)


func _lead() -> Player:
	for n in get_tree().get_nodes_in_group("player"):
		return n as Player
	return null


func _draw_box() -> void:
	if _alpha <= 0.0:
		return
	var r := Rect2(Vector2.ZERO, BOX.size)
	# 文字宽度跟着内容收一收，框不要比字宽太多
	var w := minf(_label.get_minimum_size().x + 16.0, BOX.size.x + 60.0)
	r = Rect2((BOX.size.x - w) / 2.0, 0, w, BOX.size.y)
	_box.draw_rect(r, Color(0.04, 0.035, 0.05, 0.82))
	_box.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(WARM, 0.6))
	_box.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(WARM, 0.25))
	# "马灯"那条：往左上角的灯画一个会跳的小箭头
	if _tip == "lantern" or _tip == "low":
		var bob := roundf(sin(_tip_t * 6.0) * 2.0)
		var at := Vector2(-BOX.position.x + 82 + bob, -_box.position.y + 14)
		for i in 5:
			_box.draw_rect(Rect2(at + Vector2(i, -i), Vector2(1, i * 2 + 1)), WARM)
		_box.draw_rect(Rect2(at + Vector2(5, -1), Vector2(10, 3)), WARM)
