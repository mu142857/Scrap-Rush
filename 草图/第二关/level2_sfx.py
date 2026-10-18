"""第二关的两段循环环境音（用 numpy 合成，不用网上素材；不动共享的 tools/gen_sfx.py）。

  sfx/level2_tube_wind.wav       气动管里的风：过滤过的气流噪声，慢慢起伏。游戏里音量、音高跟着胶囊速度走
  sfx/level2_projector_loop.wav  放映机：每秒 24 下的胶片齿轮"咔嗒"（一重一轻），底下一点电机嗡嗡和转动的沙沙声

都是 2 秒、首尾无缝的循环（游戏里 AudioStreamWAV.loop_mode = LOOP_FORWARD）。
跑法：python3 level2_sfx.py
"""
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


if __name__ == "__main__":
    save(tube_wind(), "level2_tube_wind.wav")
    save(projector(), "level2_projector_loop.wav")
