`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

 module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );
  //perform the sum
  logic[3:0] ones;
 always_comb begin
    ones = 0;
    for (integer i=0; i < 8; i++ ) begin
        if (data_in[i]) begin
            ones = ones + 1;
        end
    end  
    qm_out[0] = data_in[0];
    if (ones > 4 || (ones == 4 && !data_in[0] ))begin
        //option 2
        for (integer j = 1; j < 8; j++) begin
            qm_out[j] = !(data_in[j] ^ qm_out[j-1]);
        end
        qm_out[8] = 0;
    end else begin
        //option 1
        for (integer j = 1; j < 8; j++) begin
            qm_out[j] = data_in[j] ^ qm_out[j-1];
        end
        qm_out[8] = 1;
    end
 end
    
endmodule

module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);
 
  logic [8:0] q_m;
  logic [4:0] tally;
  logic [3:0] ones;
  logic [3:0] zeros;

  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));
 
  //your code here.

  always_comb begin
    ones = 0;
    
    for (integer i = 0; i < 8; i++) begin
                if (q_m[i]) begin
                    ones = ones + 1;
                end
            end
        zeros = 8 - ones;
  end
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        tmds_out <= 0;
        tally <= 0;
    end else begin
        if (ve_in) begin
            //HDMI state machine 
            //find tally combinationally/instantly
            
            if (tally == 0 || ones == zeros) begin
                //do True stuff
                tmds_out[9] <= ~(q_m[8]);
                tmds_out[8] <= q_m[8];
                tmds_out[7:0] <= (q_m[8]) ? q_m[7:0] : ~q_m[7:0];
                if(!q_m[8]) begin
                    tally <= tally + (zeros - ones);
                end else begin
                    tally <= tally + (ones - zeros);
                end
            end else begin
                if((tally[4] == 0 && ones > zeros) || (tally[4] == 1 && zeros > ones)) begin
                    //invert lower bits
                    tmds_out[9] <= 1;
                    tmds_out[8] <= q_m[8];
                    tmds_out[7:0] <= ~q_m[7:0];
                    tally <= tally + 2 * q_m[8] + (zeros - ones);
                end else begin
                    tmds_out[9] <= 0;
                    tmds_out[8] <= q_m[8];
                    tmds_out[7:0] <= q_m[7:0];
                    tally <= tally - 2 *(!q_m[8]) + (ones - zeros);
                end
            end

            //tally <= ~(ones - zeros) + 1 // two's complement

        end else begin
            tally <= 0;
            case(control_in)
                2'b00: tmds_out <= 10'b1101010100;
                2'b01: tmds_out <= 10'b0010101011;
                2'b10: tmds_out <= 10'b0101010100;
                default: tmds_out <= 10'b1010101011;
            endcase
        end
    end
  end
 
endmodule
 




`default_nettype wire