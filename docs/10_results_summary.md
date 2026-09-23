# 10 — Results Summary

## 1. Project status

The project implements and validates the digital backend of a first-order
sigma-delta ADC intended as the digital portion of a larger mixed-signal
ADC.

The current design has been:

1. modeled in Python;
2. implemented in synthesizable Verilog RTL;
3. verified against a golden model;
4. synthesized with OpenLane;
5. placed and routed in Sky130A;
6. checked with STA, DRC and LVS;
7. exported as final GDS, LEF and DEF.

The current hardened core is named:

```text
adc_sd_top
The TinyTapeout-specific wrapper and integration flow have not yet been
implemented.

2. ADC specifications
Parameter	Value
Architecture	First-order sigma-delta ADC
Signal bandwidth	20 kHz
Output sample rate	40 kHz
Oversampling ratio	128
Modulator sample rate	5.12 MHz
Modulator order	1
Quantizer	1 bit
CIC stages	3
CIC decimation	64
FIR taps	15
FIR decimation	2
Total decimation	128
CIC internal width	19 bit
FIR coefficient width	12 bit
Output width	16 bit
FIR coefficients	Fixed
3. RTL verification

The RTL was simulated using Icarus Verilog.

The RTL output was compared against the Python golden model.

Result
Output samples produced: 8000
Expected samples compared: 4160
Maximum error: 0 LSB
Mismatches greater than 2 LSB: 0
PASS

The simulation continued beyond the number of samples required by the
comparison testbench, hence the difference between the total produced
samples and the number of expected samples.

The important verification result is:

mismatch > 2 LSB = 0
maximum error = 0 LSB

Therefore the RTL implementation reproduces the golden-model output for
the samples under test.

4. FIR optimization

The original FIR implementation exposed the coefficients as an input
vector.

The final implementation uses fixed coefficients internally, since the
coefficients are not programmable during operation.

The 15-tap symmetric FIR therefore exploits coefficient symmetry and
requires 8 multiplier operations instead of 15 independent multiplications.

The fixed quantized coefficients are:

H0 = -3
H1 = -6
H2 = -14
H3 = -29
H4 = -51
H5 = -74
H6 = -93
H7 = 2047

Coefficient sum:

1507

This architectural change substantially reduced the synthesized hardware.

5. Synthesis results

Final OpenLane run:

adc_sd_gen_fixedfir

Main synthesis result:

Metric	Result
Synthesized cells	9,315
Total cells after physical implementation	30,197
Core area	235,630.9888 µm²
Core area	0.235631 mm²
Die area	0.2532016388 mm²
Final utilization	37.4089 %
OpenDP utilization	41.19 %
6. Physical implementation

The final routed design has:

Die width  = 497.86 µm
Die height = 508.58 µm
Die area   ≈ 0.2532 mm²

Final routing statistics:

Metric	Result
Wire length	206,356
Vias	60,906
TritonRoute violations	0
DRC violations	0
LVS errors	0

The final DEF contains:

DIEAREA ( 0 0 ) ( 497860 508580 ) ;

with the Sky130 database units used by the design.

7. Timing

Clock:

Clock frequency target = 5.12 MHz
Clock period            = 195.3125 ns

The final signoff STA reports no setup or hold violations in the reported
corners.

The detailed nominal setup report shows a worst displayed positive slack
of approximately:

+144.22 ns

corresponding to an approximate path delay of:

195.3125 ns - 144.22 ns ≈ 51.09 ns

The OpenLane metrics also report:

Critical path = 196.3125 ns
Suggested frequency = 5.093919 MHz

The latter metric should be interpreted together with the detailed
signoff STA rather than in isolation.

8. Electrical checks
DRC
DRC errors = 0

Magic and KLayout signoff checks completed successfully.

LVS
LVS errors = 0

The final layout and extracted netlist were verified against the
corresponding design netlist.

Antenna

The final run reports:

Pin antenna violations = 2
Net antenna violations = 2

These violations occur at backend-generated structures rather than being
caused by an RTL functional modification.

They are documented here instead of being hidden from the project record.

Slew

The Slowest corner reports 53 slew violations, with the largest reported
violation approximately:

0.84 vs 0.75

The Typical and Fastest corners do not show corresponding violations in
the final checks report.

Fanout

One internal backend buffer has a reported fanout of 11 against the
constraint of 10.

This is:

_15302_ = sky130_fd_sc_hd__buf_2

and is an implementation-level issue rather than a top-level RTL
interface problem.

9. Area reduction

The final fixed-coefficient symmetric FIR implementation was compared
against the previous implementation that exposed the coefficient vector.

Approximate reduction:

Metric	Reduction
Die area	68.7 %
Core area	69.7 %
Synthesized cells	71.9 %
Total cells	71.0 %
Wire length	79.4 %
Vias	73.9 %
Total OpenLane runtime	91.7 %
Routing runtime	91.8 %

This comparison is one of the principal implementation results of the
project.

10. Final physical artifacts

The repository contains selected final physical-design artifacts:

results/physical/adc_sd_top.def
results/physical/adc_sd_top.gds
results/physical/adc_sd_top.lef
results/physical/adc_sd_top_postroute.v
results/physical/adc_sd_top_postroute_nl.v
results/physical/adc_sd_top_signoff.gds

The complete OpenLane run remains available outside the repository in the
local OpenLane workspace.

11. TinyTapeout status

The current adc_sd_top design is a hardened Sky130A core, but it is not
yet a complete TinyTapeout project.

The remaining integration tasks are:

create the TinyTapeout top-level wrapper;
map the ADC signals to the TinyTapeout GPIO interface;
determine the required tile configuration;
verify compatibility with the TinyTapeout technology and routing rules;
run the TinyTapeout-specific flow;
verify the final wrapper and GDS.

In particular, the current GDS must not be assumed to be directly
TinyTapeout-compatible merely because it passed the standalone OpenLane
Sky130A flow.

The TinyTapeout integration is therefore treated as a subsequent stage
rather than as part of the already completed hardening result.

12. Current conclusion

The digital sigma-delta ADC backend has reached a complete RTL-to-GDS
implementation milestone.

The following chain has been demonstrated:

Specifications
      ↓
Python golden model
      ↓
Verilog RTL
      ↓
RTL simulation
      ↓
Golden-model comparison
      ↓
Synthesis
      ↓
Place & Route
      ↓
STA
      ↓
DRC
      ↓
LVS
      ↓
Final GDS

The remaining work is primarily TinyTapeout integration rather than
completion of the core digital implementation.
