"""程序合成的旧机器音效（闪光灯充电、蒸汽、齿轮、马灯……）。

用法：python3 tools/gen_sfx.py
输出 sfx/*.wav，单声道 22050Hz 16 位。数值改了就重跑。
"""
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "sfx"
rng = np.random.default_rng(7)


def t(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def env(n: int, attack=0.005, release=0.05) -> np.ndarray:
    e = np.ones(n)
    a, r = int(SR * attack), int(SR * release)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def decay(n: int, k: float) -> np.ndarray:
    return np.exp(-np.arange(n) / SR * k)


def sweep(f0: float, f1: float, dur: float, curve="exp") -> np.ndarray:
    tt = t(dur)
    if curve == "exp":
        f = f0 * (f1 / f0) ** (tt / dur)
    else:
        f = f0 + (f1 - f0) * tt / dur
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(dur: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x: np.ndarray, a: float) -> np.ndarray:
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def highpass(x: np.ndarray, a: float) -> np.ndarray:
    return x - lowpass(x, a)


def write(name: str, x: np.ndarray, gain=0.8) -> None:
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    OUT.mkdir(exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("wrote", name, f"{len(x) / SR:.2f}s")


# 闪光灯充电：越来越尖的"嘀——"，带一点电容的嗡嗡声。长度 0.8 秒 = 默认蓄满时间
def charge():
    d = 0.8
    whine = sweep(700, 3600, d) * 0.6 + sweep(1400, 7200, d) * 0.12
    hum = np.sign(np.sin(2 * np.pi * 120 * t(d))) * 0.05
    trem = 1 + 0.15 * np.sin(2 * np.pi * 30 * t(d))
    return (whine * trem + hum) * env(len(whine), 0.02, 0.01)


# 蓄满："叮"
def ready():
    d = 0.35
    x = np.sin(2 * np.pi * 2600 * t(d)) + 0.5 * np.sin(2 * np.pi * 5230 * t(d))
    return x * decay(len(x), 14)


# 发射：闪光灯"啪"
def shoot():
    d = 0.16
    pop = noise(d) * decay(int(SR * d), 45)
    chirp = sweep(2400, 300, d) * decay(int(SR * d), 20)
    return highpass(pop, 0.3) * 0.7 + chirp * 0.5


# 打中：闷响加一声金属
def hit():
    d = 0.18
    thud = np.sin(2 * np.pi * 110 * t(d)) * decay(int(SR * d), 22)
    clank = (np.sin(2 * np.pi * 1310 * t(d)) + np.sin(2 * np.pi * 2170 * t(d))) * decay(int(SR * d), 40)
    click = noise(d) * decay(int(SR * d), 120)
    return thud + clank * 0.3 + click * 0.4


# 怪碎掉：一串不协和的金属零件声
def scrap():
    d = 0.5
    x = np.zeros(int(SR * d))
    for f, k, off in [(523, 9, 0), (1307, 12, 0.03), (2210, 16, 0.07), (887, 10, 0.12), (3120, 22, 0.16)]:
        s = int(SR * off)
        seg = np.sin(2 * np.pi * f * t(d - off)) * decay(int(SR * (d - off)), k)
        x[s:s + len(seg)] += seg
    x += lowpass(noise(d), 0.2) * decay(len(x), 18) * 0.6
    return x


# 起跳：弹簧"嘣"一小下
def jump():
    d = 0.09
    return sweep(220, 520, d) * decay(int(SR * d), 30) * 0.7 + highpass(noise(d), 0.5) * decay(int(SR * d), 80) * 0.3


# 落地
def land():
    d = 0.12
    return lowpass(noise(d), 0.08) * decay(int(SR * d), 35) + np.sin(2 * np.pi * 70 * t(d)) * decay(int(SR * d), 30)


# 喷气靴：气阀放气的"嘶——"，圆滑不刺耳。2 秒，首尾交叉淡化，可以无缝循环。
# 2026-10-17 试玩：原来的"突突突"太吵，换成这个。
def jet():
    d, fade_d = 2.0, 0.3
    n, f = int(SR * d), int(SR * fade_d)
    raw = rng.uniform(-1, 1, n + f)
    # 去掉最低的轰鸣和最高的刺声，只留中间柔和的一段气流声
    air = lowpass(highpass(raw, 0.08), 0.22)
    air = lowpass(air, 0.35)
    tt = np.arange(len(air)) / SR
    # 气流强弱慢慢起伏，听起来像真在放气，不是死板的白噪声
    air *= 1.0 + 0.12 * np.sin(2 * np.pi * 2.5 * tt) + 0.06 * np.sin(2 * np.pi * 6.1 * tt + 1.0)
    out = air[:n].copy()
    ramp = np.linspace(0, 1, f)
    out[:f] = air[:f] * ramp + air[n:n + f] * (1 - ramp)
    return out


# 马灯：拎起 / 放下的玻璃和铁环声
def lantern_pick():
    d = 0.25
    x = np.sin(2 * np.pi * 3100 * t(d)) + 0.6 * np.sin(2 * np.pi * 4370 * t(d))
    return x * decay(int(SR * d), 25) + highpass(noise(d), 0.5) * decay(int(SR * d), 90) * 0.4


def lantern_drop():
    d = 0.3
    thunk = lowpass(noise(d), 0.1) * decay(int(SR * d), 30)
    ring = np.sin(2 * np.pi * 2450 * t(d)) * decay(int(SR * d), 18) * 0.5
    return thunk + ring


# 主角挨打
def hurt():
    d = 0.25
    crunch = lowpass(noise(d), 0.3) * decay(int(SR * d), 14)
    drop = sweep(400, 90, d) * decay(int(SR * d), 10)
    return crunch * 0.8 + drop * 0.6


# 水晶受损：玻璃裂开
def crack():
    d = 0.35
    x = np.zeros(int(SR * d))
    for off in [0, 0.025, 0.06, 0.1]:
        s = int(SR * off)
        seg = highpass(noise(0.05), 0.7) * decay(int(SR * 0.05), 60)
        x[s:s + len(seg)] += seg
    x += np.sin(2 * np.pi * 3900 * t(d)) * decay(len(x), 20) * 0.4
    return x


# —— 开始界面 ——
# 换选项：老式拨档开关"嗒"
def ui_move():
    d = 0.06
    click = highpass(noise(d), 0.5) * decay(int(SR * d), 140)
    tone = np.sin(2 * np.pi * 1450 * t(d)) * decay(int(SR * d), 60)
    return click * 0.6 + tone * 0.5


# 确认：继电器吸合"咔哒"加一声上扬的电子音
def ui_confirm():
    d = 0.35
    x = np.zeros(int(SR * d))
    clack = highpass(noise(0.03), 0.4) * decay(int(SR * 0.03), 150)
    x[:len(clack)] += clack
    s = int(SR * 0.04)
    up = sweep(660, 1320, d - 0.04) * decay(int(SR * (d - 0.04)), 9)
    x[s:s + len(up)] += up * 0.6
    return x


# 返回：往下走的电子音
def ui_back():
    d = 0.18
    return sweep(900, 380, d) * decay(int(SR * d), 14)


# 标题亮起：老灯管通电，先"嗒"一声，接着 50Hz 的嗡嗡声慢慢消失
def title_on():
    d = 1.2
    n = int(SR * d)
    x = np.zeros(n)
    for off in [0.0, 0.09, 0.16]:  # 灯管闪了三下才亮稳
        s = int(SR * off)
        c = highpass(noise(0.025), 0.4) * decay(int(SR * 0.025), 120)
        x[s:s + len(c)] += c * 0.8
    hum = np.sign(np.sin(2 * np.pi * 50 * t(d))) * 0.25 + np.sin(2 * np.pi * 100 * t(d)) * 0.25
    hum = lowpass(hum, 0.15)
    env_h = np.minimum(t(d) / 0.18, 1.0) * np.exp(-t(d) * 2.5)
    x += hum * env_h
    return x


# 多人加入：两声往上的提示音
def join():
    d = 0.22
    a = np.sin(2 * np.pi * 880 * t(0.09)) * decay(int(SR * 0.09), 30)
    b = np.sin(2 * np.pi * 1320 * t(0.13)) * decay(int(SR * 0.13), 22)
    return np.concatenate([a, b])


# 多人退出：两声往下
def leave():
    a = np.sin(2 * np.pi * 1100 * t(0.08)) * decay(int(SR * 0.08), 30)
    b = np.sin(2 * np.pi * 660 * t(0.12)) * decay(int(SR * 0.12), 22)
    return np.concatenate([a, b])


# —— 第一关 Boss「司炉」 ——
# 蒸汽汽笛：两个不协和的音一起响，像老火车
def whistle():
    d = 1.4
    tt = t(d)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * tt)
    a = np.sin(2 * np.pi * np.cumsum(np.full(len(tt), 466.0) * vib) / SR)
    b = np.sin(2 * np.pi * np.cumsum(np.full(len(tt), 587.0) * vib) / SR)
    air = highpass(noise(d), 0.3) * 0.25
    e = np.minimum(tt / 0.08, 1.0) * np.minimum((d - tt) / 0.4, 1.0)
    return (a * 0.5 + b * 0.4 + air) * e


# 爆炸：低频闷响 + 碎片噪声
def boom():
    d = 0.9
    thump = sweep(120, 35, d) * decay(int(SR * d), 5)
    debris = lowpass(noise(d), 0.25) * decay(int(SR * d), 6)
    return thump + debris * 0.7


# 铆钉齐射：一串金属"叮"
def rivets():
    d = 0.35
    x = np.zeros(int(SR * d))
    for i in range(6):
        s = int(SR * i * 0.012)
        f = 2400 + i * 180
        seg = np.sin(2 * np.pi * f * t(d - i * 0.012)) * decay(int(SR * (d - i * 0.012)), 30)
        x[s:s + len(seg)] += seg * 0.5
    x[:int(SR * 0.03)] += highpass(noise(0.03), 0.4) * decay(int(SR * 0.03), 100)
    return x


# 烟囱喷余烬："噗"
def embers():
    d = 0.45
    puff = lowpass(noise(d), 0.12) * decay(int(SR * d), 9)
    crackle = np.zeros(int(SR * d))
    for _ in range(14):
        s = rng.integers(0, int(SR * (d - 0.02)))
        c = highpass(noise(0.01), 0.6) * decay(int(SR * 0.01), 300)
        crackle[s:s + len(c)] += c * 0.5
    return puff + crackle


# 蒸汽喷口：一大股"嘶——"
def vent():
    d = 1.1
    air = lowpass(highpass(noise(d), 0.1), 0.5)
    e = np.minimum(t(d) / 0.04, 1.0) * np.exp(-t(d) * 2.2)
    return air * e


# 铲煤：铁铲刮地
def scrape():
    d = 0.6
    grind = highpass(noise(d), 0.2) * (0.6 + 0.4 * np.sin(2 * np.pi * 37 * t(d)))
    tone = np.sin(2 * np.pi * 180 * t(d)) * 0.3
    return (grind + tone) * env(int(SR * d), 0.02, 0.2)


# 炉门吸气：低沉的轰鸣，2 秒，可以循环
def suction():
    d = 2.0
    n = int(SR * d)
    rumble = lowpass(noise(d), 0.03) * 2.5
    roar = lowpass(noise(d), 0.15) * (0.5 + 0.2 * np.sin(2 * np.pi * 3 * t(d)))
    x = rumble + roar
    f = int(SR * 0.05)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    return x


# 闸门砸下："哐"
def clang():
    d = 0.8
    x = np.zeros(int(SR * d))
    for f, k in [(180, 6), (412, 8), (733, 10), (1210, 14)]:
        x += np.sin(2 * np.pi * f * t(d)) * decay(int(SR * d), k)
    x += lowpass(noise(d), 0.2) * decay(int(SR * d), 20) * 1.5
    return x


# 压力表归零："叮"
def ding():
    d = 1.0
    x = np.sin(2 * np.pi * 1760 * t(d)) + 0.4 * np.sin(2 * np.pi * 4400 * t(d))
    return x * decay(int(SR * d), 4)


# 警报：两音交替的老式警笛，1 秒
def alarm():
    d = 1.0
    tt = t(d)
    f = np.where((tt * 4).astype(int) % 2 == 0, 660.0, 520.0)
    sq = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR))
    return lowpass(sq, 0.25) * env(len(tt), 0.01, 0.05)


if __name__ == "__main__":
    for fn in [charge, ready, shoot, hit, scrap, jump, land, jet, lantern_pick, lantern_drop, hurt, crack,
               ui_move, ui_confirm, ui_back, title_on, join, leave,
               whistle, boom, rivets, embers, vent, scrape, suction, clang, ding, alarm]:
        write(fn.__name__, fn())
