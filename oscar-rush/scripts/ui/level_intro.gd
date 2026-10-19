class_name LevelIntro
extends CanvasLayer
## 三关共用的开场框架（作者 10-18："给游戏加一点动画……都要做出电影感、高级感、流畅的动画"）。
## 第一关：奥斯卡的开场帧（关上、喷蒸汽、打开）；第二关：胶片飞过；第三关：电脑开机。三段共用这里的：
##   - 上下黑边滑进滑出、名字卡（"第一关 · 锅炉间"）、镜头从稍近拉回、按任意键跳过；
##   - 播放时整棵树暂停（关卡停在第一帧，主角不能动），自己 PROCESS_MODE_ALWAYS；reveal() 那一刻就放开暂停、交还控制，
##     名字卡和收黑边叠在跑起来的游戏上播完（不吃按键）。finished 在名字卡放完时发，revealed 在交还控制时发；
##   - 只在一局里第一次进这一关时播：死了重来、存档点重生不播（_played 按场景记，Run.reset_run 清掉）；
##   - 无界面（headless）、带调试参数、设了 SCRAP_NO_LEVEL_INTRO=1 时不播，别的会话的自动测试不会卡住。
##
## 用法（关卡 _ready 最后，镜头和主角都建好以后）：
##   if LevelIntro.should_play(self):
##       var intro := LevelIntro.make(1, "BOILER BAY", my_content)
##       add_child(intro)        # 挂在关卡下面就行
##       await intro.finished    # 可以不等
## my_content：一个 Node（Control / Node2D 都行），有 func run(intro: LevelIntro) -> void（可以 await）。
##   它会被加在黑边下面、名字卡下面。开场一开始是黑底盖着关卡；
##   内容播到"该露出关卡"的那一刻调 intro.reveal()：撤黑底、镜头拉回、名字卡淡入。run() 结束后内容自己会被删掉。
##   不调 reveal() 的话，run() 结束时自动 reveal。
##   想让黑底一开始就不盖（比如第一关是在关卡画面上"关上"），make 之后设 intro.start_covered = false。
##   intro.impact(强度)：关上那一下的冲击（整块画面抖 + 低沉的轰声 + 一下闪白），内容里随时可以调。
##   intro.skipped：被跳过了没有（内容里的循环可以看它提前结束）。
## 播完 / 跳过都发 finished。

signal finished
## 露出关卡、交还控制的那一刻
signal revealed

const LAYER := 45
const BAR_H := 24.0
const BAR_IN := 0.35
const BAR_OUT := 0.45
## 撤黑底以后镜头从这么近拉回原来的大小
const PULL_FROM := 1.12
const PULL_TIME := 0.9
## 露出关卡以后过这么久开始收黑边
const BARS_AFTER := 0.5
const CARD_IN := 0.4
const CARD_HOLD := 1.0
const CARD_OUT := 0.4
const WARM := Color8(255, 211, 138)
## 名字卡上沿（黑边下面一点）
const CARD_Y := 40.0

## 这一局已经播过开场的场景（场景路径 → true）。Run.reset_run 清空
static var _played := {}

var level_no := 1
var level_name := ""
var content: Node
var start_covered := true
var skipped := false

var _black: ColorRect
var _top: ColorRect
var _bottom: ColorRect
var _card: Control
var _shake_root: Control
var _flash: ColorRect
var _revealed := false
var _done := false
var _cam: Camera2D
var _cam_zoom := Vector2.ONE
var _was_paused := false
var _tweens: Array[Tween] = []
var _pulling: GameCamera


## 这一关该不该播开场：一局里第一次进、不是重来、不是测试
static func should_play(level: Node) -> bool:
	if DisplayServer.get_name() == "headless" or OS.get_environment("SCRAP_NO_LEVEL_INTRO") == "1":
		return false
	if Engine.get_write_movie_path() != "" and OS.get_environment("SCRAP_LEVEL_INTRO") != "1":
		return false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg != "--no-autopause":
			return false
	var path := level.scene_file_path
	if _played.has(path):
		return false
	return true


static func make(no: int, name: String, what: Node = null) -> LevelIntro:
	var i := LevelIntro.new()
	i.level_no = no
	i.level_name = name
	i.content = what
	return i


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 名字卡放完之前算"屏幕上有大字"：Hud.show_banner 排队、coach 的新手提示和路牌先让开（和精英名字卡同一个组）
	add_to_group("name_card")
	var level := get_parent()
	if level:
		_played[level.scene_file_path if level.scene_file_path != "" else str(level.get_path())] = true
		# 趁开场盖着，把关卡里的材质都画一遍，让网页版先编好着色器（不然进遭遇战第一次画到时顿 50ms+）
		MaterialWarmer.warm(level)
	_was_paused = get_tree().paused
	get_tree().paused = true
	_shake_root = Control.new()
	_shake_root.size = Vector2(480, 270)
	_shake_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shake_root)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = Vector2(480, 270)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.visible = start_covered
	_shake_root.add_child(_black)
	if content:
		_shake_root.add_child(content)
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.95, 0.85, 0)
	_flash.size = Vector2(480, 270)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_root.add_child(_flash)
	_top = _bar(-BAR_H)
	_bottom = _bar(270.0)
	_card = _make_card()
	add_child(_card)
	_cam = get_viewport().get_camera_2d()
	if _cam:
		_cam_zoom = _cam.zoom
	_run.call_deferred()


func _bar(y: float) -> ColorRect:
	var b := ColorRect.new()
	b.color = Color.BLACK
	b.size = Vector2(480, BAR_H)
	b.position = Vector2(0, y)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	return b


## 名字卡：小字"第一关"，下面暖黄大字关卡名，上下各一条细线，从中间往两边拉开。
## 放在画面上三分之一（CARD_Y），不压在画面中间的主角身上
func _make_card() -> Control:
	var c := Control.new()
	c.size = Vector2(480, 270)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.modulate.a = 0.0
	var small := Label.new()
	small.label_settings = Hud.small_text(Color(0.78, 0.76, 0.73))
	small.text = tr("TAPE %d · %s" % [level_no, ["STEAM", "SIGNAL", "STATIC"][level_no - 1]]) if level_no in [1, 2, 3] else tr("LEVEL %d" % level_no)   # 10-19 改名 REWIND RUSH：三关是三盘录像带（text.csv "TAPE 1 · STEAM" 等，剧情会话改）
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.position = Vector2(0, CARD_Y + 4)
	small.size = Vector2(480, 14)
	c.add_child(small)
	var big := Label.new()
	var st := Hud.small_text(WARM)
	st.font_size = 22
	st.outline_size = 4
	big.label_settings = st
	big.text = tr(level_name)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.position = Vector2(0, CARD_Y + 20)
	big.size = Vector2(480, 28)
	c.add_child(big)
	var lines := Control.new()
	lines.size = Vector2(480, 270)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.set_meta("k", 0.0)
	lines.draw.connect(func() -> void:
		var k: float = lines.get_meta("k")
		var half := roundf(70.0 * k)
		for y in [CARD_Y, CARD_Y + 53.0]:
			lines.draw_rect(Rect2(240.0 - half, y, half * 2.0, 1.0), Color(WARM, 0.55)))
	c.add_child(lines)
	c.set_meta("lines", lines)
	return c


func _tw() -> Tween:
	var t := create_tween().set_ignore_time_scale(true)
	_tweens.append(t)
	return t


func _wait(t: float) -> void:
	if skipped:
		return
	await get_tree().create_timer(t, true, false, true).timeout


func _run() -> void:
	var t := _tw().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_top, "position:y", 0.0, BAR_IN)
	t.tween_property(_bottom, "position:y", 270.0 - BAR_H, BAR_IN)
	if content and content.has_method("run"):
		await content.call("run", self)
	if _done:
		return
	if not _revealed:
		reveal()
	if is_instance_valid(content):
		content.queue_free()
	# 名字卡放完再收尾（这时游戏早就在跑了，见 reveal）
	await _wait(maxf(CARD_IN + CARD_HOLD + CARD_OUT, BARS_AFTER + BAR_OUT) + 0.05)
	_finish()


## 露出关卡：撤黑底、马上放开暂停交还控制（10-18 作者要"流畅"：气动管直接跑起来、主角马上能动），
## 名字卡淡入淡出、黑边收起都叠在跑起来的游戏上播完，不挡按键。
## 镜头从稍近拉回：只有普通的 GameCamera（自己管缩放的，第一关）做；第二关、第三关的镜头每帧自己定缩放，不去抢
func reveal() -> void:
	if _revealed or _done:
		return
	_revealed = true
	_black.visible = false
	get_tree().paused = _was_paused
	revealed.emit()
	if _cam is GameCamera and (_cam as GameCamera).manages_zoom:
		var gc := _cam as GameCamera
		gc.manages_zoom = false
		gc.zoom = _cam_zoom * PULL_FROM
		var pt := _tw()
		pt.tween_property(gc, "zoom", _cam_zoom, PULL_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		pt.tween_callback(func() -> void: gc.manages_zoom = true)
		_pulling = gc
	var bt := _tw().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	bt.tween_property(_top, "position:y", -BAR_H, BAR_OUT).set_delay(BARS_AFTER)
	bt.tween_property(_bottom, "position:y", 270.0, BAR_OUT).set_delay(BARS_AFTER)
	var lines: Control = _card.get_meta("lines")
	var t := _tw()
	t.tween_property(_card, "modulate:a", 1.0, CARD_IN)
	t.parallel().tween_method(func(k: float) -> void:
		lines.set_meta("k", k)
		lines.queue_redraw(), 0.0, 1.0, CARD_IN + 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(CARD_HOLD)
	t.tween_property(_card, "modulate:a", 0.0, CARD_OUT)


## 关上那一下的冲击：整块画面抖几下、低沉的轰声、一下闪白
func impact(strength := 1.0) -> void:
	if skipped:
		return
	Game.sfx("boom", -6.0 + 2.0 * strength, 0.55)
	Game.sfx("clang", -10.0, 0.6)
	_flash.color.a = 0.35 * strength
	_tw().tween_property(_flash, "color:a", 0.0, 0.25)
	var t := _tw()
	for i in 7:
		var k := (1.0 - i / 7.0) * 4.0 * strength
		t.tween_property(_shake_root, "position", Vector2(randf_range(-k, k), randf_range(-k, k)).round(), 0.035)
	t.tween_property(_shake_root, "position", Vector2.ZERO, 0.035)


func _input(event: InputEvent) -> void:
	# 露出关卡以后按键都交给游戏，不再算跳过
	if _done or _revealed:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton \
			or event is InputEventScreenTouch) and event.is_pressed() and not event.is_echo()
	# 播放时所有按键都吞掉，按下的那一下算跳过
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
	if pressed:
		skip()


## 跳过：直接收尾，关卡马上能玩
func skip() -> void:
	if _done:
		return
	skipped = true
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	for t in _tweens:
		if t.is_valid():
			t.kill()
	if _pulling and is_instance_valid(_pulling):
		_pulling.zoom = _cam_zoom
		_pulling.manages_zoom = true
	elif not _revealed and _cam:
		_cam.zoom = _cam_zoom
	# 已经 reveal 过就不再碰暂停（这时可能是玩家自己开了暂停菜单）
	if not _revealed:
		get_tree().paused = _was_paused
	finished.emit()
	queue_free()
