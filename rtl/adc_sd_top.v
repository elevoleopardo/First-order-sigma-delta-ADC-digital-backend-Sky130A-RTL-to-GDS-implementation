// ==============================================================================
// adc_sd_top.v - Top del blocco digitale: CIC +FIR compensatore
// ______________________________________________________________________________
// Catena di decimazione completa del ADC sigma-delta:
//	bitstreN 1-BIT @Fs_mod ---> CIC sinc^3/64 ---> FIR/2 ---> 16-bit @Fs_out
//
// Questo è il modulo funzionante del "core". L'integrazione con il wrapper
// Tiny Tapeout (tt_um_*, mapping su ui_in/uo_out/uio_*) avverra in fasi successive
//
// ==============================================================================

module adc_sd_top #(
	parameter integer CIC_STAGES = 3,
	parameter integer CIC_R = 64,
	parameter integer CIC_W = 19,
	parameter integer FIR_NTAPS = 15,
	parameter integer FIR_D = 2,
	parameter integer COEF_BITS = 12,
	parameter integer OUT_W = 16
)(
	input wire	clk, //Fs_mod(5.12 MHz)
	input wire	rst_n,
	input wire	din, //bitstream 1-bit
	output wire signed [OUT_W-1:0] dout, //uscita 16-bit @Fs_out
	output wire	dout_valid
);
	// --- CIC ---
	wire signed [CIC_W-1:0] cic_out;
	wire cic_valid;

	cic_decimator #(
		.STAGES(CIC_STAGES), .R(CIC_R), .WIDTH(CIC_W)
	) u_cic (
		.clk(clk), .rst_n(rst_n), .din(din),
		.dout(cic_out), .dout_valid(cic_valid)
	);
	
	// --- FIR compensatore + decimazione/2 ---
	fir_comp #(
		.NTAPS(FIR_NTAPS), .D(FIR_D), .COEF_BITS(COEF_BITS),
		.DIN_W(CIC_W), .OUT_W(OUT_W)
	) u_fir (
		.clk(clk), .rst_n(rst_n), 
		.din_valid(cic_valid), .din(cic_out),
		.dout(dout), .dout_valid(dout_valid)
	);
endmodule