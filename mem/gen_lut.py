# Genera le LUT del seno in formato $readmemh (16 bit, complemento a 2, una word per riga).
#   lut_sin.mem             : 2048 campioni su un periodo, per Axis_dds_sine_2048 (DDS).
#                             La frequenza la decide phase_step: 200 kHz @ 125 MHz -> 6871948
#   lut_sin_200k_625.mem    : 625 campioni = 1 periodo esatto a 200 kHz con clock 125 MHz
#                             (per un generatore a lettura diretta, senza DDS)
# Ampiezza 4000: sta comodamente nei 14 bit del DAC Red Pitaya (+-8191).
import math
from pathlib import Path

AMPL = 4000
HERE = Path(__file__).resolve().parent


def write_lut(name, n):
    with open(HERE / name, "w") as f:
        for k in range(n):
            v = round(AMPL * math.sin(2 * math.pi * k / n))
            f.write(f"{v & 0xFFFF:04X}\n")


write_lut("lut_sin.mem", 2048)
write_lut("lut_sin_200k_625.mem", round(125e6 / 200e3))
