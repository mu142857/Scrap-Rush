class_name DevMode
extends CanvasLayer
## F1 无敌（随时能按，不用开面板）：主角不受伤、马灯不掉血，左下角一直标着 INVINCIBLE。
## 开发者模式：任何场景按 F8 开关，右上角出一个面板。打开时下面这些键才有用：
##   1 第一关  2 第一关 Boss 房  3 商店  4 开始界面
##   P 零件 +5   H 马灯回满   G 马灯打不碎（开/关）   K 杀掉画面里所有怪
##   U 装备全满级   [ ] 情绪 -25 / +25   T 慢动作（0.25 倍，开/关）
## 挂在 Game 下面，换场景也一直在。开始界面原来的"F8 进 Boss 房"改成这里的 2。

const SCENES := {
	KEY_1: "res://scenes/test_level.tscn",
	KEY_2: "res://scenes/boss1.tscn",
	KEY_3: "res://scenes/shop.tscn",
	KEY_4: "res://scenes/title.tscn",
}
const HELP := "F1 invincible   1 Level 1   2 Boss   3 Shop   4 Title\nP +5 parts   H fill lantern   G unbreakable lantern\nK kill all   U max gear   [ ] emotion -/+   T slow-mo"

var on := false
var god := false
var slow := false

var _panel: ColorRect
var _label: Label
var _badge: Label


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = ColorRect.new()
	_panel.color = Color(0.02, 0.02, 0.03, 0.72)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_label = Label.new()
	_label.label_settings = Hud.small_text(Color(0.75, 1.0, 0.75))
	_label.position = Vector2(4, 2)
	_panel.add_child(_label)
	_panel.visible = false
	_badge = Label.new()
	_badge.label_settings = Hud.small_text(Color(1.0, 0.85, 0.3))
	_badge.text = "INVINCIBLE (F1)"
	_badge.position = Vector2(6, 240)
	_badge.visible = false
	add_child(_badge)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_F1:
		Game.invincible = not Game.invincible
		_badge.visible = Game.invincible
		get_viewport().set_input_as_handled()
		return
	if k.physical_keycode == KEY_F8:
		on = not on
		_panel.visible = on
		get_viewport().set_input_as_handled()
		return
	if not on:
		return
	var used := true
	match k.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			Engine.time_scale = 1.0
			slow = false
			get_tree().paused = false
			if Run.players.is_empty():
				Run.players = [{"input": "solo", "skin": Run.SKINS[0]}]
			if k.physical_keycode == KEY_3:
				ShopRoom.next_scene = "res://scenes/title.tscn"
			get_tree().change_scene_to_file(SCENES[k.physical_keycode])
		KEY_P:
			Run.add_part(5)
		KEY_H:
			_fill_lantern()
		KEY_G:
			god = not god
		KEY_K:
			for n in get_tree().get_nodes_in_group("enemy"):
				if n.has_method("hurt") and (not n.has_method("is_targetable") or n.is_targetable()):
					n.hurt(99999.0, Vector2.RIGHT, true)
		KEY_U:
			for id in Upgrades.GEAR:
				Upgrades.levels[id] = Upgrades.MAX_LEVEL
			for n in get_tree().get_nodes_in_group("player"):
				Upgrades.apply(n as Player)
		KEY_BRACKETLEFT:
			Run.add_emotion(-25.0)
		KEY_BRACKETRIGHT:
			Run.add_emotion(25.0)
		KEY_T:
			slow = not slow
			Engine.time_scale = 0.25 if slow else 1.0
		_:
			used = false
	if used:
		get_viewport().set_input_as_handled()


func _fill_lantern() -> void:
	Run.crystal_hp = Run.crystal_max
	Run.crystal_changed.emit(Run.crystal_hp, Run.crystal_max)


func _process(_delta: float) -> void:
	if god and Run.crystal_hp < Run.crystal_max:
		_fill_lantern()
	if not on:
		return
	var cur := get_tree().current_scene
	var scene_name := cur.scene_file_path.get_file().get_basename() if cur else "-"
	var flags := ""
	if Game.invincible:
		flags += "  [INVINCIBLE]"
	if god:
		flags += "  [UNBREAKABLE]"
	if slow:
		flags += "  [SLOW]"
	_label.text = "DEV MODE (F8)%s\n%s  %d fps   emotion %d (tier %d)   parts %d   lantern %d/%d\n%s" % [
		flags, scene_name, Engine.get_frames_per_second(), int(Run.emotion), EnemyBase.emotion_tier(),
		Run.parts, ceili(Run.crystal_hp), int(Run.crystal_max), HELP]
	var size := _label.get_minimum_size() + Vector2(8, 4)
	_panel.size = size
	var vp := get_viewport().get_visible_rect().size
	_panel.position = Vector2(vp.x - size.x - 4, 4)
