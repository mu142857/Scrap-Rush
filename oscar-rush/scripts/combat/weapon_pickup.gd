class_name WeaponPickup
extends Node2D
## 打完某些精英掉的武器（10-18 作者："要不要打完某些精英怪自动掉落武器？都是固定的，比如火车掉蒸汽锤，你可以选择是否替换"）。
## 精英真炸开那一下（EliteBase._die）调 WeaponPickup.drop_from(精英)：DROPS 里有它就在脚下放一个。
## - 地上一个武器图标（商店图标表 icons.png），上下浮、身上发光、一圈光环一跳一跳。
## - 主角走近：底部弹一张对比卡（新武器的名字和特性，下面一行"现在"手上那把），按"下"换。
##   交互用"下"不用 V：V 是放下 / 捡起马灯，用它会把马灯一起放下。
## - 换了：手上那把留在原地变成新的拾取物，可以换回去。不换就一直在地上，场子开门以后也能回来拿。
## - 双人：谁按算谁的。所有人手上都已经是这把时不掉武器，改掉 1～2 个零件。
## - 换枪用主角现成的 set_weapon（新武器的出招脚本会跟着重建，双人只换按键的那个人）。它写进 Run.players /
##   Upgrades.weapon，下一关开头自动存档时带上（存档存的是"那关开头"，关卡中途不改存档文件，见 夜间打磨/难度和存档接口.md）。
## - "下"键别的用处：单向平台上按"下"往下跳、霰弹枪空中按住"下"朝脚下喷、激光开火时按"下"往下压。所以只在
##   站在地上、和拾取物同一层、没按着攻击、刚按下"下"的那一下才换；拾取物也只落在实心地面上（不落单向平台），
##   换枪的那一下不会顺带掉下平台。手柄的"下"（摇杆下 / 十字键下）是同一个动作，一样。

## 哪只精英掉哪把：第一、二关按精英脚本的文件名，第三关按 level3_mobs.gd 里的名字
const DROPS := {
	"register": "shotgun",      # 收银机：吐碎铁、硬币
	"sewing": "rivet",          # 缝纫机：针头一下下扎
	"gramophone": "record",     # 留声机：唱片
	"switchboard": "tongs",     # 总机台：电话线、配电
	"projector": "flash",       # 放映机：放映灯的光
	"last_train": "hammer",     # 末班车：火车掉蒸汽锤（作者举的例子）
	"tvcrab": "laser",          # 电视寄居蟹：老电视
	"static_noise": "tongs",    # 白噪音：静电
}
const PICK_RANGE := 22.0
const SWAP_GAP := 0.5
const CARD_RECT := Rect2(100, 196, 280, 44)
const GLOW := Color(1.0, 0.85, 0.55)

var weapon := "flash"
var _t := 0.0
var _rise := 0.0            # 刚掉出来时往上一跳
var _gap := 0.0
var _focus: Node2D = null
var _ui: CanvasLayer
var _card: Control
var _lines: Array[Label] = []


## 精英炸开时调（EliteBase._die）
static func drop_from(e: Node2D) -> void:
	if e == null or not e.is_inside_tree():
		return
	var key := elite_key(e)
	if not DROPS.has(key):
		return
	var id: String = DROPS[key]
	var def: Dictionary = WeaponRegistry.get_def(id)
	if def.is_empty() or not def.get("ready", false):
		return
	# 所有人手上都已经是这把：改掉 1～2 个零件当补偿（10-19 作者定的；遭遇战现成的零件，会自己飞到人身上）
	var everyone := true
	for n in e.get_tree().get_nodes_in_group("player"):
		if not n.has_method("weapon") or str(n.call("weapon")) != id:
			everyone = false
	if everyone and not e.get_tree().get_nodes_in_group("player").is_empty():
		var at: Vector2 = e.call("aim_point") if e.has_method("aim_point") else e.global_position
		for k in randi_range(1, 2):
			var part := Encounter.Part.new()
			part.position = at + Vector2((k * 2 - 1) * 6.0, 0)
			e.get_parent().add_child.call_deferred(part)
		return
	var w := WeaponPickup.new()
	w.weapon = id
	w.position = _ground(e, e.global_position)
	e.get_parent().add_child(w)


static func elite_key(e: Node) -> String:
	var mn = e.get("mob_name")
	if mn is String and mn != "":
		return mn
	var scr := e.get_script() as Script
	return scr.resource_path.get_file().get_basename() if scr else ""


## 往下找实心地面（单向平台跳过：站在上面按"下"会掉下去）
static func _ground(e: Node2D, at: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(at + Vector2(0, -20), at + Vector2(0, 200), 1)
	var space := e.get_world_2d().direct_space_state
	for _i in 4:
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return at.round()
		if not Player.is_one_way_body(hit["collider"]):
			return (hit["position"] as Vector2).round()
		q.exclude = q.exclude + [hit["rid"]]
	return at.round()


func _ready() -> void:
	z_index = 6
	add_to_group("weapon_pickup")
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = m
	var l := PointLight2D.new()
	l.texture = Game.light_texture()
	l.color = GLOW
	l.energy = 0.7
	l.texture_scale = 0.6
	l.position = Vector2(0, -12)
	l.name = "L"
	add_child(l)
	_rise = 1.0
	_build_card()
	Game.sfx("ding", -10.0, 1.2)
	Game.sparks(get_parent(), global_position + Vector2(0, -10), GLOW, 8, 70.0, Vector2.UP)


func _physics_process(delta: float) -> void:
	_t += delta
	_gap = maxf(_gap - delta, 0.0)
	_rise = maxf(_rise - delta * 2.5, 0.0)
	# 离得最近的那个主角（双人谁近给谁看卡、谁按算谁的）
	var best: Node2D = null
	var bd := PICK_RANGE
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Node2D
		if p == null or not p.has_method("set_weapon"):
			continue
		var d := (p.global_position + Vector2(0, -8)).distance_to(global_position + Vector2(0, -10))
		if d < bd:
			bd = d
			best = p
	if best != _focus:
		_focus = best
		if _focus:
			Game.sfx("ui_move", -14.0, 1.3)
	_card.visible = _focus != null
	if _focus:
		_fill_card(_focus)
		var pre: String = str(_focus.get("input_prefix"))
		if _gap <= 0.0 and _can_swap(_focus) and Input.is_action_just_pressed(pre + "_down") and str(_focus.call("weapon")) != weapon:
			_swap(_focus)
	var light := get_node_or_null("L") as PointLight2D
	if light:
		light.energy = 0.6 + 0.25 * sin(_t * 4.0) + (0.4 if _focus else 0.0)
	queue_redraw()
	_card.queue_redraw()


## 站在地上、和拾取物同一层（不在上面的平台上）、没按着攻击键
func _can_swap(p: Node2D) -> bool:
	if not (p as CharacterBody2D).is_on_floor():
		return false
	if absf(p.global_position.y - global_position.y) > 6.0:
		return false
	if p.has_method("attack_held") and p.call("attack_held"):
		return false
	return true


func _swap(p: Node2D) -> void:
	var old := str(p.call("weapon"))
	p.call("set_weapon", weapon)
	Achievements.on_weapon_swap()   # 成就"热插拔"（立绘添加会话，10-18）
	_gap = SWAP_GAP
	weapon = old
	_rise = 0.6
	Game.sfx("ui_confirm", -6.0, 1.0)
	Game.sfx("clang", -12.0, 1.4)
	Game.sparks(get_parent(), global_position + Vector2(0, -10), GLOW, 10, 80.0, Vector2.UP)
	if p.has_method("pop"):
		p.call("pop", 0.3, 0.6)


## 地上的图标：浮着、底下一小块影子、一圈光环一跳一跳
func _draw() -> void:
	var def: Dictionary = WeaponRegistry.get_def(weapon)
	var icon := maxi(ShopStand.ICON_NAMES.find(str(def.get("icon", ""))), 0)
	var bob := roundf(sin(_t * 3.0) * 1.5) - roundf(sin(_rise * PI) * 6.0)
	var at := Vector2(-8, -22 + bob)
	draw_rect(Rect2(-5, -1, 11, 1), Color(0, 0, 0, 0.35))
	var r := 11 + (1 if int(_t * 4.0) % 2 == 0 else 0)
	UiStyle.pixel_ring(self, Vector2(0, -14 + bob), r, Color(GLOW, 0.35 if _focus == null else 0.75))
	UiStyle.icon(self, ShopStand.ICONS, icon, at)
	# 两颗绕着转的小亮点
	for k in 2:
		var a := _t * 2.5 + k * PI
		draw_rect(Rect2((Vector2(0, -14 + bob) + Vector2(cos(a), sin(a)) * 12.0).round(), Vector2.ONE), Color(1, 1, 0.9, 0.9))


func _build_card() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 38
	add_child(_ui)
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = CARD_RECT.position
	_card.size = CARD_RECT.size
	_card.draw.connect(_draw_card)
	_card.visible = false
	_ui.add_child(_card)
	for i in 3:
		var l := UiStyle.label("", UiStyle.TEXT, Vector2(42, 2 + i * 13), CARD_RECT.size.x - 46)
		_card.add_child(l)
		_lines.append(l)


func _fill_card(p: Node2D) -> void:
	var def: Dictionary = WeaponRegistry.get_def(weapon)
	var cur := str(p.call("weapon"))
	var cdef: Dictionary = WeaponRegistry.get_def(cur)
	var scheme := str(p.get("input_prefix"))
	var key := Controls.key_name(scheme, "down") if scheme != "" else Controls.label("down")
	if cur == weapon:
		_lines[0].text = tr(str(def.get("name", weapon)))
		_lines[1].text = tr("You already have this one")
	else:
		_lines[0].text = "%s      %s" % [tr(str(def.get("name", weapon))), tr("%s: SWAP") % key]
		_lines[1].text = tr(str(def.get("trait", "")))
	_lines[2].text = tr("NOW: %s") % tr(str(cdef.get("name", cur)))
	_lines[0].label_settings = Hud.small_text(UiStyle.WARM)
	_lines[1].label_settings = Hud.small_text(UiStyle.TEXT)
	_lines[2].label_settings = Hud.small_text(UiStyle.DIM)


func _draw_card() -> void:
	var r := Rect2(Vector2.ZERO, CARD_RECT.size)
	UiStyle.panel(_card, r, true, _t, GLOW)
	var ir := Rect2(4, 4, 34, 36)
	UiStyle.panel(_card, ir, false, _t, UiStyle.WARM, Color(0.03, 0.03, 0.04, 0.9))
	var def: Dictionary = WeaponRegistry.get_def(weapon)
	var icon := maxi(ShopStand.ICON_NAMES.find(str(def.get("icon", ""))), 0)
	UiStyle.icon(_card, ShopStand.ICONS, icon, Vector2(5, 6 + roundf(sin(_t * 3.0))), 2)
