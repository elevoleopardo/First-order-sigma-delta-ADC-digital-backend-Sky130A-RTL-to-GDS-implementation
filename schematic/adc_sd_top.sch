v {xschem version=3.4.5 file_version=1.2}
G {}
K {}
V {}

T {FIRST-ORDER SIGMA-DELTA ADC - DIGITAL BACKEND} 100 70 0 0 0 0 0 0 0 0 0 0
T {BW=20 kHz | OSR=128 | Fs_mod=5.12 MHz | Fs_out=40 kHz} 100 100 0 0 0 0 0 0 0 0 0 0

B 120 180 390 340 {}
T {1st-ORDER SIGMA-DELTA} 155 215 0 0 0 0 0 0 0 0 0 0
T {MATLAB / ANALOG FRONT-END MODEL} 145 250 0 0 0 0 0 0 0 0 0 0
T {1-bit quantizer} 190 285 0 0 0 0 0 0 0 0 0 0
T {1-bit bitstream} 205 315 0 0 0 0 0 0 0 0 0 0

B 500 180 770 340 {}
T {CIC DECIMATOR} 570 215 0 0 0 0 0 0 0 0 0 0
T {sinc^3 / 64} 590 250 0 0 0 0 0 0 0 0 0 0
T {3 integrator stages} 550 280 0 0 0 0 0 0 0 0 0 0
T {3 comb stages} 570 310 0 0 0 0 0 0 0 0 0 0

B 880 180 1150 340 {}
T {FIR COMPENSATION} 930 215 0 0 0 0 0 0 0 0 0 0
T {15 taps / decimation /2} 915 250 0 0 0 0 0 0 0 0 0 0
T {fixed symmetric coefficients} 900 280 0 0 0 0 0 0 0 0 0 0
T {8 multipliers after symmetry} 910 310 0 0 0 0 0 0 0 0 0 0

N 390 260 500 260 {}
N 770 260 880 260 {}

T {1-bit @ 5.12 MHz} 395 245 0 0 0 0 0 0 0 0 0 0
T {19-bit CIC output} 775 245 0 0 0 0 0 0 0 0 0 0

C {devices/ipin.sym} 70 260 0 0 {name=p_din lab=din}
N 90 260 120 260 {}

C {devices/ipin.sym} 70 390 0 0 {name=p_clk lab=clk}
C {devices/ipin.sym} 70 440 0 0 {name=p_rst lab=rst_n}

T {clk / rst_n} 120 405 0 0 0 0 0 0 0 0 0 0

C {devices/opin.sym} 1210 260 0 0 {name=p_dout lab=dout[15:0]}
N 1150 260 1210 260 {}

C {devices/opin.sym} 1210 320 0 0 {name=p_valid lab=dout_valid}
N 1150 320 1210 320 {}

T {RTL: adc_sd_top -> cic_decimator -> fir_comp} 120 500 0 0 0 0 0 0 0 0 0 0
T {Implementation: Sky130A / OpenLane -> routed GDS} 120 530 0 0 0 0 0 0 0 0 0 0
