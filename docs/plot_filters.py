# Magnitude and phase response of the filters used in the design:
#   cic_response.png : 3-stage CIC (R=2048 sine branch, R=8 square branch)
#   fir_response.png : 32-tap and 64-tap FIR (coefficients parsed from rtl/)
# Usage: python docs/plot_filters.py
import re
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from matplotlib.ticker import EngFormatter

HERE = Path(__file__).resolve().parent
RTL = HERE.parent / "rtl"

# Palette (light theme): categorical slots in fixed order, ink for all text
SURFACE = "#fcfcfb"
INK = "#0b0b0b"
INK_2 = "#52514e"
INK_3 = "#8a8984"
GRID = "#e9e8e4"
SERIES = ["#2a78d6", "#eb6834", "#1baf7a"]

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
    "axes.edgecolor": INK_3, "axes.linewidth": 0.8, "axes.labelcolor": INK_2,
    "text.color": INK, "xtick.color": INK_2, "ytick.color": INK_2,
    "xtick.major.size": 0, "ytick.major.size": 0, "xtick.minor.size": 0, "ytick.minor.size": 0,
    "axes.grid": True, "axes.grid.which": "both", "grid.color": GRID, "grid.linewidth": 0.7,
    "axes.spines.top": False, "axes.spines.right": False, "axes.spines.left": False,
    "font.size": 10.5, "axes.labelsize": 10.5, "legend.frameon": False, "legend.fontsize": 10,
})
HZ = EngFormatter(unit="Hz", sep=" ")
DB3 = -10 * np.log10(2)


def hz3(f):
    """Frequency with 3 significant digits and an SI prefix."""
    exp = int(np.floor(np.log10(f) / 3) * 3)
    return f"{f / 10**exp:.3g} {dict([(0, ''), (3, 'k'), (6, 'M')])[exp]}Hz"


def read_coeffs(name):
    txt = (RTL / name).read_text()
    vals = re.findall(r"COEFFS\[\s*\d+\]\s*=\s*16'sd(-?\d+)", txt)
    return np.array([int(v) for v in vals], dtype=float) / 2**15  # >>> 15 in the RTL


def fir_amplitude(b, w):
    """Real amplitude A(w) of a symmetric FIR, H = A(w)·e^{-jw(L-1)/2}; returns (A, group delay)."""
    d = (len(b) - 1) / 2
    return np.cos(np.outer(w, np.arange(len(b)) - d)) @ b, d


def cic_amplitude(R, N, w):
    """Real amplitude of an N-stage CIC with unity DC gain, H = A(w)·e^{-jwN(R-1)/2}."""
    s = np.sin(w / 2)
    safe = np.where(np.abs(s) < 1e-15, 1.0, s)
    a = np.where(np.abs(s) < 1e-15, 1.0, np.sin(w * R / 2) / (R * safe))
    return a ** N, N * (R - 1) / 2


def f_3db(f, mag_db):
    i = np.argmax(mag_db < DB3)
    return np.interp(DB3, [mag_db[i], mag_db[i - 1]], [f[i], f[i - 1]])


def plot(path, title, subtitle, curves, ylim_db, xlim):
    fig, (am, ap) = plt.subplots(2, 1, figsize=(10, 8), sharex=True,
                                 gridspec_kw={"height_ratios": [3, 2], "hspace": 0.08})
    handles = []
    for c in curves:
        f, amp, fs, delay, color = c["f"], c["amp"], c["fs"], c["delay"], c["color"]
        w = 2 * np.pi * f / fs
        mag = 20 * np.log10(np.maximum(np.abs(amp), 1e-9))
        fc = f_3db(f, mag)
        (h,) = am.plot(f, mag, color=color, lw=1.6, rasterized=len(f) > 50_000,
                       label=f"{c['label']}  ·  −3 dB at {hz3(fc)}")
        handles.append(h)
        am.plot(fc, DB3, "o", ms=8, color=color, mec=SURFACE, mew=2, zorder=5)
        ap.plot(f, np.degrees(w * delay), color=color, lw=2)
        if "f_nyq_out" in c:
            am.axvline(c["f_nyq_out"], color=color, lw=1, ls=(0, (4, 3)), alpha=0.7)

    for ax in (am, ap):
        ax.set_xscale("log")
        ax.set_xlim(*xlim)
        ax.xaxis.set_major_formatter(HZ)
    am.set_ylim(*ylim_db)
    am.set_ylabel("Magnitude (dB)")
    ap.set_yscale("log")
    ap.set_ylim(1e-1, None)
    ap.set_ylabel("Phase lag  −φ (deg)")
    ap.set_xlabel("Frequency")

    fig.text(0.075, 0.97, title, fontsize=15, fontweight="bold", color=INK, ha="left")
    fig.text(0.075, 0.943, subtitle, fontsize=10.5, color=INK_2, ha="left")
    fig.legend(handles=handles, loc="upper left", bbox_to_anchor=(0.067, 0.925),
               handlelength=1.6, labelcolor=INK)
    fig.subplots_adjust(left=0.075, right=0.98, top=0.835, bottom=0.07)
    fig.savefig(path, dpi=200)
    plt.close(fig)
    print("written", path)


# ---------------- CIC ----------------
N = 3
curves = []
for label, R, fs_in, color in [
    ("Sine branch: R = 2048, 125 MHz → 61.0 kHz", 2048, 125e6, SERIES[0]),
    ("Square branch: R = 8, 200.3 kHz → 25.0 kHz", 8, 125e6 / 624, SERIES[1]),
]:
    f = np.logspace(1, np.log10(fs_in / 2), 400_000 if R > 100 else 20_000)
    amp, delay = cic_amplitude(R, N, 2 * np.pi * f / fs_in)
    curves.append(dict(f=f, amp=amp, fs=fs_in, delay=delay, color=color, label=label,
                       f_nyq_out=fs_in / R / 2))
plot(HERE / "cic_response.png",
     "3-stage CIC decimator",
     "Gain normalised to 0 dB at DC · dashed lines: output Nyquist frequency · "
     "linear phase (±180° steps at the zeros omitted)",
     curves, (-140, 8), (10, 70e6))

# ---------------- FIR ----------------
b32 = read_coeffs("Axis_FIR_32taps_filter.v")
b64 = read_coeffs("Axis_FIR_64taps_filter.v")
curves = []
for label, b, fs, color in [
    ("FIR 32 taps, ADC input, sine branch (fs 125 MHz)", b32, 125e6, SERIES[0]),
    ("FIR 64 taps, sine branch (fs 30.5 kHz)", b64, 125e6 / 2048 / 2, SERIES[1]),
    ("FIR 64 taps, square branch (fs 12.5 kHz)", b64, 125e6 / 624 / 8 / 2, SERIES[2]),
]:
    f = np.logspace(0, np.log10(fs / 2), 20_000)
    amp, delay = fir_amplitude(b, 2 * np.pi * f / fs)
    curves.append(dict(f=f, amp=amp, fs=fs, delay=delay, color=color, label=label))
plot(HERE / "fir_response.png",
     "FIR low-pass filters",
     "16-bit symmetric coefficients read from rtl/ · linear phase, group delay "
     f"{(len(b32) - 1) / 2:g} / {(len(b64) - 1) / 2:g} samples (±180° steps at the zeros omitted)",
     curves, (-80, 8), (1, 70e6))
