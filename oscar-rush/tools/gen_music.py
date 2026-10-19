"""把本2兔的两首曲子处理成游戏里用的循环（2026-10-18，游戏细节讨论会话）。

用法：python3 tools/gen_music.py
读 ../Bentootoo_Music_Assets/ 里的原稿（44.1kHz 立体声 16 位，工程外、只读），写 music/*.wav（22050Hz 立体声 16 位）。
进 Godot 以后用 QOA 压缩导入（compress/mode=2），循环点在 scripts/audio/music.gd 里按采样数设。

分析（详见 夜间打磨/游戏细节讨论_报告.md 第 22 节）：
- back_to_the_game：120 BPM，正好 36 小节 = 72.00 秒，首尾都在 0 附近，是写好的循环。很闷：99% 的能量在 1kHz 以下，
  8kHz 以上比主体低 40 dB。原样整段循环。
- backhome：120 BPM，32 小节 = 64.00 秒，后面多 0.54 秒混响尾巴；原稿首尾直接接会"嗒"一声（首尾差是平时相邻两格的 10 倍）。
  做法：在 64.00 秒切开，尾巴叠回开头（混响自然地延续进下一圈），开头先做 5 毫秒淡入（原稿第一格不在 0 上）。

处理：
- 降到 22050Hz：两首 11kHz 以上的能量都只占 0.003%~0.36%（backhome 那点是 16kHz 以上的底噪）。用 FFT 降（把整段当一个周期），
  首尾照样严丝合缝。包体减半，QOA 进包每首约 1.2 MB。
- 响度拉近：原稿 back_to_the_game RMS -21.6 dBFS、backhome -33.7 dBFS，差 12 dB。统一到 -23 / -27 dBFS
  （标题、结局那首本来就该安静一点，但别安静到要把音量开很大才听得见）。
"""
import wave
from pathlib import Path

import numpy as np
from scipy.signal import resample

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT.parent / "Bentootoo_Music_Assets"
OUT = ROOT / "music"
SR_OUT = 22050
BPM = 120.0
## 曲名 → [循环长度（小节，4/4）, 目标 RMS dBFS]
TRACKS = {
    "back_to_the_game": [36, -23.0],
    "backhome": [32, -27.0],
}


def read(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path)) as w:
        sr = w.getframerate()
        ch = w.getnchannels()
        x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768.0
    return x.reshape(-1, ch), sr


def write(path: Path, x: np.ndarray, sr: int) -> None:
    y = np.clip(x, -1.0, 1.0)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(y.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((y * 32767.0).round().astype(np.int16).tobytes())


def main() -> None:
    OUT.mkdir(exist_ok=True)
    for name, (bars, target) in TRACKS.items():
        x, sr = read(SRC / f"{name}.wav")
        loop = int(round(bars * 4 * 60.0 / BPM * sr))
        if len(x) > loop:
            # 尾巴叠回开头：开头先淡入 5 毫秒，接缝处才连得上
            fade = int(sr * 0.005)
            body = x[:loop].copy()
            body[:fade] *= np.linspace(0.0, 1.0, fade)[:, None]
            tail = x[loop:]
            body[: len(tail)] += tail
            x = body
        else:
            x = x[:loop]
        # 整段当一个周期降采样：首尾无缝
        n_out = int(round(len(x) * SR_OUT / sr))
        y = resample(x, n_out, axis=0)
        rms = np.sqrt(np.mean(y.mean(axis=1) ** 2))
        y *= 10 ** (target / 20.0) / rms
        peak = np.max(np.abs(y))
        if peak > 0.97:
            y *= 0.97 / peak
        write(OUT / f"{name}.wav", y, SR_OUT)
        seam = np.abs(y[0] - y[-1]).max()
        med = np.median(np.abs(np.diff(y[:, 0])))
        print(f"wrote music/{name}.wav: {len(y)} samples ({len(y) / SR_OUT:.3f}s), "
              f"peak {20 * np.log10(np.max(np.abs(y))):.1f} dBFS, seam jump {seam:.4f} vs median {med:.4f}")


if __name__ == "__main__":
    main()
