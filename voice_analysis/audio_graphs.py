from pathlib import Path

import librosa
import librosa.display
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def build_graph_data(y, sr, f0):
    spectrum = np.abs(librosa.stft(y, n_fft=2048, hop_length=512)) ** 2
    power_db = librosa.power_to_db(np.mean(spectrum, axis=1), ref=np.max)
    return {
        "pitch": {
            "time_sec": librosa.times_like(f0, sr=sr, hop_length=512).tolist(),
            "frequency_hz": [float(value) if np.isfinite(value) else None for value in f0],
        },
        "spectrum": {
            "frequency_hz": librosa.fft_frequencies(sr=sr, n_fft=2048).tolist(),
            "relative_power_db": power_db.tolist(),
        },
    }


def save_spectrogram(y, sr, output_path):
    spectrum = np.abs(librosa.stft(y, n_fft=2048, hop_length=512)) ** 2
    fig, ax = plt.subplots(figsize=(12, 4), constrained_layout=True)
    try:
        mesh = librosa.display.specshow(
            librosa.power_to_db(spectrum, ref=np.max), sr=sr,
            hop_length=512, x_axis="time", y_axis="linear",
            ax=ax, cmap="magma", vmin=-80, vmax=0,
        )
        ax.set(xlabel="Time (s)", ylabel="Frequency (Hz)")
        fig.colorbar(mesh, ax=ax, label="Relative power (dB)")
        path = Path(output_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(path, dpi=160)
    finally:
        plt.close(fig)


def save_frequency_graphs(y, sr, f0, output_path="frequency_graph.png"):
    """Save a spectrum, spectrogram, and pitch contour as one PNG."""
    if len(y) == 0:
        raise ValueError("Audio data is empty.")

    fig, axes = plt.subplots(3, 1, figsize=(12, 10), constrained_layout=True)
    try:
        # Average power across short frames; normalized to the strongest bin.
        spectrum = np.abs(librosa.stft(y, n_fft=2048, hop_length=512)) ** 2
        frequencies = librosa.fft_frequencies(sr=sr, n_fft=2048)
        mean_power = np.mean(spectrum, axis=1)
        power_db = librosa.power_to_db(mean_power, ref=np.max)
        axes[0].plot(frequencies, power_db, color="#2563eb", linewidth=1.2)
        axes[0].set(title="Average frequency spectrum", xlabel="Frequency (Hz)",
                    ylabel="Relative power (dB)", xlim=(0, sr / 2))
        axes[0].grid(alpha=0.25)

        spectrum_db = librosa.power_to_db(spectrum, ref=np.max)
        mesh = librosa.display.specshow(
            spectrum_db, sr=sr, hop_length=512, x_axis="time",
            y_axis="linear", ax=axes[1], cmap="magma", vmin=-80, vmax=0
        )
        axes[1].set(title="Frequency over time (spectrogram)",
                    xlabel="Time (s)", ylabel="Frequency (Hz)")
        fig.colorbar(mesh, ax=axes[1], label="Relative power (dB)")

        times = librosa.times_like(f0, sr=sr, hop_length=512)
        axes[2].plot(times, f0, color="#059669", linewidth=1.5)
        axes[2].set(title="Voice pitch (F0)", xlabel="Time (s)",
                    ylabel="Pitch (Hz)", xlim=(0, len(y) / sr))
        axes[2].grid(alpha=0.25)
        if not np.any(np.isfinite(f0)):
            axes[2].text(0.5, 0.5, "No voiced pitch detected",
                         transform=axes[2].transAxes, ha="center")

        path = Path(output_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(path, dpi=160)
    finally:
        plt.close(fig)
    return str(path.resolve())


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Save audio frequency graphs.")
    parser.add_argument("audio_path", nargs="?", default="audio.wav")
    parser.add_argument("--output", default="frequency_graph.png")
    args = parser.parse_args()
    y, sr = librosa.load(args.audio_path, sr=None, mono=True)
    f0, _, _ = librosa.pyin(
        y, fmin=librosa.note_to_hz("C2"),
        fmax=librosa.note_to_hz("C7"), sr=sr
    )
    print(save_frequency_graphs(y, sr, f0, args.output))
