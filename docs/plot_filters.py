# Risposta in modulo e fase dei filtri del progetto:
#   cic_response.png : CIC 3 stadi (R=2048 ramo sine, R=8 ramo square)
#   fir_response.png : FIR 32 tap e FIR 64 tap (coefficienti letti da rtl/)
# Uso: python docs/plot_filters.py
import re
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
RTL = HERE.parent / "rtl"

# Palette e inchiostri (tema chiaro)
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
GRID = "#e4e3df"
SERIES = ["#2a78d6", "#eb6834"]

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE,
    "axes.edgecolor": GRID, "axes.labelcolor": INK_2, "text.color": INK,
    "xtick.color": INK_2, "ytick.color": INK_2,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8,
    "axes.spines.top": False, "axes.spines.right": False,
    "font.size": 10, "axes.titlesize": 12, "axes.titleweight": "bold",
    "legend.frameon": False,
})


def read_coeffs(name):
    txt = (RTL / name).read_text()
    vals = re.findall(r"COEFFS\[\s*\d+\]\s*=\s*16'sd(-?\d+)", txt)
    return np.array([int(v) for v in vals], dtype=float) / 2**15  # >>> 15 nell'RTL


def freq_resp(b, w):
    """H(e^jw) di un FIR con coefficienti b, w in rad/campione."""
    n = np.arange(len(b))
    return np.exp(-1j * np.outer(w, n)) @ b


def db(h):
    return 20 * np.log10(np.maximum(np.abs(h), 1e-12))


def phase_deg(h):
    return np.degrees(np.unwrap(np.angle(h)))


def finish(fig, ax_mag, ax_ph, xlabel, path):
    ax_mag.set_ylabel("Modulo [dB]")
    ax_ph.set_ylabel("Fase [°]")
    ax_ph.set_xlabel(xlabel)
    ax_mag.legend(loc="upper right")
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    print("scritto", path)


# ---------------- CIC ----------------
# H(z) = [ (1 - z^-R) / (1 - z^-1) ]^N / R^N   (guadagno normalizzato, come nell'RTL)
N = 3
cic = [
    ("CIC R = 2048 – ramo sine (f_in 125 MHz, f_out 61.0 kHz)", 2048, 125e6),
    ("CIC R = 8 – ramo square (f_in 200.3 kHz, f_out 25.0 kHz)", 8, 125e6 / 624),
]
x = np.linspace(1e-4, 3.0, 6000)  # frequenza normalizzata alla frequenza d'uscita f/f_out

fig, (am, ap) = plt.subplots(2, 1, figsize=(9, 6.5), sharex=True)
for (label, R, fs_in), c in zip(cic, SERIES):
    w = 2 * np.pi * x / R                     # rad/campione all'ingresso
    h = (np.sin(w * R / 2) / (R * np.sin(w / 2))) ** N * np.exp(-1j * w * N * (R - 1) / 2)
    am.plot(x, db(h), color=c, lw=2, label=label)
    ap.plot(x, phase_deg(h), color=c, lw=2, label=label)
am.axvline(0.5, color=INK_2, lw=1, ls="--")
am.annotate("Nyquist uscita", (0.5, -95), xytext=(6, 0), textcoords="offset points",
            color=INK_2, fontsize=9)
am.set_ylim(-120, 5)
am.set_title("Filtro CIC 3 stadi – risposta in frequenza")
finish(fig, am, ap, "Frequenza normalizzata  f / f_out", HERE / "cic_response.png")

# ---------------- FIR ----------------
fir = [
    ("FIR 32 tap – ingresso ADC ramo sine (fs 125 MHz)", read_coeffs("Axis_FIR_32taps_filter.v")),
    ("FIR 64 tap – dopo CIC e ↓2 (fs 30.5 kHz sine, 12.5 kHz square)", read_coeffs("Axis_FIR_64taps_filter.v")),
]
x = np.linspace(1e-4, 0.5, 6000)  # f / fs
w = 2 * np.pi * x

fig, (am, ap) = plt.subplots(2, 1, figsize=(9, 6.5), sharex=True)
for (label, b), c in zip(fir, SERIES):
    h = freq_resp(b, w)
    # FIR simmetrico: H = A(w)·e^{-jw(L-1)/2} con A reale -> fase lineare + 180° dove A < 0
    delay = (len(b) - 1) / 2
    amp = np.real(h * np.exp(1j * w * delay))
    ph = np.degrees(-w * delay) + np.where(amp < 0, 180.0, 0.0)
    am.plot(x, db(h), color=c, lw=2, label=f"{label}, DC {db(b.sum()):+.2f} dB")
    ap.plot(x, ph, color=c, lw=2, label=f"ritardo di gruppo {delay:g} campioni")
ap.legend(loc="lower left")
am.set_ylim(-80, 5)
am.set_title("Filtri FIR – risposta in frequenza")
finish(fig, am, ap, "Frequenza normalizzata  f / fs", HERE / "fir_response.png")
