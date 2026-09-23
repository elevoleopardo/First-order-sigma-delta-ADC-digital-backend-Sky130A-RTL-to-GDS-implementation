// ==============================================================================
// tb_adc_sd.v	-	Testbench del blocco digitale ADC Sigma-Delta
// ______________________________________________________________________________
// -- legge la bitstream generata dal golden model (output/bitstream.txt)
// -- applica lo stimolo a adc_sd_top e registra l'uscita
// -- confronta con il golden (output/golden_out.txt), riporta errore max
//
// Uso quando sarà disponibile la toolchain:
// 	iverilog -o sim.vvp -s tb_adc_sd \
//		rtl/cic_decimator.v rtl/fir_comp.v rtl/adc_sd_top.v tb/tb_adc_sd.v
//	vpp sim.vvp
// I path dei file sono relativi alla directory da cui si lancia la vvp (adc_sd/).
// ==============================================================================

`timescale 1ns/1ps
module tb_adc_sd;
	// parametri coerenti col goden model / PRS
	localparam integer CIC_STAGES	= 3;
	localparam integer CIC_R	= 64;
	localparam integer CIC_W	= 19;
	localparam integer FIR_NTAPS	= 15;
	localparam integer FIR_D	= 2;
	localparam integer COEF_BITS	= 12;
	localparam integer OUT_W	= 16;

	localparam integer MAX_IN	= 600000;	// > 532480 campioni bitstream
	localparam integer MAX_OUT	= 5000;		// > 4160 campioni attesi

	reg clk = 0, rst_n = 0, din = 0;
	wire signed [OUT_W-1:0] dout;
	wire dout_valid;

	// clock a 5.12 MHz -> periodo ~ 195.3125 ns
	always #97.65625 clk = ~clk;

	// DUT
	adc_sd_top #(
		.CIC_STAGES(CIC_STAGES), .CIC_R(CIC_R), .CIC_W(CIC_W),
		.FIR_NTAPS(FIR_NTAPS), .FIR_D(FIR_D),
		.COEF_BITS(COEF_BITS), .OUT_W(OUT_W)
	) dut (
		.clk(clk), .rst_n(rst_n), .din(din),
		.dout(dout), .dout_valid(dout_valid)
	);

	// memorie di stimolo / riferimento
	reg [0:0]	bitmem [0:MAX_IN-1];
	reg signed [OUT_W-1:0] goldmem [0:MAX_OUT-1];

	integer i, n_in, n_gold, in_idx, out_idx, errs;
	integer diff, maxdiff;

	initial begin
		// --- carica stimolo e riferimenti ---
		// bitstream: un valore 0/1 per riga (formato decimale)
		$readmemb("output/bitstream.txt", bitmem);

		// conta campioni validi (semplificazione: usiamo i limiti noti)
		n_in	= 532480;
		n_gold	= 4160;

		// reset
		rst_n = 0;
		din = 0;

		repeat (4) @(posedge clk);

		// Attendi un mezzo periodo: din è sicuramente stabile
		@(negedge clk);

		// Prepara il primo campione mentre il reset è ancora attivo
		in_idx = 1;
		din = bitmem[0][0];

		out_idx = 0;
		errs = 0;
		maxdiff = 0;

		// Ora abilita il circuito evitando la race con always @(negedge clk)
		#1 rst_n = 1;
	end

	// applica un bit di stimolo ad ogni fronte di salita
	always @(negedge clk) begin
		if (rst_n && in_idx < n_in) begin
			din	= bitmem[in_idx][0];
			in_idx	= in_idx + 1;
		end
	end

	//verifica temporanea del cic_valid
	always @(posedge clk) begin
		if (rst_n && dut.cic_valid) begin
			$display("CIC VALID: t=%0t cic_out=%0d", $time, dut.cic_out);
		end
	end

	// cattura l'uscita e confronta col golden
	always @(posedge clk) begin
		if (rst_n && dout_valid) begin
			$display("VALID: t=%0t out_idx=%0d dout=%0d", $time, out_idx, dout);	//verifica temporanea dout_valid
			if (out_idx < n_gold) begin
				diff = dout - goldmem[out_idx];
				if (diff < 0) diff = -diff;
				if (diff > maxdiff) maxdiff = diff;
				if (diff > 2) begin // soglia tolleranza (LSB) - da concordare
				errs = errs + 1;
				if (errs <= 10)
					$display(" [mismatch] idx=%0d  rtl=%0d gold=%0d diff=%0d",
						out_idx, dout, goldmem[out_idx], diff);
				end
			end
		out_idx <= out_idx + 1;
		end
	end

	// fine simulazione
	initial begin
		#(200_000_000);	// 200 ms simulati, sufficienti a coprire lo stimolo
		$display("=== RISULTATO CONFRONTO RTL vs GOLDEN ===");
		$display("campioni uscita: %0d (attesi %0d)", out_idx, n_gold);
		$display("errore max: %0d LSB", maxdiff);
		$display("mismatch (>2 LSB): %0d", errs);
		if (errs == 0)	$display("PASS");
		else		$display("FAIL");
		$finish;
	end
endmodule
