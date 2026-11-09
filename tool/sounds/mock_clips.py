"""The mock's clips, spoken: every `example.com` audio link in assets/mock/
becomes a WAV in assets/mock/audio/, saying the English beside it in the
data (a word, a sentence), so mock mode plays real speech.

    python -I tool/sounds/mock_clips.py

Windows only: it speaks through Windows' own English voice (System.Speech,
"Microsoft Zira"). Mock data only: these files go with the mock once the
lessons' endpoints are connected (docs/STATUS.md D-050). A link's file name
follows `mockClipAsset` in lib/core/audio/mock_clips.dart; both must agree.
"""
import io
import json
import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
ROOT = Path(__file__).resolve().parents[2]
MOCK = ROOT / "assets" / "mock"
OUT = MOCK / "audio"

# The English said where the data has none: the guide's Arabic lines, whose
# voice can't speak Arabic, and clips that stand alone.
SAID_FOR = {
    "praise": "Great job!",
    "tryAgain": "Try again.",
    "done": "Well done! You finished the lesson.",
    "leave": "See you soon!",
    "empty": "No words yet.",
    "review": "Let's review your words.",
    "words": "Here are your words.",
    "instructionAudio": "Listen, and choose.",
    "echoInstructionAudio": "Now you say it.",
    "titleAudio": "Let's learn.",
}
TEXT_KEYS = ("en", "word", "base", "sentence", "text", "transcript", "example")


def asset_name(url: str) -> str:
    """The file a mock link plays: its host and path, kept to [a-z0-9_]."""
    rest = re.sub(r"^[a-z]+://", "", url.lower())
    rest = re.sub(r"\.[a-z0-9]+$", "", rest)
    return re.sub(r"[^a-z0-9]+", "_", rest).strip("_") + ".wav"


def is_mock_clip(value) -> bool:
    return isinstance(value, str) and re.match(r"^https://(cdn\.)?example\.com/", value) and value.endswith(".mp3")


def english(node: dict, key: str) -> str:
    for name in TEXT_KEYS:
        v = node.get(name)
        if isinstance(v, dict):
            v = v.get("en")
        if isinstance(v, str) and re.search(r"[A-Za-z]", v) and not re.search(r"[؀-ۿ]", v):
            return v
    return SAID_FOR.get(key, "Listen carefully.")


def clips() -> dict:
    found = {}

    def walk(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if is_mock_clip(value):
                    found.setdefault(value, english(node, key))
                walk(value)
        elif isinstance(node, list):
            for item in node:
                walk(item)

    for file in sorted(MOCK.rglob("*.json")):
        walk(json.loads(file.read_text(encoding="utf-8")))
    return found


def speak(lines: list) -> None:
    """One PowerShell run for all: [(text, path)] spoken to 16 kHz mono WAV."""
    script = [
        "Add-Type -AssemblyName System.Speech",
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer",
        "try { $s.SelectVoice('Microsoft Zira Desktop') } catch {}",
        "$s.Rate = -1",
        "$f = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(16000, "
        "[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, "
        "[System.Speech.AudioFormat.AudioChannel]::Mono)",
    ]
    for text, path in lines:
        t = text.replace("'", "''")
        p = str(path).replace("'", "''")
        script += [f"$s.SetOutputToWaveFile('{p}', $f)", f"$s.Speak('{t}')"]
    script.append("$s.SetOutputToNull(); $s.Dispose()")
    with tempfile.NamedTemporaryFile("w", suffix=".ps1", delete=False, encoding="utf-8-sig") as f:
        f.write("\n".join(script))
        name = f.name
    subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", name], check=True)
    Path(name).unlink()


def trim(path: Path) -> None:
    """Windows' voice pads each line with silence: kept to 30 ms before and
    80 ms after, the voice brought to 80% of full scale."""
    with wave.open(str(path)) as w:
        rate = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), "<i2").astype(float)
    peak = np.max(np.abs(x)) or 1
    heard = np.nonzero(np.abs(x) > peak * 0.02)[0]
    if len(heard) == 0:
        return
    x = x[max(0, heard[0] - int(0.03 * rate)): heard[-1] + int(0.08 * rate)]
    x *= 0.8 * 32767 / peak
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(np.clip(x, -32768, 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    found = clips()
    for old in OUT.glob("*.wav"):
        old.unlink()
    speak([(text, OUT / asset_name(url)) for url, text in found.items()])
    for clip in OUT.glob("*.wav"):
        trim(clip)
    size = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    print(f"{len(found)} clips, {size / 1024 / 1024:.1f} MB")
