extends BossArena
## 第三关 Boss 房「最深处」：最后一台老电视 THE SET。竞技场 320×180，镜头固定 1.5 倍。
## 平台是三台吊着的小电视（画在 room3_fg 里），房间没有转灯，只靠电视屏幕的光。
## 打完不开门，直接进结局：
##   1. 电视关机以后安静一会儿，自己重新亮起，开始放录像（家乡）
##   2. 镜头推进屏幕，录像铺满全屏。雪花多少由剩下的水晶血量决定，旁白也分三档
##   3. 切到最后一个镜头：四个人在黑漆漆的废品场里，围着一台发光的电视坐着。THE END → 回标题
## 美术见 tools/draw_boss3.py。

const BOSS_X := 248.0
const ENDING_SHADER := """
shader_type canvas_item;
// 录像的雪花：noise 0~1 由水晶血量决定；fade 控制整体亮度
uniform float noise = 0.2;
uniform float fade = 1.0;
uniform vec2 size = vec2(444.0, 245.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * size);
	float t = floor(TIME * 20.0);
	// 每一行左右抖一点，信号越差抖得越多
	float jitter = (hash(vec2(px.y, t)) - 0.5) * noise * noise * 14.0;
	vec4 img = texture(TEXTURE, UV + vec2(jitter / size.x, 0.0));
	// 一阵一阵断线：整屏只剩雪花
	float drop = step(1.0 - noise * 0.55, hash(vec2(floor(TIME * 2.5), 3.0))) * step(0.15, noise);
	float n = hash(px + vec2(t * 13.0, t * 7.0));
	float amt = clamp(noise * (0.75 + 0.5 * hash(vec2(floor(px.y / 6.0), t))) + drop, 0.0, 1.0);
	vec3 col = mix(img.rgb, vec3(n * 0.9 + 0.05), amt);
	// 一条慢慢往下滚的亮带
	float band = smoothstep(0.0, 0.08, abs(fract(UV.y - TIME * 0.12) - 0.5));
	col *= 0.9 + 0.1 * band;
	// 扫描线
	col *= mod(px.y, 2.0) < 1.0 ? 1.0 : 0.82;
	COLOR = vec4(col * fade, 1.0);
}
"""
## 三档旁白：血量高 / 中 / 低
const LINES := [
	["The house on the hill. The porch light is on.", "Somebody left it on for us.", "We know the way home now."],
	["...a house... a light in the window...", "...the signal keeps slipping...", "Close. We're close."],
	["Snow. Almost all snow.", "For one frame: a lit window.", "That's enough. We know the way now."],
]

var _end_layer: CanvasLayer
var _film: TextureRect
var _film_mat: ShaderMaterial
var _black: ColorRect
var _line: Label
var _end_title: Label
var _end_sub: Label
var _hum: AudioStreamPlayer
var _can_quit := false


func _configure() -> void:
	bg_tex = preload("res://art/boss/room3_bg.png")
	fg_tex = preload("res://art/boss/room3_fg.png")
	gate_tex = preload("res://art/boss/gate3.png")
	platforms = [Vector3(22, 74, 124), Vector3(106, 158, 98), Vector3(34, 86, 70)]
	# 没有转灯：这间屋只有电视屏幕在亮
	lamps = []
	darkness = Color(0.24, 0.24, 0.28)
	darkness_hot = Color(0.32, 0.22, 0.3)
	boss_name = "THE SET"
	card_sub = "The last TV that still plays tapes."
	defeat_line = "It stopped changing channels."
	defeat_wait = 3.4


func _make_boss() -> Node2D:
	var b := TVBoss.new()
	b.position = Vector2(BOSS_X, floor_y)
	b.arena = arena
	b.floor_y = floor_y
	b.ceil_y = ceil_y
	b.platforms = platforms
	b.bullet_parent = self
	return b


func _build_extras() -> void:
	_end_layer = CanvasLayer.new()
	_end_layer.layer = 20
	add_child(_end_layer)

	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = Vector2(480, 270)
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_layer.add_child(_black)

	# 录像：原尺寸 444×245 摆在正中，四周一圈黑边像显像管的边框
	_film_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ENDING_SHADER
	_film_mat.shader = sh
	_film = TextureRect.new()
	_film.texture = preload("res://art/boss/hometown.png")
	_film.position = Vector2(18, 10)
	_film.size = Vector2(444, 245)
	_film.material = _film_mat
	_film.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_film.modulate.a = 0.0
	_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_layer.add_child(_film)

	_line = Label.new()
	var ls := Hud.small_text(Color(0.95, 0.92, 0.85))
	ls.outline_size = 4
	ls.outline_color = Color.BLACK
	_line.label_settings = ls
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.position = Vector2(0, 236)
	_line.size = Vector2(480, 14)
	_end_layer.add_child(_line)

	_end_title = Label.new()
	var big := Hud.small_text(Color8(255, 211, 138))
	big.font_size = 33
	big.outline_size = 4
	_end_title.label_settings = big
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.position = Vector2(0, 30)
	_end_title.size = Vector2(480, 40)
	_end_layer.add_child(_end_title)
	_end_sub = Label.new()
	_end_sub.label_settings = Hud.small_text(Color(0.75, 0.72, 0.7))
	_end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_sub.position = Vector2(0, 72)
	_end_sub.size = Vector2(480, 12)
	_end_layer.add_child(_end_sub)

	_hum = AudioStreamPlayer.new()
	var st := Game.load_sound("static").duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	_hum.stream = st
	_hum.volume_db = -60.0
	add_child(_hum)


## 结局，不开门
func _after_defeat() -> void:
	var tv := boss as TVBoss
	await _show_card("", defeat_line)
	_bar.visible = false
	hud.visible = false
	_lock_players()
	await get_tree().create_timer(1.2).timeout

	# 1. 自己重新开机，放录像
	tv.turn_on("home")
	await get_tree().create_timer(2.0).timeout

	# 2. 镜头推进屏幕，录像铺满全屏
	var screen_center := tv.global_position + TVBoss.SCREEN.get_center()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_cam, "zoom", Vector2(6, 6), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_cam, "position", screen_center, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_black, "modulate:a", 1.0, 0.4).set_delay(1.2)
	tw.tween_property(_film, "modulate:a", 1.0, 0.6).set_delay(1.4)
	await tw.finished

	var q := clampf(Run.crystal_hp / maxf(Run.crystal_max, 1.0), 0.0, 1.0)
	var tier := 0 if q > 0.66 else (1 if q > 0.33 else 2)
	# 血量满几乎没有雪花；见底几乎全是雪花
	var noise: float = lerpf(0.92, 0.04, q)
	_film_mat.set_shader_parameter("noise", noise)
	_hum.volume_db = lerpf(-34.0, -10.0, noise)
	_hum.play()
	await get_tree().create_timer(1.5).timeout
	for line in LINES[tier]:
		await _type(_line, line, 0.04)
		await get_tree().create_timer(2.2).timeout
	await _fade_label(_line)
	await get_tree().create_timer(0.6).timeout

	# 3. 最后一个镜头：四个人围着电视坐
	var out := create_tween()
	out.tween_property(_film, "modulate:a", 0.0, 1.2)
	out.parallel().tween_property(_hum, "volume_db", -60.0, 1.2)
	await out.finished
	_hum.stop()
	_final_shot(tv)
	await get_tree().create_timer(0.8).timeout
	var back := create_tween()
	back.tween_property(_black, "modulate:a", 0.0, 2.5)
	await back.finished
	await get_tree().create_timer(1.6).timeout
	await _type(_end_title, "THE END", 0.12)
	Game.add_shake(2.0)
	await get_tree().create_timer(0.6).timeout
	await _type(_end_sub, "Scrap Rush  -  thanks for playing", 0.035)
	await get_tree().create_timer(2.5).timeout
	_can_quit = true


func _final_shot(tv: TVBoss) -> void:
	for n in get_tree().get_nodes_in_group("player"):
		n.queue_free()
	for n in get_children():
		if n is Crystal:
			n.queue_free()
	_dark.color = Color(0.07, 0.07, 0.09)
	tv.screen_mode = "home"
	# 四个人坐在电视前的地上，面朝电视（脸朝右），只露上半身
	var seats := [Vector2(118, floor_y), Vector2(134, floor_y), Vector2(152, floor_y), Vector2(168, floor_y)]
	for i in Run.SKINS.size():
		for part in ["body", "strip"]:
			var sp := Sprite2D.new()
			sp.texture = load("res://art/chars/%s_%s.png" % [Run.SKINS[i], part])
			sp.hframes = 7
			sp.frame = i % 4
			sp.centered = false
			sp.region_enabled = true
			sp.region_rect = Rect2(0, 0, 16 * 7, Player.FRAME_SIZE.y - 6)
			sp.offset = Vector2(-8, -Player.FRAME_SIZE.y + 6)
			sp.position = seats[i]
			sp.z_index = 2
			if part == "strip":
				var unshaded := CanvasItemMaterial.new()
				unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
				sp.material = unshaded
			add_child(sp)
	_cam.zoom = Vector2(2.2, 2.2)
	_cam.position = Vector2(204, floor_y - 46)


func _lock_players() -> void:
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		p.velocity.x = 0.0
		p.set_physics_process(false)
		p.set_process_unhandled_input(false)


func _type(label: Label, text: String, step: float) -> void:
	label.modulate.a = 1.0
	label.text = ""
	for i in text.length():
		label.text = text.substr(0, i + 1)
		if text[i] != " " and step >= 0.1:
			Game.sfx("ui_move", -8.0, 0.8)
		await get_tree().create_timer(step).timeout


func _fade_label(label: Label) -> void:
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 0.0, 0.6)
	await tw.finished


func _unhandled_input(event: InputEvent) -> void:
	if _can_quit and event.is_pressed() and not event.is_echo():
		_can_quit = false
		Run.reset_run()
		Game.flash(Color.BLACK, 1.0, 0.6)
		get_tree().change_scene_to_file("res://scenes/title.tscn")
		return
	# 结局里不许按 R 重打
	if _state < 3:
		super._unhandled_input(event)
