extends BossArena
## 第三关 Boss 房「最深处」：最后一台老电视 THE SET。竞技场 320×180，镜头固定 1.5 倍。
## 老电视长了腿满地跑、冲撞、跳砸，所以场地是"往上躲"：两边墙上一块低搁板（踏脚，挡不住冲撞）→
## 两台吊着的旧电视（高过老电视的壳，冲撞时躲这里）→ 正中最高一台。画在 room3_fg 里。
## 房间没有转灯，只靠电视屏幕的光。
## 打完不开门，直接进结局：
##   1. 电视关机以后安静一会儿，自己重新亮起，开始放录像（家乡）
##   2. 镜头推进屏幕，录像铺满全屏。雪花多少由剩下的水晶血量决定，旁白也分三档
##   3. 切到最后一个镜头：四个人在黑漆漆的废品场里，围着一台发光的电视坐着。THE END → 回标题
## 美术见 tools/draw_boss3.py。

const BOSS_X := 240.0
const ENDING_SHADER := """
shader_type canvas_item;
// 录像的雪花：noise 0~1 由水晶血量决定；fade 控制整体亮度
uniform float noise = 0.2;
uniform float fade = 1.0;
uniform vec2 size = vec2(444.0, 245.0);

// 2026-10-17 夜：原来的 fract(sin(dot(...))) 在显卡上精度不够，雪花成了一道道斜条纹；换成 Dave Hoskins 的 hash12
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

## 墙上两盏壁灯灯罩的位置（room3_bg 里灯罩中心，减掉边距 M）
const SCONCES := [Vector2(245, 101), Vector2(310, 101)]

var _end_layer: CanvasLayer
var _sconces: Array[CanvasItem] = []
var _film: TextureRect
var _film_mat: ShaderMaterial
var _black: ColorRect
var _line: Label
var _end_title: Label
var _end_sub: Label
var _hum: AudioStreamPlayer
var _can_quit := false
## 马灯 95% 以上通关
var _perfect := false


func _configure() -> void:
	bg_tex = preload("res://art/boss/room3_bg.png")
	fg_tex = preload("res://art/boss/room3_fg.png")
	gate_tex = preload("res://art/boss/gate3.png")
	platforms = [Vector3(8, 52, 130), Vector3(268, 312, 130), Vector3(36, 92, 94), Vector3(228, 284, 94), Vector3(134, 186, 62)]
	# 没有转灯：这间屋只有电视屏幕在亮
	lamps = []
	# 夜间打磨：原来 0.24 太暗（第三关会话报告：中位亮度 16/255）
	darkness = Color(0.34, 0.33, 0.38)
	darkness_hot = Color(0.42, 0.3, 0.38)
	boss_tip = "It charges along the floor: jump up onto the hanging TVs"
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
	_hide_overlays()
	_lock_players()
	# 0. 墙上两盏壁灯一盏接一盏亮起来：打的时候这间屋只有电视在亮，沙发、相框都看不见；
	#    打完灯一开，才看出这是一间家里的客厅（2026-10-17 夜，Boss3 房美术巡检）
	if is_inside_tree(): await get_tree().create_timer(0.5).timeout
	for p in SCONCES:
		_sconce_on(p)
		if is_inside_tree(): await get_tree().create_timer(0.45).timeout
	create_tween().tween_property(_dark, "color", Color(0.4, 0.37, 0.38), 0.6)
	if is_inside_tree(): await get_tree().create_timer(1.0).timeout

	# 1. 自己重新开机，放录像
	tv.turn_on("home")
	if is_inside_tree(): await get_tree().create_timer(2.0).timeout

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
	# 雪花按旁白的三档分段，档和档之间有台阶（2026-10-17 夜，商店 / 马灯会话的建议）：
	# 好档几乎干净，中档明显有雪花，差档几乎看不见画面。马灯 95% 以上算满血通关：一点雪花都没有
	_perfect = q >= 0.95
	var noise: float
	if _perfect:
		noise = 0.0
	elif q > 0.66:
		noise = lerpf(0.15, 0.03, (q - 0.66) / 0.34)
	elif q > 0.33:
		noise = lerpf(0.55, 0.35, (q - 0.33) / 0.33)
	else:
		noise = lerpf(0.92, 0.7, q / 0.33)
	_film_mat.set_shader_parameter("noise", noise)
	_hum.volume_db = lerpf(-34.0, -10.0, noise)
	_hum.play()
	if is_inside_tree(): await get_tree().create_timer(1.5).timeout
	var lines: Array = LINES[tier].duplicate()
	if _perfect:
		lines.insert(1, "Not a scratch on the tape.")
	for line in lines:
		await _type(_line, line, 0.04)
		if is_inside_tree(): await get_tree().create_timer(2.2).timeout
	await _fade_label(_line)
	if is_inside_tree(): await get_tree().create_timer(0.6).timeout

	# 3. 最后一个镜头：四个人围着电视坐
	var out := create_tween()
	out.tween_property(_film, "modulate:a", 0.0, 1.2)
	out.parallel().tween_property(_hum, "volume_db", -60.0, 1.2)
	await out.finished
	_hum.stop()
	_final_shot(tv)
	if is_inside_tree(): await get_tree().create_timer(0.8).timeout
	var back := create_tween()
	back.tween_property(_black, "modulate:a", 0.0, 2.5)
	await back.finished
	if is_inside_tree(): await get_tree().create_timer(1.6).timeout
	# 字放高一点，别压到电视天线
	_end_title.position.y = 14
	_end_sub.position.y = 54
	await _type(_end_title, "THE END", 0.12)
	Game.add_shake(2.0)
	if is_inside_tree(): await get_tree().create_timer(0.6).timeout
	await _type(_end_sub, "Scrap Rush  -  thanks for playing", 0.035)
	if _perfect:
		# 满血通关的小奖励：THE END 下面一行暖黄小字
		var lantern := Label.new()
		lantern.label_settings = Hud.small_text(Color8(255, 211, 138))
		lantern.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lantern.position = Vector2(0, 68)
		lantern.size = Vector2(480, 12)
		_end_layer.add_child(lantern)
		if is_inside_tree(): await get_tree().create_timer(0.5).timeout
		await _type(lantern, "LANTERN 100%", 0.05)
	if is_inside_tree(): await get_tree().create_timer(2.5).timeout
	_can_quit = true


func _final_shot(tv: TVBoss) -> void:
	for n in get_tree().get_nodes_in_group("player"):
		n.queue_free()
	for n in get_children():
		if n is Crystal:
			n.queue_free()
		# 最后一个镜头只留老电视和四个人：藏掉竞技场前景（吊着的搁板、旧电视），不然"剧终"压在它们上面
		if n is Sprite2D and (n as Sprite2D).texture == fg_tex:
			n.visible = false
	_dark.color = Color(0.07, 0.07, 0.09)
	# 壁灯只在满血通关时留着（家里有人给我们留了灯）；否则还是只有电视亮着的黑屋
	if not _perfect:
		for n in _sconces:
			n.queue_free()
		_sconces.clear()
	tv.screen_mode = "home"
	# 黑场里把电视挪回房间右边，跪着放录像
	tv.position = Vector2(262, floor_y)
	# 四个人坐在电视前的地上，面朝电视（脸朝右），只露上半身
	# 2026-10-17 夜：原来用走路帧，截掉下半身以后只剩几个钩子；现在都用站立帧截掉腿，坐在地上，
	# 离电视近一点，屏幕前一盏冷白的光把他们照出来（不然暗场里只看得见亮边）
	var seats := [Vector2(196, floor_y), Vector2(208, floor_y - 1), Vector2(221, floor_y), Vector2(233, floor_y - 1)]
	var glow := PointLight2D.new()
	glow.texture = Game.light_texture()
	# 满血通关时屏幕光是暖色（录像一点没坏，像家里的灯），否则是显像管的冷白
	glow.color = Color(1.0, 0.84, 0.62) if _perfect else Color(0.78, 0.84, 1.0)
	glow.energy = 1.1
	glow.texture_scale = 120.0 / 32.0
	glow.position = Vector2(244, floor_y - 18)
	add_child(glow)
	for i in Run.SKINS.size():
		for part in ["body", "strip"]:
			var sp := Sprite2D.new()
			sp.texture = load("res://art/chars/%s_%s.png" % [Run.SKINS[i], part])
			sp.hframes = 7
			sp.frame = 0
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
	# 7/3：窗口 3 倍时每格正好 7 个屏幕像素，像素不会一大一小（原来 2.4，美术巡检）
	var z := GameCamera.pixel_zoom(get_viewport(), 7.0 / 3.0)
	_cam.zoom = Vector2(z, z)
	_cam.position = Vector2(216, floor_y - 40)


## 开一盏壁灯："咔哒"一声，灯罩下面亮一个暖色灯泡，一盏暖光慢慢亮起来
func _sconce_on(at: Vector2) -> void:
	Game.sfx("tvclick", -10.0, 1.4)
	var bulb := ColorRect.new()
	bulb.color = Color(1.0, 0.86, 0.6)
	bulb.position = at + Vector2(-2, 3)
	bulb.size = Vector2(4, 2)
	bulb.z_index = -10   # 在背景（-20）和吊着的旧电视（前景 -5）之间
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	bulb.material = unshaded
	add_child(bulb)
	var l := PointLight2D.new()
	l.texture = Game.light_texture()
	l.color = Color(1.0, 0.78, 0.52)
	l.energy = 0.0
	l.texture_scale = 2.6
	l.position = at + Vector2(0, 6)
	add_child(l)
	create_tween().tween_property(l, "energy", 0.85, 0.35)
	_sconces.append(bulb)
	_sconces.append(l)


## 情绪表和全屏老电视滤镜是 Hud 里另建的画布层（EmotionFx，里面还套着一层放表盘），
## hud.visible = false 藏不掉嵌套的画布层，所以把 Hud 底下的画布层一层层都藏掉
func _hide_overlays() -> void:
	for n in hud.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false


func _lock_players() -> void:
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		p.velocity.x = 0.0
		p.set_physics_process(false)
		p.set_process_unhandled_input(false)


func _type(label: Label, text: String, step: float) -> void:
	text = tr(text)
	label.modulate.a = 1.0
	label.text = ""
	for i in text.length():
		label.text = text.substr(0, i + 1)
		if text[i] != " " and step >= 0.1:
			Game.sfx("ui_move", -8.0, 0.8)
		if is_inside_tree(): await get_tree().create_timer(step).timeout


func _fade_label(label: Label) -> void:
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 0.0, 0.6)
	await tw.finished


func _unhandled_input(event: InputEvent) -> void:
	if _can_quit and event.is_pressed() and not event.is_echo():
		_can_quit = false
		# 先进一局结算（用时、马灯碎了几次、零件……，"游戏细节讨论"会话做的），
		# 结算画面退出时再清掉这一局、回开始界面，所以这里不 reset_run
		SceneFade.go(get_tree(), "res://scenes/results.tscn", 1.2)
		return
	# 结局里不许按 R 重打
	if _state < 3:
		super._unhandled_input(event)
