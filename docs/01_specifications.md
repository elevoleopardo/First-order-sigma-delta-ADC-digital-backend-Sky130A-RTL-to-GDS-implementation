# 01 — Specifications

## 1. Project Objective

The objective of the project is the implementation of the digital backend of a first-order Sigma-Delta Analog-to-Digital Converter (ADC).

The analog part of the converter is represented by a behavioral model during the digital development phase. The digital backend processes the 1-bit Sigma-Delta bitstream and produces a decimated 16-bit digital output.

The implementation is intended for ASIC realization in the Sky130A technology, with TinyTapeout integration considered as a subsequent development stage.

---

## 2. Main System Specifications

| Parameter | Symbol | Value | Status |
|---|---|---:|---|
| Signal bandwidth | BW | 20 kHz | Fixed |
| Output sampling frequency | Fs_out | 40 kHz | Derived |
| Oversampling ratio | OSR | 128 | Fixed |
| Modulator sampling frequency | Fs_mod | 5.12 MHz | Derived |
| Sigma-Delta modulator order | N_mod | 1 | Fixed |
| Quantizer resolution | Q | 1 bit | Fixed |
| ADC output width | OUT_W | 16 bit | Fixed |
| Supply/reference normalization | VREF | 1.0 | Modeling choice |

### Derived sampling frequencies

The output sampling frequency is selected according to:

```text
Fs_out = 2 × BW
       = 2 × 20 kHz
       = 40 kHz
The modulator sampling frequency is determined by the oversampling ratio:

Fs_mod = OSR × Fs_out
       = 128 × 40 kHz
       = 5.12 MHz

The corresponding clock period is:

Tclk = 1 / Fs_mod
     ≈ 195.3125 ns
3. Digital Decimation Chain

The total decimation factor must reduce the Sigma-Delta modulator rate to the final output rate:

Total decimation = Fs_mod / Fs_out
                 = 5.12 MHz / 40 kHz
                 = 128

The decimation is divided into two stages:

CIC decimation = /64
FIR decimation = /2

Total = 64 × 2 = /128

Therefore:

5.12 MHz
   |
   | CIC /64
   v
80 kHz
   |
   | FIR /2
   v
40 kHz
4. CIC Filter Specifications

The first digital filtering stage is a Cascaded Integrator-Comb (CIC) filter.

Parameter	Value
Architecture	CIC
Number of stages	3
Differential delay	1
Decimation factor	64
Transfer characteristic	sinc^3
Input	1-bit Sigma-Delta stream
Internal width	19 bit

The CIC is implemented using:

three integrator stages operating at the modulator sampling frequency;
decimation by 64;
three comb stages operating at the reduced sampling frequency.

The 1-bit input is mapped to a bipolar representation:

0 → -1
1 → +1

The internal arithmetic uses finite-width wrap-around behavior for the integrators.

5. CIC Internal Width

The CIC internal width was selected to avoid overflow for the intended configuration.

For a CIC filter with:

N = 3
R = 64
M = 1

and a 1-bit input, the selected implementation width is:

CIC_W = 19 bit

This width is used consistently between the CIC RTL and the FIR input interface.

6. FIR Compensation Filter

The CIC introduces passband droop. A FIR compensation filter is therefore used after the CIC stage.

Parameter	Value
Number of taps	15
Decimation	/2
Coefficient width	12 bit
Input width	19 bit
Output width	16 bit
Coefficients	Fixed
Runtime programmability	No

The FIR coefficients are quantized fixed-point constants embedded directly in the RTL.

The implemented coefficients are symmetric:

h[0]  = -3
h[1]  = -6
h[2]  = -14
h[3]  = -29
h[4]  = -51
h[5]  = -74
h[6]  = -93
h[7]  = 2047
h[8]  = -93
h[9]  = -74
h[10] = -51
h[11] = -29
h[12] = -14
h[13] = -6
h[14] = -3

Because of the symmetry, the FIR implementation requires eight multiplication terms rather than fifteen independent multiplications.

7. Output Representation

The final FIR output is represented using 16-bit signed data.

The implementation includes scaling and saturation logic to map the internal FIR accumulation to the selected output range.

The final digital output therefore has:

OUT_W = 16 bit
8. Target Technology

The ASIC implementation targets:

Technology: SkyWater SKY130
PDK:        sky130A
Flow:       OpenLane

The design was physically implemented through synthesis, floorplanning, placement, clock-tree synthesis and routing, followed by signoff checks.

9. Clock Constraint

The main clock is:

Clock frequency = 5.12 MHz
Clock period    = 195.3125 ns

The clock port used by the ASIC flow is:

clk

The design also includes an active-low reset:

rst_n
10. Interface of the Hardened Core

The current standalone ASIC core has the following logical interface:

Port	Direction	Description
clk	Input	System clock
rst_n	Input	Active-low reset
din	Input	1-bit Sigma-Delta bitstream
dout[15:0]	Output	16-bit decimated output
dout_valid	Output	Output-valid indication

The current core does not expose FIR coefficients as external inputs because the coefficients are fixed in the hardware implementation.

11. TinyTapeout Considerations

TinyTapeout integration is not included in the current specification of the standalone core.

A future integration stage will need to define:

TinyTapeout wrapper interface;
GPIO mapping;
clock/reset routing;
physical tile dimensions;
integration of the hardened macro;
compatibility with TinyTapeout-specific physical-design rules.

The standalone Sky130A implementation is therefore considered the current ASIC core milestone, while TinyTapeout compatibility remains a separate stage.

12. Specification Summary

The complete signal-processing chain is:

Input signal
     |
     v
Sigma-Delta modulator
     |
     | 1 bit @ 5.12 MHz
     v
CIC sinc^3
     |
     | /64
     | 80 kHz
     v
FIR compensation
     |
     | /2
     | 40 kHz
     v
16-bit digital output

The implementation is designed around a 20 kHz signal bandwidth and an overall oversampling ratio of 128.
