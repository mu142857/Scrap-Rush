"""合成各区域的环境声循环 sfx/amb_*.wav（2026-10-17 夜间打磨，游戏细节讨论会话）。

用法：python3 tools/gen_ambience.py
全是程序合成（噪声 + 频域滤波 + 低频正弦），没有外部素材。每段 8 秒，首尾无缝：
- 噪声在频域里造（FFT 是周期的，天然首尾接得上）；
- 正弦的频率都取 8 秒内转整数圈；
- 篝火的噼啪按 8 秒取模摆放。
每段归一到同一个响度（RMS -18 dBFS），游戏里用 scripts/audio/ambience.gd 里的音量再压低。
"""
import wave
from pathlib import Path

import numpy as np

SR = 22050
SEC = 8
N = SR * SEC
OUT = Path(__file__).resolve().parent.parent / "sfx"
rng = np.random.default_rng(1017)


def t() -> np.ndarray:
    return np.arange(N) / SR


def band_noise(lo: float, hi: float, tilt: float = 0.0) -> np.ndarray:
    """频域里只留 lo~hi Hz 的噪声；tilt < 0 越高频越弱（-1 接近粉噪，-2 接近棕噪）"""
    spec = np.zeros(N // 2 + 1, dtype=complex)
    f = np.fft.rfftfreq(N, 1 / SR)
    mask = (f >= lo) & (f <= hi)
    mag = np.where(mask, np.power(np.maximum(f, 1.0), tilt / 2.0), 0.0)
    # 边缘柔一点，免得太"数字"
    edge = np.clip(np.minimum((f - lo) / max(lo * 0.3, 5), (hi - f) / max(hi * 0.3, 5)), 0, 1)
    mag *= edge
    phase = rng.uniform(0, 2 * np.pi, len(f))
    spec = mag * np.exp(1j * phase)
    x = np.fft.irfft(spec, N)
    return x / (np.max(np.abs(x)) + 1e-9)


def sine(freq: float, amp: float = 1.0) -> np.ndarray:
    cycles = round(freq * SEC)  # 8 秒整数圈
    return amp * np.sin(2 * np.pi * cycles / SEC * t())


def lfo(freq: float, depth: float, base: float = 1.0) -> np.ndarray:
    cycles = max(1, round(freq * SEC))
    return base + depth * np.sin(2 * np.pi * cycles / SEC * t() + rng.uniform(0, 6.28))


def norm(x: np.ndarray, rms_db: float = -18.0) -> np.ndarray:
    rms = np.sqrt(np.mean(x ** 2)) + 1e-12
    y = x * (10 ** (rms_db / 20) / rms)
    peak = np.max(np.abs(y))
    if peak > 0.89:  # 峰值留余量
        y *= 0.89 / peak
    return y


def save(name: str, x: np.ndarray) -> None:
    y = (norm(x) * 32767).astype(np.int16)
    with wave.open(str(OUT / f"amb_{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(y.tobytes())
    print("wrote", f"sfx/amb_{name}.wav")


def clicks(rate: float, width_ms: float, freq: float, jitter: float = 0.0) -> np.ndarray:
    """每秒 rate 下的短促咔哒（衰减的正弦小包），按 8 秒取模摆放"""
    x = np.zeros(N)
    n = int(round(rate * SEC))
    w = int(SR * width_ms / 1000)
    env = np.exp(-np.linspace(0, 6, w))
    for i in range(n):
        pos = int((i / n * N + rng.uniform(-jitter, jitter) * SR)) % N
        burst = env * np.sin(2 * np.pi * freq * np.arange(w) / SR) * rng.uniform(0.6, 1.0)
        idx = (pos + np.arange(w)) % N
        x[idx] += burst
    return x


def main() -> None:
    # 2026-10-18 早上作者试玩："场景里有蒸汽的白噪音，很吵"。改成以低沉的嗡鸣为主：
    # 噪声只留 200 Hz 以下（再往上就是"沙沙""嘶嘶"），而且比嗡鸣轻得多；不要宽频噪声。

    # 第一关：工厂。50 Hz 电机嗡鸣 + 谐波，慢慢起伏；下面一点点很低的轰鸣
    hum = sine(50, 1.0) + sine(100, 0.45) + sine(150, 0.18)
    save("factory", hum * lfo(0.25, 0.15) + band_noise(25, 140, -2.0) * lfo(0.125, 0.3) * 0.25)

    # 第一关 Boss 房：锅炉。更低的嗡鸣，一呼一吸地起伏
    save("boiler", (sine(35, 1.0) + sine(70, 0.5) + sine(105, 0.2)) * lfo(0.5, 0.3) + band_noise(20, 120, -2.0) * 0.3)

    # 第二关前半：电话交换局。安静的 60 Hz 交流嗡（电话铃、继电器另外随机点缀）
    save("exchange", sine(60, 1.0) + sine(120, 0.35) + sine(180, 0.12))

    # 第二关后半：放映厅。放映机马达的低沉转动 + 很轻、很闷的快门咔哒
    motor = (sine(48, 1.0) + sine(96, 0.4) + sine(144, 0.15)) * lfo(0.5, 0.1)
    save("projector", motor + clicks(16, 14, 380) * 0.18)

    # 第三关：老电视。只留 60 Hz 的嗡，不要雪花的沙沙
    save("tv", (sine(60, 1.0) + sine(120, 0.3) + sine(180, 0.1)) * lfo(0.25, 0.1))

    # 第三关到家：很低的风，慢慢鼓起来又落下（只留 200 Hz 以下）
    save("wind", band_noise(40, 200, -1.5) * lfo(0.125, 0.5) * lfo(0.375, 0.12))

    # 商店：篝火。低低的火苗声 + 少量、很闷的噼啪
    pops = np.zeros(N)
    for _ in range(14):
        pos = int(rng.uniform(0, N))
        w = int(SR * rng.uniform(0.006, 0.02))
        burst = band_noise(200, 900, 0.0)[:w] * np.exp(-np.linspace(0, 5, w)) * rng.uniform(0.3, 0.8)
        idx = (pos + np.arange(w)) % N
        pops[idx] += burst
    save("fire", band_noise(40, 200, -1.8) * lfo(0.375, 0.3) * 0.8 + sine(55, 0.3) + pops * 0.5)


if __name__ == "__main__":
    main()
