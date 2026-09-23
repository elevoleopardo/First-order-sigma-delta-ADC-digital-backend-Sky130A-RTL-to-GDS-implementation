# 04 — RTL Implementation

## 1. Overview

The digital backend is implemented in synthesizable Verilog RTL.

The current design is divided into three main modules:

```text
adc_sd_top
|
+-- cic_decimator
|
+-- fir_comp
The implementation is intended for ASIC synthesis using the Sky130A technology.

The RTL was developed and progressively refined through simulation and synthesis.

2. RTL Source Files

The current RTL consists of:

rtl/
├── adc_sd_top.v
├── cic_decimator.v
└── fir_comp.v
adc_sd_top.v

Top-level integration module.

cic_decimator.v

Three-stage CIC decimator with decimation factor 64.

fir_comp.v

15-tap FIR compensation filter with fixed coefficients, decimation by 2, scaling and saturation.

3. Top-Level Interface

The hardened digital core has the following interface:

clk
rst_n
din
dout[15:0]
dout_valid

The interface is intentionally compact.

Signal	Direction	Width	Description
clk	Input	1	System clock
rst_n	Input	1	Active-low reset
din	Input	1	Sigma-Delta bitstream
dout	Output	16	Decimated digital output
dout_valid	Output	1	Output sample valid

The FIR coefficients are not exposed as external ports.

They are fixed inside the RTL and therefore become part of the synthesized hardware.

4. Top-Level Data Flow

The top-level module connects the CIC and FIR stages:

din
 |
 | 1 bit @ 5.12 MHz
 v
+------------------+
| cic_decimator    |
|                  |
| 3 integrators    |
| /64              |
| 3 combs          |
+------------------+
 |
 | 19 bit @ 80 kHz
 v
+------------------+
| fir_comp         |
|                  |
| 15 taps          |
| /2               |
| scaling          |
| saturation       |
+------------------+
 |
 | 16 bit @ 40 kHz
 v
dout

The dout_valid signal identifies the cycles in which a new FIR output sample is available.

5. CIC RTL Implementation

The CIC module implements a third-order decimator.

Main parameters:

CIC_STAGES = 3
CIC_R      = 64
CIC_W      = 19

The input bit is converted to a bipolar signed value:

din = 0 -> -1
din = 1 -> +1

This representation is then processed by the integrator chain.

6. Integrator Chain

The first part of the CIC contains three cascaded integrators.

Conceptually:

x[n]
 |
 v
z^-1
 |
 +----> Integrator 1
          |
          v
      Integrator 2
          |
          v
      Integrator 3

The integrators operate at the full 5.12 MHz clock rate.

Their state variables use the selected 19-bit internal representation.

The implementation relies on finite-width two's-complement arithmetic.

7. Decimation Logic

After the integrator chain, the signal is decimated by 64.

Only every 64th integrator result is passed to the comb section.

The sampling-rate conversion is:

5.12 MHz / 64 = 80 kHz

The decimation counter therefore operates synchronously with the main system clock.

8. Comb Chain

The second part of the CIC consists of three comb stages.

The comb section operates at the reduced 80 kHz rate.

Conceptually:

Integrator output
       |
       v
    +-----+
    |Comb1|
    +-----+
       |
       v
    +-----+
    |Comb2|
    +-----+
       |
       v
    +-----+
    |Comb3|
    +-----+
       |
       v
   CIC output

For a differential delay of one sample, each comb stage calculates a difference between the current sample and the previous sample.

9. CIC Width and Arithmetic

The selected CIC internal width is:

CIC_W = 19 bit

The width is sufficient for the intended configuration:

N = 3
R = 64
M = 1

The integrators use wrap-around arithmetic rather than explicit saturation.

This is an intentional architectural choice.

The finite-width arithmetic corresponds to modular arithmetic and avoids adding saturation logic to the high-rate integrator path.

10. FIR Compensation Module

The FIR module receives the CIC output:

DIN_W = 19 bit

and produces:

OUT_W = 16 bit

Its main parameters are:

NTAPS     = 15
D         = 2
COEF_BITS = 12

The filter performs both:

CIC passband compensation;
final decimation by 2.
11. FIR Delay Line

The 15-tap FIR maintains a delay line containing the most recent input samples.

Conceptually:

x[n] --> x[n-1] --> x[n-2] --> ... --> x[n-14]

The 15 samples form the input vector used by the FIR multiply-accumulate operation.

The delay line is updated synchronously with the CIC output-valid signal.

12. Fixed Coefficients

The FIR coefficients are fixed constants in the RTL.

The coefficient set is:

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

The coefficients are represented using signed 12-bit fixed-point constants.

There is no runtime coefficient programming interface.

13. FIR Symmetry Optimization

The coefficient set is symmetric:

h[k] = h[14-k]

Therefore the FIR convolution can be rewritten as:

y[n] =
h0  × (x0  + x14)
+ h1  × (x1  + x13)
+ h2  × (x2  + x12)
+ h3  × (x3  + x11)
+ h4  × (x4  + x10)
+ h5  × (x5  + x9)
+ h6  × (x6  + x8)
+ h7  × x7

This reduces the number of independent multiplication operations from fifteen to eight.

The optimization is particularly relevant for ASIC implementation because multipliers represent a significant fraction of the FIR hardware cost.

14. FIR Accumulator

The products generated by the symmetric FIR structure are accumulated in a wider signed accumulator.

The accumulator must accommodate:

the 19-bit input data;
the 12-bit coefficients;
the sum of multiple products.

Explicit sign extension is used when combining data and coefficients.

This prevents unintended unsigned arithmetic and ensures that negative values are handled correctly.

15. FIR Decimation

The FIR performs the final decimation by two.

The CIC output rate is:

80 kHz

The FIR output rate is:

80 kHz / 2 = 40 kHz

The FIR therefore computes an output sample only on the required decimation phase.

This avoids generating unnecessary output samples.

16. Scaling

The internal FIR accumulation uses a wider numerical representation than the final 16-bit output.

The implementation therefore applies a fixed scaling operation.

The current scaling constants are:

SCALE_NUM = 32767
SCALE_DEN = 132358

The scaled value is subsequently converted to the 16-bit output representation.

The scaling is part of the fixed RTL implementation and is therefore included in the golden-model comparison.

17. Saturation

After scaling, the result is limited to the representable signed 16-bit range.

Conceptually:

if value > MAX:
    output = MAX

else if value < MIN:
    output = MIN

else:
    output = value

with:

MAX = 32767
MIN = -32768

Saturation prevents arithmetic overflow from causing wrap-around at the final output.

18. Signed Arithmetic

Signed arithmetic is particularly important in this design because:

the Sigma-Delta bitstream is interpreted as bipolar;
CIC values can be negative;
FIR coefficients contain both positive and negative values;
the FIR accumulator is signed;
the final output is signed.

The RTL therefore uses explicit signed declarations and sign-extension functions where required.

This avoids implicit Verilog type conversions affecting the numerical result.

19. Synthesis-Oriented RTL Refinements

Several RTL issues were identified during synthesis and corrected before the final physical implementation.

19.1 FIR accumulator assignment

The FIR accumulator initially contained both blocking and non-blocking assignments in conflicting contexts.

This produced a Verilator warning/error corresponding to a BLKANDNBLK condition.

The implementation was corrected so that the accumulator is computed consistently within the sequential processing structure.

The reset assignment that caused the conflict was removed from the accumulator path because the accumulator is fully assigned during the calculation.

19.2 CIC loop variables

The CIC implementation originally reused integer loop variables in different procedural contexts.

This caused synthesis to interpret the variable usage as conflicting drivers.

The implementation was corrected by separating the loop variables:

integer i;
integer j;

The variables are used independently for combinational and sequential loops.

This eliminated the synthesis conflict.

20. Fixed-Coefficient Architecture

An earlier version of the design exposed the FIR coefficients through an external interface.

This was changed to a fixed-coefficient architecture.

The current design therefore does not contain a coefficient bus.

The final top-level interface is reduced to:

clk
rst_n
din
dout[15:0]
dout_valid

This change removes:

coefficient input pins;
coefficient storage/control logic;
coefficient loading logic;
associated routing.

The result is a substantially smaller synthesized and routed design.

21. Hardware Complexity Improvement

The fixed-coefficient and symmetric-FIR implementation produced a significant reduction in hardware complexity compared with the earlier programmable-coefficient implementation.

The previous implementation contained:

programmable FIR coefficients
+
coefficient input interface
+
coefficient storage/control
+
15 independent FIR products

The current implementation uses:

fixed coefficients
+
8 multiplication terms exploiting symmetry

The physical implementation results demonstrate the impact of these architectural changes.

The final design contains:

Synthesized cells: 9,315
Total cells:       30,197
Die area:           0.2532 mm^2

The corresponding earlier implementation had approximately:

Synthesized cells: 33,210
Total cells:       104,094
Die area:           0.8083 mm^2

The final implementation therefore represents a major reduction in physical complexity.

22. RTL Verification Before Synthesis

Before proceeding to ASIC implementation, the RTL was compared against the Python golden model.

The validated comparison produced:

Output samples compared: 4160
Maximum error:           0 LSB
Mismatches (>2 LSB):     0
Result:                  PASS

This established the functional correctness of the RTL for the tested reference dataset before physical implementation.

23. RTL-to-ASIC Flow

The RTL implementation is the input to the ASIC implementation flow:

Verilog RTL
    |
    v
Synthesis
    |
    v
Gate-level netlist
    |
    v
Floorplanning
    |
    v
Placement
    |
    v
Clock Tree Synthesis
    |
    v
Routing
    |
    v
Signoff
    |
    v
GDS

The current implementation has completed this flow in the Sky130A technology.

24. Current RTL Milestone

The current RTL represents the frozen digital-core implementation used for the completed Sky130A physical-design run.

The core has:

fixed FIR coefficients;
symmetric FIR optimization;
19-bit CIC processing;
16-bit output;
no coefficient programming interface;
validated RTL behavior;
successful ASIC physical implementation.

Future modifications should be treated as new design iterations rather than changes to this validated milestone.

