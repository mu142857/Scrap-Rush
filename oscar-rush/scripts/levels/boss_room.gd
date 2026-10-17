extends BossArena
## 第一关 Boss 房「炉膛间」：司炉 THE STOKER。竞技场 320×180，镜头固定 1.5 倍正好一屏。
## 通用流程（开场、闸门、镜头、血条、打完开门、重来）在 BossArena；这里只填参数、造 Boss、放蒸汽格栅。
## 打完：商店 → 第二关。美术和坐标见 tools/draw_boss_room.py。

const VENTS := [50.0, 128.0, 196.0]
const BOSS_X := 258.0


func _configure() -> void:
	bg_tex = preload("res://art/boss/room_bg.png")
	fg_tex = preload("res://art/boss/room_fg.png")
	platforms = [Vector3(20, 76, 128), Vector3(100, 156, 104), Vector3(30, 86, 78)]
	lamps = [Vector2(80, 16), Vector2(240, 16)]
	boss_name = "THE STOKER"
	card_sub = "It burns what you remember."
	defeat_line = "Somebody else's memories. Burned."
	clear_banner = "BOILER BAY CLEARED"
	next_shop = "res://scenes/level2.tscn"


func _make_boss() -> Node2D:
	var b := Stoker.new()
	b.position = Vector2(BOSS_X, floor_y)
	b.arena = arena
	b.floor_y = floor_y
	b.bullet_parent = self
	return b


func _build_extras() -> void:
	for x in VENTS:
		var v := SteamVent.new()
		v.position = Vector2(x, floor_y)
		v.height = floor_y - ceil_y
		add_child(v)
		(boss as Stoker).vents.append(v)
