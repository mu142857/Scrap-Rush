class_name BossArena
extends Node2D
## 关底 Boss 房的通用底子（从第一关的炉膛间抽出来的）。每个 Boss 房 extends 它，在 _configure() 里填参数，
## 在 _make_boss() 里造 Boss，需要的话在 _build_extras() 里加自己的机关。
## 流程：
##   1. 从左边进来，镜头先是普通关卡的 2 倍放大跟着主角
##   2. 走过 trigger_x：左边闸门"哐"地砸下锁门，镜头退远露出整个房间，警报灯转起来，
##      Boss 醒来（boss.wake()），屏幕中间逐字打出名字和一句话
##   3. 开打（boss.start_fight()）。二阶段警报灯变快，三阶段整个房间变成 darkness_hot 的颜色
##   4. Boss 倒下：等它的死亡演出，打出 defeat_line，掉 1 个零件，右边闸门升起；走出去进商店或下一站
## Boss 要有：signal hp_changed(hp, max_hp)、phase_changed(phase)、defeated；
##           属性 hp、max_hp、phase；方法 wake()、start_fight()。
## F3 显示碰撞框，R 从房间门口重来。

const M := 16

# —— 子类在 _configure() 里改 ——
var bg_tex: Texture2D
var fg_tex: Texture2D
var gate_tex: Texture2D = preload("res://art/boss/gate.png")
var arena := Rect2(0, 0, 320, 180)
var floor_y := 164.0
var wall := 8.0
var ceil_y := 12.0
## 单向平台：Vector3(x0, x1, 顶面 y)
var platforms: Array = []
## 天花板上的转灯
var lamps: Array = []
var lamp_color := Color(1.0, 0.25, 0.15)
var lamp_energy := 0.55
var spawn := Vector2(26, 164)
var trigger_x := 64.0
var gate_open_y := 84.0
var gate_shut_y := 124.0
var darkness := Color(0.32, 0.26, 0.27)
var darkness_hot := Color(0.45, 0.22, 0.2)
var zoom_fight := 1.5
var zoom_enter := 2.0
var boss_name := "BOSS"
var card_sub := ""
var defeat_line := ""
var clear_banner := "CLEARED"
## 打完走出去：next_shop 非空就先进商店，商店出口去 next_shop；否则直接去 next_scene
var next_scene := "res://scenes/title.tscn"
var next_shop := ""
## 死亡演出要多久，之后才打字、开门
var defeat_wait := 4.0

var hud: Hud
var boss: Node2D
var _bar: BossBar
var _cam: Camera2D
var _dark: CanvasModulate
var _gate_l: Sprite2D
var _gate_r: Sprite2D
var _exit_wall: CollisionShape2D
var _lamps: Array[PointLight2D] = []
var _lamp_speed := 0.0
var _lamp_angle := 0.0
var _state := 0      # 0 进门，1 开场，2 打，3 打完，4 走了
var _debug := false
var _retrying := false
var _card: Label
var _card_sub: Label


func _configure() -> void:
	pass


func _make_boss() -> Node2D:
	return null


func _build_extras() -> void:
	pass


func _ready() -> void:
	_configure()
	Run.start_level()
	Run.crystal_broken.connect(_on_crystal_broken)
	_build_room()

	boss = _make_boss()
	add_child(boss)
	_build_extras()
	boss.connect("phase_changed", _on_phase)
	boss.connect("defeated", _on_defeated)

	var first: Player = null
	for i in Run.players.size():
		var p := Player.new()
		p.input_prefix = Run.players[i]["input"]
		p.skin = Run.players[i]["skin"]
		p.position = spawn + Vector2(i * 10, 0)
		add_child(p)
		if first == null:
			first = p
	var crystal := Crystal.new()
	crystal.position = spawn
	add_child(crystal)
	crystal.pick_up(first, true)

	_cam = Camera2D.new()
	_cam.zoom = Vector2(zoom_enter, zoom_enter)
	add_child(_cam)
	_cam.make_current()
	_cam.position = _enter_cam_pos()

	hud = Hud.new()
	add_child(hud)
	hud.show_hint = false
	_bar = BossBar.new()
	_bar.boss = boss
	_bar.boss_name = boss_name
	add_child(_bar)
	_build_card()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bossshots="):
			var shots: Node = load("res://scripts/debug/boss_shots.gd").new()
			shots.set("out_dir", arg.trim_prefix("--bossshots="))
			add_child(shots)


func _build_room() -> void:
	for pair in [[bg_tex, -20], [fg_tex, -5]]:
		if pair[0] == null:
			continue
		var s := Sprite2D.new()
		s.texture = pair[0]
		s.centered = false
		s.position = Vector2(-M, -M)
		s.z_index = pair[1]
		add_child(s)

	_dark = CanvasModulate.new()
	_dark.color = darkness
	add_child(_dark)

	_solid(Rect2(-40, floor_y, arena.size.x + 80, 40))
	_solid(Rect2(-40, -40, arena.size.x + 80, 40 + ceil_y))
	_solid(Rect2(-40, -40, 40 + wall, 220 + arena.size.y))
	_solid(Rect2(arena.size.x - wall, -40, 40 + wall, gate_shut_y + 40))
	# 右边闸门那一截墙单独一块，打完以后拆掉放人出去
	_exit_wall = _solid(Rect2(arena.size.x - wall, gate_shut_y, 40 + wall, floor_y - gate_shut_y))
	for p in platforms:
		var cs := _solid(Rect2(p.x, p.z, p.y - p.x, 4))
		cs.one_way_collision = true

	_gate_l = _gate(Vector2(-1, gate_open_y))
	_gate_r = _gate(Vector2(arena.size.x - wall - 1, gate_shut_y))

	for lp in lamps:
		var lamp := Node2D.new()
		lamp.position = lp
		lamp.z_index = 4
		var unshaded := CanvasItemMaterial.new()
		unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		lamp.material = unshaded
		lamp.draw.connect(_draw_lamp.bind(lamp))
		add_child(lamp)
		var l := PointLight2D.new()
		l.texture = Game.light_texture()
		l.color = lamp_color
		l.energy = 0.0
		l.texture_scale = 2.2
		# 转灯照得到 Boss（第 2 层），但不能太亮
		l.range_item_cull_mask = 1 | 2
		lamp.add_child(l)
		_lamps.append(l)


func _solid(r: Rect2) -> CollisionShape2D:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	cs.shape = rect
	cs.position = r.get_center()
	body.add_child(cs)
	add_child(body)
	return cs


func _gate(pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = gate_tex
	s.centered = false
	s.position = pos
	s.z_index = -4
	add_child(s)
	return s


func _build_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_card = Label.new()
	var big := Hud.small_text(Color8(255, 211, 138))
	big.font_size = 33
	big.outline_size = 4
	_card.label_settings = big
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.position = Vector2(0, 92)
	_card.size = Vector2(480, 40)
	layer.add_child(_card)
	_card_sub = Label.new()
	_card_sub.label_settings = Hud.small_text(Color(0.75, 0.72, 0.7))
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_sub.position = Vector2(0, 134)
	_card_sub.size = Vector2(480, 12)
	layer.add_child(_card_sub)


# —— 每帧 ——

func _process(delta: float) -> void:
	var lead := _lead()
	match _state:
		0:
			if lead:
				_cam.position = _cam.position.lerp(_enter_cam_pos(), 1.0 - exp(-8.0 * delta))
				if lead.global_position.x > trigger_x:
					_begin_intro()
		3:
			if lead and lead.global_position.x > arena.size.x + 4.0:
				_leave()
	_cam.offset = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Game.shake / _cam.zoom.x * 2.0).round() / 2.0

	# 转灯：一盏光绕着灯座转
	_lamp_angle += delta * _lamp_speed
	for i in _lamps.size():
		var a := _lamp_angle + PI * i
		_lamps[i].position = Vector2(cos(a) * 26.0, 18.0 + absf(sin(a)) * 30.0)
		_lamps[i].get_parent().queue_redraw()


func _lead() -> Player:
	for n in get_tree().get_nodes_in_group("player"):
		return n as Player
	return null


## 进门时镜头 2 倍放大跟着主角（和普通关卡一样），只在竞技场里平移
func _enter_cam_pos() -> Vector2:
	var lead := _lead()
	var half := get_viewport_rect().size * 0.5 / zoom_enter
	var p := (lead.global_position + Vector2(0, -20)) if lead else spawn
	return Vector2(clampf(p.x, half.x, arena.size.x - half.x), clampf(p.y, half.y, arena.size.y - half.y))


func _begin_intro() -> void:
	_state = 1
	# 闸门砸下来
	var tw := create_tween()
	tw.tween_property(_gate_l, "position:y", gate_shut_y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_solid(Rect2(-40, gate_shut_y, 40 + wall, floor_y - gate_shut_y))
	Game.sfx("clang", -2.0)
	Game.add_shake(6.0)
	Game.sparks(self, Vector2(wall, floor_y - 2), Color(1, 0.8, 0.4), 10, 90.0)
	# 镜头退到能看全整个房间
	var cam := create_tween().set_parallel(true)
	cam.tween_property(_cam, "zoom", Vector2(zoom_fight, zoom_fight), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam.tween_property(_cam, "position", arena.get_center(), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_lamp_speed = 3.0
	for l in _lamps:
		l.energy = lamp_energy
	Game.sfx("alarm", -10.0)
	await get_tree().create_timer(0.7).timeout
	boss.call("wake")
	await get_tree().create_timer(0.6).timeout
	await _show_card(boss_name, card_sub)
	_bar.appear()
	_state = 2
	boss.call("start_fight")


## 屏幕中间的名字：一个字一个字打出来，停一会儿淡掉
func _show_card(title: String, sub: String) -> void:
	_card.text = ""
	_card_sub.text = ""
	_card.modulate.a = 1.0
	_card_sub.modulate.a = 1.0
	for i in title.length():
		_card.text = title.substr(0, i + 1)
		if title[i] != " ":
			Game.sfx("ui_move", -8.0, 0.8)
		await get_tree().create_timer(0.07).timeout
	if title != "":
		Game.add_shake(3.0)
	await get_tree().create_timer(0.3).timeout
	for i in sub.length():
		_card_sub.text = sub.substr(0, i + 1)
		await get_tree().create_timer(0.03).timeout
	await get_tree().create_timer(1.2).timeout
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_card, "modulate:a", 0.0, 0.5)
	tw.tween_property(_card_sub, "modulate:a", 0.0, 0.5)
	await tw.finished


func _on_phase(p: int) -> void:
	_lamp_speed = 3.0 + p * 2.0
	if p == 3:
		create_tween().tween_property(_dark, "color", darkness_hot, 1.5)
		for l in _lamps:
			l.energy = lamp_energy * 1.45


func _on_defeated() -> void:
	_state = 3
	_lamp_speed = 0.6
	create_tween().tween_property(_dark, "color", darkness, 2.0)
	for l in _lamps:
		create_tween().tween_property(l, "energy", 0.25, 2.0)
	await get_tree().create_timer(defeat_wait, true, false, true).timeout
	await _after_defeat()


## 死亡演出之后：打一行字、掉零件、开右边闸门。最终 Boss 会改写成进结局
func _after_defeat() -> void:
	if defeat_line != "":
		await _show_card("", defeat_line)
	Run.add_part()
	# 右边闸门升起，放人出去
	_exit_wall.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(_gate_r, "position:y", gate_open_y - 4.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Game.sfx("clang", -8.0, 0.7)
	var hint := HintSign.new()
	hint.zone = Rect2(arena.size.x - 120, 100, 120, 80)
	hint.position = Vector2(arena.size.x - 24, floor_y - 24)
	hint.text = "Onward"
	hint.arrow = "right"
	add_child(hint)


func _leave() -> void:
	_state = 4
	hud.show_banner(clear_banner)
	await get_tree().create_timer(2.5).timeout
	if next_shop != "":
		ShopRoom.next_scene = next_shop
		get_tree().change_scene_to_file("res://scenes/shop.tscn")
	else:
		get_tree().change_scene_to_file(next_scene)
	Game.flash(Color.BLACK, 1.0, 0.6)


func _on_crystal_broken() -> void:
	hud.show_banner("TAPE DESTROYED")
	Game.flash(Color(0.9, 0.9, 0.95), 0.5, 1.2)
	Game.add_shake(5.0)
	get_tree().paused = true
	await get_tree().create_timer(1.6, true, false, true).timeout
	get_tree().paused = false
	_retry()


func _retry() -> void:
	if _retrying:
		return
	_retrying = true
	Engine.time_scale = 1.0
	Run.retry_level()
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_retry()
			KEY_F3:
				_debug = not _debug
				queue_redraw()


func _draw() -> void:
	if not _debug:
		return
	for p in platforms:
		draw_rect(Rect2(p.x, p.z, p.y - p.x, 4), Color(0.3, 1.0, 0.5, 0.8), false)
	draw_rect(Rect2(0, floor_y, arena.size.x, 2), Color(0.3, 1.0, 0.5, 0.8))
	draw_line(Vector2(trigger_x, 0), Vector2(trigger_x, floor_y), Color(1, 0.8, 0.3, 0.6))


func _draw_lamp(lamp: Node2D) -> void:
	# 灯罩：3×3 的灯，转到正面那一下最亮
	var on := _lamp_speed > 0.0
	var k := 0.5 + 0.5 * cos(_lamp_angle * 2.0) if on else 0.0
	var col := lamp_color.darkened(0.7).lerp(lamp_color.lightened(0.2), k)
	lamp.draw_rect(Rect2(-2, 0, 5, 3), Color(0.2, 0.18, 0.17))
	lamp.draw_rect(Rect2(-1, 1, 3, 3), col)
	lamp.draw_rect(Rect2(0, 2, 1, 1), col.lerp(Color.WHITE, k * 0.6))
