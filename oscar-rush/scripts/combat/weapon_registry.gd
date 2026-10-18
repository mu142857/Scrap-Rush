class_name WeaponRegistry
extends RefCounted
## 所有武器的登记表（10-18 作者："武器可以多做几个"，开局 7 选 1）。加一把新武器 = 在 LIST 里加一行 + 写一个 WeaponHandler 脚本。
## 选武器界面、商店、暂停菜单、结算、底部提示、新手提示、变异（回声 / 从闪的频率）都从这里读，不用再去各处加 match。
## 老的三把（闪光灯、铆钉枪、蒸汽锤）的出招还写在 player.gd 里，handler 留空；新武器的出招都在各自的 handler 脚本里。
##
## 每一行的键：
##   id        武器 id（存在 Run.players[i]["weapon"] / Upgrades.weapon 里）
##   name      名字（英文，也是 text.csv 的键）
##   icon      res://art/shop/icons.png 里的图标名（ShopStand.ICON_NAMES 里的名字）
##   card      选武器界面说明面板的两三行（英文，text.csv 的键，用 \n 换行）
##   trait     一句独特特性（英文，text.csv 的键）
##   stats     [威力, 射速, 射程]，1~5 格
##   glows     发不发光（扑灯蛾会不会被引过来；只用来显示，真正的发光由武器自己设 p.charging）
##   handler   出招脚本的路径（extends WeaponHandler）；"" = 写在 player.gd 里的老武器
##   hint      底部操作提示（%s = 攻击键名；text.csv 的键）
##   coach     第一次遇到怪时的新手提示（%s = 攻击键名；text.csv 的键）
##   shop      商店货架上的一行小字（text.csv 的键）
##   echo_every / slave_every：变异"磁带回声""从闪"每几发触发一次（射得快的武器要降频，见 mutations.gd）
##   slave_damage：从闪补的那一发光球的伤害
##   ready     做好了没有（false = 选武器界面和商店都不摆出来）
##   qa_press / qa_range：tools/qa/elite_regression.gd 站桩测打死时间时怎么按（hold / tap / charge）、站多远

const LIST := [
	{"id": "flash", "name": "FLASH LAMP", "icon": "charge",
		"card": "Hold to charge.\nFull shots pierce\na whole row.", "trait": "Homes in. Moths chase the light.",
		"stats": [4, 2, 5], "glows": true, "handler": "",
		"hint": "Hold %s: charge, release: shoot", "coach": "Hold %s to charge,  release to shoot.  Watch the ring fill",
		"shop": "hold to charge, full shot pierces", "echo_every": 1, "slave_every": 1, "slave_damage": 40.0, "ready": true},
	{"id": "rivet", "name": "RIVET GUN", "icon": "rivet",
		"card": "Hold to fire\nnonstop. Small hits,\nshort range.", "trait": "Sweeps up and down like a heavy MG.",
		"stats": [1, 5, 3], "glows": false, "handler": "",
		"hint": "Hold %s: fire", "coach": "Hold %s to fire nonstop",
		"shop": "hold to fire nonstop", "echo_every": 3, "slave_every": 4, "slave_damage": 25.0, "ready": true},
	{"id": "hammer", "name": "STEAM HAMMER", "icon": "hammer",
		"card": "Tap: blast all\naround you. Wipes\nbullets. Slow.", "trait": "Launches small fry. Blows bullets away.",
		"stats": [5, 1, 2], "glows": false, "handler": "",
		"hint": "%s: steam blast", "coach": "Tap %s: steam blast all around you  (it needs to cool down)",
		"shop": "steam blast all around you", "echo_every": 1, "slave_every": 1, "slave_damage": 45.0, "ready": true},
	{"id": "shotgun", "qa_press": "hold", "qa_range": 40.0, "name": "SCRAP SHOTGUN", "icon": "shotgun",
		"card": "Tap: a fan of\nscrap. Huge up close.\nKicks you back.", "trait": "Shoot down in the air to hop.",
		"stats": [4, 3, 2], "glows": false, "handler": "res://scripts/combat/weapons/shotgun.gd",
		"hint": "%s: blast (in the air: kick)", "coach": "Tap %s: blast a fan of scrap.  In the air the kick moves you",
		"shop": "a fan of scrap, kicks you back", "echo_every": 1, "slave_every": 1, "slave_damage": 40.0, "ready": true},
	{"id": "laser", "qa_press": "hold", "qa_range": 90.0, "name": "CRT LASER", "icon": "laser",
		"card": "Hold: the tube warms\nup, then the beam\nsweeps. Pierces all.", "trait": "Keep holding to sweep. Burns bullets.",
		"stats": [5, 1, 5], "glows": true, "handler": "res://scripts/combat/weapons/laser.gd",
		"hint": "Hold %s: warm up, keep holding: sweep", "coach": "Hold %s: the tube lights up, then the beam sweeps through them all",
		"shop": "a sweeping beam, pierces all", "echo_every": 1, "slave_every": 1, "slave_damage": 45.0, "ready": true},
	{"id": "record", "qa_press": "tap", "qa_range": 60.0, "name": "RECORD SLINGER", "icon": "record",
		"card": "Throw a record.\nIt flies back and\ncuts both ways.", "trait": "Catch it to throw again.",
		"stats": [3, 3, 4], "glows": false, "handler": "res://scripts/combat/weapons/record.gd",
		"hint": "%s: throw a record", "coach": "Tap %s: throw a record.  It comes back - catch it",
		"shop": "a record that flies back", "echo_every": 1, "slave_every": 1, "slave_damage": 40.0, "ready": true},
	{"id": "tongs", "qa_press": "hold", "qa_range": 80.0, "name": "TESLA TONGS", "icon": "tongs",
		"card": "Hold: arcs jump\nfrom foe to foe.\nNo aiming.", "trait": "Stuns small fry. Glows.",
		"stats": [2, 4, 3], "glows": true, "handler": "res://scripts/combat/weapons/tongs.gd",
		"hint": "Hold %s: arc", "coach": "Hold %s: the arc finds them and jumps between them",
		"shop": "arcs jump between foes", "echo_every": 3, "slave_every": 4, "slave_damage": 25.0, "ready": true},
]


static func ids(only_ready := true) -> Array[String]:
	var out: Array[String] = []
	for w in LIST:
		if w["ready"] or not only_ready:
			out.append(w["id"])
	return out


static func get_def(id: String) -> Dictionary:
	for w in LIST:
		if w["id"] == id:
			return w
	return {}


static func has(id: String) -> bool:
	return not get_def(id).is_empty()


## 名字（没翻译的原文；显示时外面再套 tr()）
static func name_of(id: String) -> String:
	return get_def(id).get("name", id.to_upper())


static func handler_path(id: String) -> String:
	return get_def(id).get("handler", "")


static func value(id: String, key: String, default: Variant = null) -> Variant:
	return get_def(id).get(key, default)
