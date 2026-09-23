// ==============================================================================
// cic_decimator.v
// CIC sinc^N decimator
//
// Ingresso : 1-bit Sigma-Delta {0,1} @ Fs_mod
// Interno  : N integratori signed con wrap-around
// Decima   : R
// Uscita   : N comb signed @ Fs_mod/R
//
// Per il progetto:
//   STAGES = 3
//   R      = 64
//   WIDTH  = 19
//
// Il modulo è implementato in modo bit-accurate rispetto al golden model:
//   x = 0 -> -1
//   x = 1 -> +1
//
// Gli integratori usano il valore aggiornato dello stadio precedente.
// ==============================================================================

module cic_decimator #(
    parameter integer STAGES = 3,
    parameter integer R      = 64,
    parameter integer WIDTH  = 19
)(
    input wire clk,
    input wire rst_n,
    input wire din,

    output reg signed [WIDTH-1:0] dout,
    output reg dout_valid
);

    integer i;
    integer j;

    // --------------------------------------------------------------------------
    // Mapping 1-bit -> signed bipolar
    //
    // din = 1 -> +1
    // din = 0 -> -1
    // --------------------------------------------------------------------------

    wire signed [WIDTH-1:0] x_in;

    assign x_in = din
                ? {{(WIDTH-1){1'b0}}, 1'b1}
                : {WIDTH{1'b1}};


    // --------------------------------------------------------------------------
    // Integratori
    // --------------------------------------------------------------------------

    reg signed [WIDTH-1:0] integ [0:STAGES-1];

    // Valori successivi degli integratori.
    // Questo array è combinatorio e permette allo stadio successivo
    // di utilizzare il valore aggiornato dello stadio precedente.
    reg signed [WIDTH-1:0] integ_next [0:STAGES-1];


    // --------------------------------------------------------------------------
    // Calcolo combinatorio della cascata degli integratori
    //
    // integ_next[0] = integ[0] + x
    // integ_next[1] = integ[1] + integ_next[0]
    // integ_next[2] = integ[2] + integ_next[1]
    //
    // Con WIDTH=19 il risultato viene automaticamente mantenuto a 19 bit:
    // questo realizza il wrap-around two's complement del golden model.
    // --------------------------------------------------------------------------

    always @(*) begin

        integ_next[0] = integ[0] + x_in;

        for (i = 1; i < STAGES; i = i + 1)
            integ_next[i] = integ[i] + integ_next[i-1];

    end


    // --------------------------------------------------------------------------
    // Contatore di decimazione
    //
    // cnt = 0:
    //   produci il campione CIC
    //
    // poi cnt = R-1, R-2, ..., 0
    //
    // Quindi le uscite corrispondono a:
    //
    // integrated[0]
    // integrated[R]
    // integrated[2R]
    // ...
    //
    // esattamente come integrated[::R] nel golden model.
    // --------------------------------------------------------------------------

    localparam integer CNTW = (R <= 1) ? 1 : $clog2(R);

    reg [CNTW-1:0] cnt;


    // --------------------------------------------------------------------------
    // Comb
    // --------------------------------------------------------------------------

    reg signed [WIDTH-1:0] comb_prev [0:STAGES-1];
    reg signed [WIDTH-1:0] comb_val;


    // --------------------------------------------------------------------------
    // Registri CIC
    // --------------------------------------------------------------------------

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            for (j = 0; j < STAGES; j = j + 1) begin
                integ[j]    <= {WIDTH{1'b0}};
                comb_prev[j] <= {WIDTH{1'b0}};
            end

            cnt         <= {CNTW{1'b0}};
            dout        <= {WIDTH{1'b0}};
            dout_valid  <= 1'b0;

        end else begin

            // --------------------------------------------------------------
            // Aggiorna gli integratori
            // --------------------------------------------------------------

            for (j = 0; j < STAGES; j = j + 1)
                integ[j] <= integ_next[j];


            dout_valid <= 1'b0;


            // --------------------------------------------------------------
            // Decimazione
            // --------------------------------------------------------------

            if (cnt == 0) begin

                // ----------------------------------------------------------
                // Il campione selezionato deve essere integ_next, cioè
                // il valore degli integratori DOPO l'acquisizione di din.
                // Questo corrisponde a integrated[n] nel golden model.
                // ----------------------------------------------------------

                comb_val = integ_next[STAGES-1];


                // ----------------------------------------------------------
                // Cascata comb
                //
                // stage 0:
                //   y0[n] = x[n] - x[n-1]
                //
                // stage 1:
                //   y1[n] = y0[n] - y0[n-1]
                //
                // ...
                // ----------------------------------------------------------

                for (j = 0; j < STAGES; j = j + 1) begin

                    comb_prev[j] <= comb_val;

                    comb_val = comb_val - comb_prev[j];

                end


                dout       <= comb_val;
                dout_valid <= 1'b1;


                // prossimo campione dopo R ingressi
                cnt <= R-1;

            end else begin

                cnt <= cnt - 1'b1;

            end

        end
    end

endmodule
