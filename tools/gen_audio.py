import math
import wave
from pathlib import Path

import numpy as np


SAMPLE_RATE = 22050
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio"


def envelope(length: int, fade_ms: float = 5.0) -> np.ndarray:
	fade = min(int(SAMPLE_RATE * fade_ms / 1000.0), length // 2)
	result = np.ones(length, dtype=np.float64)
	if fade:
		ramp = np.linspace(0.0, 1.0, fade, endpoint=False)
		result[:fade] = ramp
		result[-fade:] = ramp[::-1]
	return result


def tone(frequency: float, duration: float, amplitude: float = 1.0, decay: float = 0.0) -> np.ndarray:
	length = int(SAMPLE_RATE * duration)
	time = np.arange(length, dtype=np.float64) / SAMPLE_RATE
	signal = np.sin(2.0 * math.pi * frequency * time)
	if decay:
		signal *= np.exp(-decay * time)
	return signal * amplitude


def note(frequency: float, duration: float, amplitude: float = 1.0) -> np.ndarray:
	signal = tone(frequency, duration, amplitude, 3.0)
	return signal * envelope(len(signal))


def mix_parts(parts: list[tuple[np.ndarray, int]], length: int | None = None) -> np.ndarray:
	if length is None:
		length = max(offset + len(signal) for signal, offset in parts)
	result = np.zeros(length, dtype=np.float64)
	for signal, offset in parts:
		end = min(offset + len(signal), length)
		result[offset:end] += signal[:end - offset]
	return result


def noise_burst(duration: float, amplitude: float, decay: float, seed: int) -> np.ndarray:
	length = int(SAMPLE_RATE * duration)
	rng = np.random.default_rng(seed)
	noise = rng.normal(0.0, 1.0, length)
	time = np.arange(length, dtype=np.float64) / SAMPLE_RATE
	return noise * np.exp(-decay * time) * envelope(length, 3.0) * amplitude


def low_tone(frequency: float, duration: float, amplitude: float, decay: float = 4.0) -> np.ndarray:
	return tone(frequency, duration, amplitude, decay) * envelope(int(SAMPLE_RATE * duration), 8.0)


def write_wav(path: Path, samples: np.ndarray, normalize: bool = True) -> None:
	if normalize:
		peak = float(np.max(np.abs(samples)))
		if peak > 0.0:
			samples = samples / peak * 0.6
	samples = np.clip(samples, -1.0, 1.0)
	encoded = (samples * 32767.0).astype(np.int16)
	with wave.open(str(path), "wb") as output:
		output.setnchannels(1)
		output.setsampwidth(2)
		output.setframerate(SAMPLE_RATE)
		output.writeframes(encoded.tobytes())


def make_bgm() -> np.ndarray:
	duration = 24.0
	length = int(SAMPLE_RATE * duration)
	result = np.zeros(length, dtype=np.float64)
	chords = [(261.63, 329.63, 392.0), (220.0, 277.18, 329.63), (246.94, 311.13, 369.99), (196.0, 246.94, 293.66)]
	beat = 0.5
	for step in range(int(duration / beat)):
		start = int(step * beat * SAMPLE_RATE)
		chord = chords[(step // 4) % len(chords)]
		for index, frequency in enumerate(chord):
			part = note(frequency * (2.0 if index == 2 else 1.0), beat * 0.82, 0.18)
			end = min(start + len(part), length)
			result[start:end] += part[:end - start]
		bass_frequency = chords[(step // 4) % len(chords)][0] / 2.0
		bass = note(bass_frequency, beat * 0.7, 0.28)
		end = min(start + len(bass), length)
		result[start:end] += bass[:end - start]
	phase = np.linspace(0.0, 2.0 * math.pi * 0.5 * duration, length, endpoint=False)
	result += np.sin(phase) * 0.025
	result *= envelope(length, 40.0)
	return result


def make_sfx() -> dict[str, np.ndarray]:
	def chord(frequencies: list[float], duration: float) -> np.ndarray:
		parts = [(note(frequency, duration, 1.0 / len(frequencies)), 0) for frequency in frequencies]
		return mix_parts(parts)

	noise = np.random.default_rng(7).normal(0.0, 1.0, int(SAMPLE_RATE * 0.12))
	hit = mix_parts([(noise * np.exp(-35.0 * np.arange(len(noise)) / SAMPLE_RATE), 0), (note(90.0, 0.16, 0.8), 0)])
	card_locked = mix_parts([
		(noise_burst(0.11, 0.55, 20.0, 21), 0),
		(low_tone(115.0, 0.16, 0.72, 7.0), 0),
	])
	card_jam = mix_parts([
		(noise_burst(0.36, 0.48, 5.0, 22), 0),
		(low_tone(72.0, 0.38, 0.8, 3.5), 0),
		(low_tone(54.0, 0.22, 0.42, 7.0), int(SAMPLE_RATE * 0.14)),
	])
	tower_alarm = mix_parts([
		(low_tone(205.0, 0.32, 0.62, 3.5), 0),
		(low_tone(145.0, 0.42, 0.7, 3.0), int(SAMPLE_RATE * 0.25)),
		(noise_burst(0.56, 0.16, 4.0, 23), 0),
	])
	unit_death_a = mix_parts([
		(noise_burst(0.18, 0.42, 15.0, 24), 0),
		(low_tone(130.0, 0.28, 0.68, 5.0), 0),
		(low_tone(82.0, 0.3, 0.45, 6.0), int(SAMPLE_RATE * 0.08)),
	])
	unit_death_b = mix_parts([
		(noise_burst(0.2, 0.38, 13.0, 25), 0),
		(low_tone(108.0, 0.34, 0.62, 4.5), 0),
		(low_tone(68.0, 0.25, 0.4, 7.0), int(SAMPLE_RATE * 0.1)),
	])
	unit_death_c = mix_parts([
		(noise_burst(0.16, 0.44, 17.0, 26), 0),
		(low_tone(155.0, 0.25, 0.58, 5.5), 0),
		(low_tone(92.0, 0.32, 0.46, 6.0), int(SAMPLE_RATE * 0.06)),
	])
	ui_denied = mix_parts([
		(noise_burst(0.08, 0.3, 28.0, 27), 0),
		(low_tone(180.0, 0.18, 0.45, 9.0), 0),
		(low_tone(125.0, 0.2, 0.32, 10.0), int(SAMPLE_RATE * 0.06)),
	])
	return {
		"click": note(1250.0, 0.055),
		"place": mix_parts([(note(430.0, 0.12), 0), (note(720.0, 0.09), int(SAMPLE_RATE * 0.04))]),
		"merge": mix_parts([(note(660.0, 0.14), 0), (note(830.0, 0.16), int(SAMPLE_RATE * 0.08)), (note(1046.5, 0.24), int(SAMPLE_RATE * 0.16))]),
		"hit": hit * envelope(len(hit)),
		"tower": mix_parts([(note(65.0, 0.25, 1.0), 0), (note(120.0, 0.18, 0.4), 0)]) * envelope(int(SAMPLE_RATE * 0.25)),
		"victory": chord([523.25, 659.25, 783.99], 0.45),
		"defeat": mix_parts([(note(220.0, 0.25), 0), (note(164.81, 0.3), int(SAMPLE_RATE * 0.18)), (note(130.81, 0.38), int(SAMPLE_RATE * 0.36))]),
		"era": mix_parts([(note(392.0, 0.12), 0), (note(587.33, 0.15), int(SAMPLE_RATE * 0.07)), (note(783.99, 0.22), int(SAMPLE_RATE * 0.14)), (note(1046.5, 0.35), int(SAMPLE_RATE * 0.21))]),
		"button": mix_parts([(note(880.0, 0.1), 0), (note(1320.0, 0.06), int(SAMPLE_RATE * 0.03))]),
		"card_locked": card_locked,
		"card_jam": card_jam,
		"tower_alarm": tower_alarm,
		"unit_death": unit_death_a,
		"unit_death_1": unit_death_b,
		"unit_death_2": unit_death_c,
		"ui_denied": ui_denied,
	}


def main() -> None:
	OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	write_wav(OUTPUT_DIR / "bgm_loop.wav", make_bgm(), normalize=True)
	for name, samples in make_sfx().items():
		write_wav(OUTPUT_DIR / f"sfx_{name}.wav", samples)
	print(f"Generated {len(list(OUTPUT_DIR.glob('*.wav')))} WAV files in {OUTPUT_DIR}")


if __name__ == "__main__":
	main()
