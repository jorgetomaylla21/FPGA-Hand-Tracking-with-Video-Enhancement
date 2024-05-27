`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
 
module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);
 
  logic [8:0] q_m;
  logic [3:0] qm_digit_sum;
  logic [4:0] tally;
 
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

  always_comb begin
    // N_1[q_m]
    qm_digit_sum = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                   q_m[4] + q_m[5] + q_m[6] + q_m[7];
  end
  
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        tally <= 0;
        tmds_out <= 0;
    end else if (!ve_in) begin
        // video encode off; return sync signal
        tally <= 0;
        case (control_in)
            2'b00: tmds_out <= 10'b1101010100;
            2'b01: tmds_out <= 10'b0010101011;
            2'b10: tmds_out <= 10'b0101010100;
            2'b11: tmds_out <= 10'b1010101011;
            default: tmds_out <= 10'b0;
        endcase

    end else begin
        if (tally == 0 || qm_digit_sum == 4) begin
            tmds_out[9] <= ~q_m[8];
            tmds_out[8] <= q_m[8];
            tmds_out[7:0] <= (q_m[8])? q_m[7:0]:
                                       ~q_m[7:0];

            if (!q_m[8]) begin
                // True, tally += N_0 - N_1 (== 8 - 2 * N_1)
                tally <= tally + 5'd8 - {qm_digit_sum, 1'b0};
            end else begin
                // False, tally += N_1 - N_0 (== 2 * N_1 -8)
                tally <= tally - 5'd8 + {qm_digit_sum, 1'b0};
            end

        end else if ((!tally[4] && qm_digit_sum > 4) 
        || (tally[4] && qm_digit_sum < 4)) begin 
            // True- Invert q_m[7:0] digits
            tmds_out[9] <= 1;
            tmds_out[8] <= q_m[8];
            tmds_out[7:0] <= ~q_m[7:0];

            // += 2*q_m[8] + (N_0 - N_1)
            tally <= tally + {q_m[8],1'b0} + 5'd8 - {qm_digit_sum, 1'b0};

        end else begin
            // False- Don't Invert
            tmds_out[9] <= 0;
            tmds_out[8] <= q_m[8];
            tmds_out[7:0] <= q_m[7:0];

            // += 2*q_m[8] + (N_0 - N_1)
            tally <= tally - {~q_m[8],1'b0} - 5'd8 + {qm_digit_sum, 1'b0};

        end

    end
  end
 
endmodule


// TM CHOICE SUBMODULE
module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

    logic [3:0] digit_sum;

    always_comb begin

        // digit sum for counting number of 1s
        digit_sum = data_in[0];
        for (int i=1; i<8; i++) begin
            digit_sum = digit_sum + data_in[i];
        end

        // lsb
        qm_out[0] = data_in[0];

        // branch for XOR, XNOR
        if (digit_sum > 4 || (digit_sum==4 && !data_in[0])) begin
            // True: XNOR
            for (int i=1; i<8; i++) begin
                qm_out[i] = ~(qm_out[i-1] ^ data_in[i]);
            end
            qm_out[8] = 1'b0;

        end else begin
            // False: XOR
            for (int i=1; i<8; i++) begin
                qm_out[i] = (qm_out[i-1] ^ data_in[i]);
            end
            qm_out[8] = 1'b1;

        end
    end


endmodule //end tm_choice
 
`default_nettype wire