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


if __name__ == "__main__":
    for fn in [charge, ready, shoot, hit, scrap, jump, land, jet, lantern_pick, lantern_drop, hurt, crack]:
        write(fn.__name__, fn())
