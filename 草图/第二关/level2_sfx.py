"""第二关的两段循环环境音（用 numpy 合成，不用网上素材；不动共享的 tools/gen_sfx.py）。

  sfx/level2_tube_wind.wav       气动管里的风：过滤过的气流噪声，慢慢起伏。游戏里音量、音高跟着胶囊速度走
  sfx/level2_projector_loop.wav  放映机：每秒 24 下的胶片齿轮"咔嗒"（一重一轻），底下一点电机嗡嗡和转动的沙沙声

  sfx/level2_intro.wav           开场动画（scripts/levels/level2_intro.gd）一整条，和画面按同一张时间表对齐：
                                 倒计时每个数字一下咔嗒（"2"那下带一声 1 kHz 的哔）→ 胶片越转越快，每过一个齿孔一下咔嗒，
                                 快到连成一片嗡；电机声跟着升调 → 卡住"咣"一声、片门里打滑咔咔两下 → 烧片的噼啪和嘶声。

前两个都是 2 秒、首尾无缝的循环（游戏里 AudioStreamWAV.loop_mode = LOOP_FORWARD）。
跑法：python3 level2_sfx.py（只做开场动画那条：python3 level2_sfx.py intro）
"""
import math
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path("/Users/jiamulin/Desktop/程序programs/小游戏/Oscar Rush/oscar-rush/sfx")
LEN = 2.0
N = int(SR * LEN)
rng = np.random.default_rng(7)


def lowpass(x, a):
    """一阶低通，a 越小越闷。循环跑两遍，让开头的状态和结尾接上。"""
    y = np.zeros_like(x)
    s = 0.0
    for _ in range(2):
        for i in range(len(x)):
            s += a * (x[i] - s)
            y[i] = s
    return y


def save(x, name):
    x = x / (np.abs(x).max() + 1e-9) * 0.9
    pcm = (x * 32767).astype(np.int16)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("saved", OUT / name)


def tube_wind():
    t = np.arange(N) / SR
    noise = rng.normal(0, 1, N)
    low = lowpass(noise, 0.035)                 # 低沉的气流
    mid = lowpass(noise, 0.18) - lowpass(noise, 0.06)   # 一点点嘶声
    # 慢慢起伏（2 秒里正好 1 个和 3 个周期，首尾接得上）
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * t / LEN) + 0.08 * np.sin(2 * np.pi * 3 * t / LEN)
    return (low * 1.0 + mid * 0.35) * swell


def projector():
    t = np.arange(N) / SR
    out = np.zeros(N)
    clicks = int(24 * LEN)                      # 48 下，正好铺满 2 秒
    burst = int(0.012 * SR)
    for k in range(clicks):
        start = int(k * N / clicks) + int(rng.integers(-20, 20))
        env = np.exp(-np.arange(burst) / (burst * (0.18 if k % 2 == 0 else 0.12)))
        tone = rng.normal(0, 1, burst) * env
        body = np.sin(2 * np.pi * (1800 if k % 2 == 0 else 2600) * np.arange(burst) / SR) * env
        amp = 1.0 if k % 2 == 0 else 0.55       # 一重一轻：咔—嗒
        seg = (tone * 0.6 + body * 0.4) * amp
        idx = (start + np.arange(burst)) % N
        out[idx] += seg
    out = lowpass(out, 0.5)
    hum = 0.10 * np.sin(2 * np.pi * 50 * t) + 0.05 * np.sin(2 * np.pi * 100 * t) + 0.03 * np.sin(2 * np.pi * 150 * t)
    whir = lowpass(rng.normal(0, 1, N), 0.08) * 0.25
    return out + hum + whir


# 开场动画的时间表（和 scripts/levels/level2_intro.gd 的常量一致，改一边要改另一边）
I_LEADER, I_ROLL, I_JAM, I_BURN, I_FADE = 0.9, 2.3, 0.3, 0.45, 0.55
I_DIST, I_K = 2600.0, 3.2          # 胶片一共走多少屏幕像素、加速的弯度
I_PERF = 50.0                      # 一个齿孔在屏幕上的间距（25 像素 × 放大 2 倍）


def roll_offset(u):
    return I_DIST * (math.exp(I_K * u) - 1.0) / (math.exp(I_K) - 1.0)


def click(out, t, amp, tone=1800.0, length=0.010, seed=0):
    r = np.random.default_rng(seed)
    n = int(length * SR)
    i0 = int(t * SR)
    if i0 >= len(out):
        return
    n = min(n, len(out) - i0)
    k = np.arange(n)
    env = np.exp(-k / (n * 0.2))
    seg = (r.normal(0, 1, n) * 0.6 + np.sin(2 * np.pi * tone * k / SR) * 0.4) * env * amp
    out[i0:i0 + n] += seg


def intro():
    total = I_LEADER + I_ROLL + I_JAM + I_BURN + I_FADE
    n = int(total * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    ri = np.random.default_rng(21)          # 自己的随机数，不影响另外两段循环
    # 倒计时：放映机慢慢转（每秒 18 下轻咔嗒），每个数字出来一下重的；"2"那下哔一声
    for k in range(int(I_LEADER * 18)):
        click(out, k / 18.0, 0.25, 2400, seed=k)
    for d in range(3):
        click(out, d * 0.3, 0.9, 1500, 0.016, seed=100 + d)
    i0, i1 = int(0.3 * SR), int(0.42 * SR)
    out[i0:i1] += 0.35 * np.sin(2 * np.pi * 1000 * t[i0:i1]) * np.hanning(i1 - i0)
    # 卷片：每过一个齿孔一下咔嗒，每过一个格子线重一下；越转越快就连成嗡
    t0 = I_LEADER
    steps = 4000
    last = 0
    for j in range(1, steps + 1):
        u = j / steps
        perf = int(roll_offset(u) // I_PERF)
        while last < perf:
            last += 1
            tt = t0 + u * I_ROLL
            heavy = last % 4 == 0
            click(out, tt, 0.8 if heavy else 0.45, 1400 if heavy else 2600, seed=1000 + last)
    m0, m1 = int(t0 * SR), int((t0 + I_ROLL) * SR)
    u = (t[m0:m1] - t0) / I_ROLL
    speed = np.exp(I_K * u) / math.exp(I_K)                     # 0.04 → 1
    freq = 50 + 140 * speed
    phase = 2 * np.pi * np.cumsum(freq) / SR
    out[m0:m1] += (0.12 + 0.25 * speed) * (np.sin(phase) + 0.5 * np.sin(2 * phase))
    whir = lowpass(ri.normal(0, 1, m1 - m0), 0.25) - lowpass(ri.normal(0, 1, m1 - m0), 0.03)
    out[m0:m1] += whir * speed * 0.9
    # 卡住：低沉的"咣" + 一团噪声，片门里再打滑两下
    tj = t0 + I_ROLL
    j0 = int(tj * SR)
    jn = int(0.35 * SR)
    k = np.arange(jn)
    out[j0:j0 + jn] += (np.sin(2 * np.pi * 70 * k / SR) * 1.2 + ri.normal(0, 1, jn) * np.exp(-k / (SR * 0.02)) * 0.9) * np.exp(-k / (SR * 0.09))
    for d, a in ((0.11, 0.7), (0.21, 0.5)):
        click(out, tj + d, a, 900, 0.02, seed=int(d * 1000))
    # 烧片：越来越密的噼啪 + 越来越响的嘶声，烧白那一刻最响，然后淡掉（气动管的风声接上）
    tb = tj + I_JAM
    b0, b1 = int(tb * SR), int((tb + I_BURN + I_FADE) * SR)
    bt = (t[b0:b1] - tb)
    hiss_env = np.clip(bt / I_BURN, 0, 1) ** 2 * np.clip((I_BURN + I_FADE - bt) / I_FADE, 0, 1)
    hiss = ri.normal(0, 1, b1 - b0) - lowpass(ri.normal(0, 1, b1 - b0), 0.1)
    out[b0:b1] += hiss * hiss_env * 0.35
    r2 = np.random.default_rng(9)
    for _ in range(70):
        tt = tb + (r2.random() ** 0.6) * I_BURN
        click(out, tt, 0.2 + 0.5 * r2.random(), 3000 + 2000 * r2.random(), 0.004, seed=int(tt * 10000))
    return out


if __name__ == "__main__":
    import sys
    if "intro" in sys.argv:                 # python3 level2_sfx.py intro：只重做开场动画那条
        save(intro(), "level2_intro.wav")
    else:
        save(tube_wind(), "level2_tube_wind.wav")
        save(projector(), "level2_projector_loop.wav")
        save(intro(), "level2_intro.wav")
