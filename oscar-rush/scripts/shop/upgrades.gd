class_name Upgrades
extends RefCounted
## 商店买到的东西（策划案第十节）。跨关卡保留，新开一局（Run.reset_run）清零。
## 全是静态变量，不用再加 autoload。

const MAX_LEVEL := 3
const GEAR: Array[String] = ["charge", "fuel", "plating", "damping"]
## 能拿到的武器（开局三选一，商店里摆另外两把可以换）。电击钳、留声机喇叭还没做，先不上架
const WEAPONS: Array[String] = ["flash", "rivet", "hammer"]
const MUTATIONS: Array[String] = ["rage", "slave", "echo", "dynamo"]
const PRICE := {"gear": 1, "repair": 1, "mutation": 2, "weapon": 3, "refresh": 1}
const REPAIR_AMOUNT := 25.0
## 镀层：每隔这么多秒挡一次对水晶的伤害（按等级 0~3）
const PLATING_INTERVAL: Array[float] = [0.0, 20.0, 15.0, 10.0]
## 阻尼：情绪随时间上涨的速度，每级 -20%
const DAMPING_PER_LEVEL := 0.2

## 已经做进游戏的武器和变异。没做的照样摆出来，但标 COMING SOON、买不了，免得卖出去没效果。
## 做好一把就把名字加进来。
static var implemented_weapons: Array[String] = ["flash", "rivet", "hammer"]
static var implemented_mutations: Array[String] = ["rage", "slave", "echo", "dynamo"]

static var levels := {"charge": 0, "fuel": 0, "plating": 0, "damping": 0}
## 身上的武器（开局在 weapon_select 里选，默认闪光灯）和变异（"" 没有）
static var weapon := "flash"
static var mutation := ""
static var _plating_ready := 0.0


static func reset() -> void:
	for k in levels:
		levels[k] = 0
	weapon = "flash"
	mutation = ""
	_plating_ready = 0.0
	Mutations.dynamo_kills = 0


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
	var now := Time.get_ticks_msec() / 1000.0
	if now < _plating_ready:
		return false
	_plating_ready = now + PLATING_INTERVAL[lv]
	return true
