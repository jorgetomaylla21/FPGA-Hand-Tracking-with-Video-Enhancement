`default_nettype none
`timescale 1ns/1ps

module video_sig_gen #(
    parameter ACTIVE_H_PIXELS = 1280,
    parameter H_FRONT_PORCH = 110,
    parameter H_SYNC_WIDTH = 40,
    parameter H_BACK_PORCH = 220,
    parameter ACTIVE_LINES = 720,
    parameter V_FRONT_PORCH = 5,
    parameter V_SYNC_WIDTH = 5,
    parameter V_BACK_PORCH = 20
    ) (  
    input wire clk_pixel_in,
    input wire rst_in,
    output logic [$clog2(TOTAL_PIXELS)-1:0] hcount_out,
    output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
    output logic vs_out,
    output logic hs_out,
    output logic ad_out,
    output logic nf_out,
    output logic [5:0] fc_out
    );

    localparam TOTAL_PIXELS = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH;
    localparam TOTAL_LINES  = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH;
    
    logic old_rst;

    always_ff @(posedge clk_pixel_in) begin
        old_rst <= rst_in;

        if (rst_in) begin
        // total reset
        hcount_out <= 0;
        vcount_out <= 0;
        vs_out     <= 0;
        hs_out     <= 0;
        ad_out     <= 0;
        nf_out     <= 0;
        fc_out     <= 0;

        end else if (old_rst) begin
        ad_out     <= 1;

        end else begin

        // frame count controller
        if (nf_out) begin
            // active for a single cycle only
            nf_out <= 1'b0;

        end else if (hcount_out==ACTIVE_H_PIXELS-1 && vcount_out==ACTIVE_LINES) begin
            // frame count changes here
            fc_out <= fc_out + 1;
            nf_out <= 1'b1;
        end

        // hcount, vcount
        if (hcount_out == TOTAL_PIXELS - 1) begin
            // reached end of horizontal line
            hcount_out <= 0;
            
            if (vcount_out == TOTAL_LINES-1) begin
                // End of a frame
                vcount_out <= 0;
            end else begin
                vcount_out <= vcount_out + 1;
            end

            //vsync
            if (vcount_out == ACTIVE_LINES + V_FRONT_PORCH -1) begin
                vs_out <= 1;
            end else if (vcount_out == ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH -1) begin
                vs_out <= 0;
            end

        end else begin
            hcount_out <= hcount_out + 1;
        end

        //hsync
        hs_out <= (hcount_out >= ACTIVE_H_PIXELS + H_FRONT_PORCH -1
                && hcount_out < ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH -1);
        
        // active data signal
        if (hcount_out==TOTAL_PIXELS-1 && 
        (vcount_out==TOTAL_LINES-1 || vcount_out < ACTIVE_LINES-1)) begin
            ad_out <= 1;
        end else if (hcount_out == ACTIVE_H_PIXELS -1) begin
            ad_out <= 0;
        end

    end
  end

endmodule

`default_nettype wire