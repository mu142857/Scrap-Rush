class_name Upgrades
extends RefCounted
## 商店买到的东西（策划案第十节）。跨关卡保留，新开一局（Run.reset_run）清零。
## 全是静态变量，不用再加 autoload。

const MAX_LEVEL := 3
const GEAR: Array[String] = ["charge", "fuel", "plating", "damping"]
## 能拿到的武器：从武器登记表（WeaponRegistry）来，开局 7 选 1，商店里摆身上没有的。没做好的（ready=false）不摆
static var WEAPONS: Array[String] = WeaponRegistry.ids()
const MUTATIONS: Array[String] = ["rage", "slave", "echo", "dynamo"]
const PRICE := {"gear": 1, "repair": 1, "mutation": 2, "weapon": 3, "refresh": 1}
## 装备按等级涨价（夜间打磨报告第 17 节、拍板清单第 1 条：零件从第二个商店起花不完）：
## 打开后升到 1 级 1 个、2 级 2 个、3 级 3 个，全满要 24 个。默认关，等作者一句话改成 true
static var tiered_gear_price := false


## 装备升到下一级要几个零件（lv 是现在的等级）
static func gear_price(lv: int) -> int:
	return lv + 1 if tiered_gear_price else PRICE["gear"]
const REPAIR_AMOUNT := 25.0
## 镀层：每隔这么多秒挡一次对水晶的伤害（按等级 0~3）
const PLATING_INTERVAL: Array[float] = [0.0, 20.0, 15.0, 10.0]
## 阻尼：情绪随时间上涨的速度，每级 -20%
const DAMPING_PER_LEVEL := 0.2

## 已经做进游戏的武器和变异。没做的照样摆出来，但标 COMING SOON、买不了，免得卖出去没效果。
## 做好一把就把名字加进来。
static var implemented_weapons: Array[String] = WeaponRegistry.ids()
static var implemented_mutations: Array[String] = ["rage", "slave", "echo", "dynamo"]

static var levels := {"charge": 0, "fuel": 0, "plating": 0, "damping": 0}
## 身上的武器（开局在 weapon_select 里选，默认闪光灯）和变异（"" 没有）
## 双人各拿各的武器（作者 10-18）：每个人的武器存在 Run.players[i]["weapon"]，用 weapon_for / set_weapon_for 读写。
## weapon 一直等于 1P 的那把：HUD、新手提示、结算这些只认 1P 的地方照旧读它
static var weapon := "flash"
static var mutation := ""
static var _plating_ready := 0.0


static func reset() -> void:
	for k in levels:
		levels[k] = 0
	weapon = "flash"
	for e in Run.players:
		e.erase("weapon")
	mutation = ""
	_plating_ready = 0.0
	Mutations.dynamo_kills = 0


## 这个输入方案（"solo"、"kb_left"、"pad0"……）的玩家拿的武器；没单独选过就是全局那把
static func weapon_for(input: String) -> String:
	for e in Run.players:
		if e["input"] == input:
			return e.get("weapon", weapon)
	return weapon


static func set_weapon_for(input: String, w: String) -> void:
	for i in Run.players.size():
		if Run.players[i]["input"] == input:
			Run.players[i]["weapon"] = w
			if i == 0:
				weapon = w
			return
	weapon = w


## 有没有人拿着这把武器（Boss 房按武器给提示时用）
static func anyone_has(w: String) -> bool:
	if Run.players.is_empty():
		return weapon == w
	for e in Run.players:
		if e.get("weapon", weapon) == w:
			return true
	return false


static func level(id: String) -> int:
	return levels.get(id, 0)


## 把装备等级套到主角身上（主角 _ready 时、在商店里买完时调）
static func apply(p: Player) -> void:
	p.charge_level = level("charge")
	p.fuel_level = level("fuel")


## 情绪随时间上涨的倍率（做"每 4 秒 +1"的地方乘上它）
static func emotion_rate_mult() -> float:
	return 1.0 - DAMPING_PER_LEVEL * level("damping")


## 水晶要挨打时先问一下镀层：挡下来返回 true（这一下不扣血）
static func plating_block() -> bool:
	var lv := level("plating")
	if lv <= 0:
		return false
	# 按物理帧数算，不用现实时间：卡顿掉帧时不会多走表
	var now := Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)
	if now < _plating_ready:
		return false
	_plating_ready = now + PLATING_INTERVAL[lv]
	return true
