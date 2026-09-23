// ==============================================================================
// fir_comp.v - FIR compensatore di droop + decimazione finale /D
// ------------------------------------------------------------------------------
// Coefficienti FIXED e simmetrici.
// Implementazione folded/symmetric:
//   h0*(x0+x14)
//   h1*(x1+x13)
//   h2*(x2+x12)
//   h3*(x3+x11)
//   h4*(x4+x10)
//   h5*(x5+x9)
//   h6*(x6+x8)
//   h7*x7
//
// Coefficienti quantizzati a COEF_BITS:
//   -3  -6  -14  -29  -51  -74  -93  2047
//  -93 -74  -51  -29  -14  -6   -3
//
// Somma coefficienti = 1507
//
// Ingresso : campioni dal CIC (signed, DIN_W bit)
// Uscita   : campioni filtrati e decimati /D (signed, OUT_W bit)
// ==============================================================================

module fir_comp #(
    parameter integer NTAPS     = 15,
    parameter integer D         = 2,
    parameter integer COEF_BITS = 12,
    parameter integer DIN_W     = 19,
    parameter integer OUT_W     = 16,
    parameter integer ACC_W     = 40,
    parameter integer SCALE_NUM = 32767,
    parameter integer SCALE_DEN = 132358
)(
    input wire clk,
    input wire rst_n,
    input wire din_valid,
    input wire signed [DIN_W-1:0] din,
    output reg signed [OUT_W-1:0] dout,
    output reg dout_valid
);

    // --------------------------------------------------------------------------
    // Coefficienti FIR FIXED
    // --------------------------------------------------------------------------

    localparam signed [COEF_BITS-1:0] H0 = -3;
    localparam signed [COEF_BITS-1:0] H1 = -6;
    localparam signed [COEF_BITS-1:0] H2 = -14;
    localparam signed [COEF_BITS-1:0] H3 = -29;
    localparam signed [COEF_BITS-1:0] H4 = -51;
    localparam signed [COEF_BITS-1:0] H5 = -74;
    localparam signed [COEF_BITS-1:0] H6 = -93;
    localparam signed [COEF_BITS-1:0] H7 = 2047;

    localparam integer COEF_SUM = 1507;

    // --------------------------------------------------------------------------
    // Delay line
    // --------------------------------------------------------------------------

    reg signed [DIN_W-1:0] taps [0:NTAPS-1];

    integer i;

    // --------------------------------------------------------------------------
    // Conversione esplicita a ACC_W bit
    // --------------------------------------------------------------------------

    function signed [ACC_W-1:0] sx_din;
        input signed [DIN_W-1:0] x;
        begin
            sx_din = x;
        end
    endfunction

    function signed [ACC_W-1:0] sx_coef;
        input signed [COEF_BITS-1:0] c;
        begin
            sx_coef = c;
        end
    endfunction

    // --------------------------------------------------------------------------
    // Contatore decimazione
    // --------------------------------------------------------------------------

    localparam integer DCNTW = (D <= 1) ? 1 : $clog2(D);

    reg [DCNTW-1:0] dcnt;

    // --------------------------------------------------------------------------
    // Accumulatore
    // --------------------------------------------------------------------------

    reg signed [ACC_W-1:0] acc;

    // --------------------------------------------------------------------------
    // FIR + decimazione
    // --------------------------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            for (i = 0; i < NTAPS; i = i + 1)
                taps[i] <= {DIN_W{1'b0}};

            dcnt       <= 0;
            dout       <= {OUT_W{1'b0}};
            dout_valid <= 1'b0;

        end else begin

            dout_valid <= 1'b0;

            if (din_valid) begin

                // Shift register
                for (i = NTAPS-1; i > 0; i = i - 1)
                    taps[i] <= taps[i-1];

                taps[0] <= din;

                // ------------------------------------------------------------------
                // FIR simmetrico:
                //
                // h0*(x0+x14)
                // h1*(x1+x13)
                // h2*(x2+x12)
                // h3*(x3+x11)
                // h4*(x4+x10)
                // h5*(x5+x9)
                // h6*(x6+x8)
                // h7*x7
                //
                // Rispetto alla forma diretta:
                // 15 moltiplicazioni -> 8 moltiplicazioni
                // ------------------------------------------------------------------

                acc = (sx_din(din) + sx_din(taps[14])) * sx_coef(H0);
                acc = acc + (sx_din(taps[1]) + sx_din(taps[13])) * sx_coef(H1);
                acc = acc + (sx_din(taps[2]) + sx_din(taps[12])) * sx_coef(H2);
                acc = acc + (sx_din(taps[3]) + sx_din(taps[11])) * sx_coef(H3);
                acc = acc + (sx_din(taps[4]) + sx_din(taps[10])) * sx_coef(H4);
                acc = acc + (sx_din(taps[5]) + sx_din(taps[9]))  * sx_coef(H5);
                acc = acc + (sx_din(taps[6]) + sx_din(taps[8]))  * sx_coef(H6);
                acc = acc + sx_din(taps[7]) * sx_coef(H7);

                // ------------------------------------------------------------------
                // Decimazione /D
                // ------------------------------------------------------------------

                if (dcnt == 0) begin

                    dcnt <= D-1;

                    dout <= scale_and_sat(
                        floor_div_pos(acc, COEF_SUM)
                    );

                    dout_valid <= 1'b1;

                end else begin

                    dcnt <= dcnt - 1'b1;

                end
            end
        end
    end

    // ==========================================================================
    // Divisione floor con denominatore positivo
    // ==========================================================================

    function signed [ACC_W-1:0] floor_div_pos;
        input signed [ACC_W-1:0] num;
        input signed [ACC_W-1:0] den;

        reg signed [ACC_W-1:0] q;
        reg signed [ACC_W-1:0] r;

        begin
            q = num / den;
            r = num % den;

            // Verilog tronca verso zero.
            // Python // con denominatore positivo fa floor.
            if ((num < 0) && (r != 0))
                q = q - 1;

            floor_div_pos = q;
        end
    endfunction

    // ==========================================================================
    // Scaling + arrotondamento + saturazione
    // ==========================================================================

    function signed [OUT_W-1:0] scale_and_sat;
        input signed [ACC_W-1:0] v;

        reg signed [ACC_W-1:0] scaled;
        reg signed [ACC_W-1:0] num;
        reg signed [ACC_W-1:0] den;

        begin
            num = v * SCALE_NUM;
            den = SCALE_DEN;

            // Arrotondamento al valore intero più vicino.
            if (num >= 0)
                scaled = (num + den/2) / den;
            else
                scaled = (num - den/2) / den;

            scale_and_sat = sat(scaled);
        end
    endfunction

    // ==========================================================================
    // Saturazione signed a OUT_W bit
    // ==========================================================================

    function signed [OUT_W-1:0] sat;
        input signed [ACC_W-1:0] v;

        reg signed [ACC_W-1:0] maxv;
        reg signed [ACC_W-1:0] minv;

        begin

            maxv = (1 <<< (OUT_W-1)) - 1;
            minv = -(1 <<< (OUT_W-1));

            if (v > maxv)
                sat = maxv[OUT_W-1:0];

            else if (v < minv)
                sat = minv[OUT_W-1:0];

            else
                sat = v[OUT_W-1:0];

        end
    endfunction

endmodule
