module video_sig_gen
#(
  parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  parameter V_FRONT_PORCH = 5,
  parameter V_SYNC_WIDTH = 5,
  parameter V_BACK_PORCH = 20)
(
  input wire clk_pixel_in,
  input wire rst_in,
  output logic [$clog2(TOTAL_PIXELS)-1:0] hcount_out,
  output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
  output logic vs_out,
  output logic hs_out,
  output logic ad_out,
  output logic nf_out,
  output logic [5:0] fc_out);
 
  localparam TOTAL_PIXELS = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH; //figure this out (change me)
  localparam TOTAL_LINES = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH; //figure this out (change me)
  logic rst_previous;
  logic h_blanking1;
  logic v_blanking;
  //your code here
  always_ff @(posedge clk_pixel_in ) begin
    if (rst_in) begin
        hcount_out <= 0;
        vcount_out <= 0;
        vs_out <= 0;
        hs_out <= 0;
        ad_out <= 0;
        nf_out <= 0;
        fc_out <= 0;
        h_blanking1 <= 0;
        v_blanking <= 0;
        rst_previous <= rst_in;
    end else begin
        //on the first rising clock after reset is low
        if (rst_previous == 1 && rst_in == 0) begin
            ad_out <= 1;
            rst_previous <= rst_in;
            //equivalent to resetting everything to 0 now, check future behavior

        end else begin
            if (vcount_out < ACTIVE_LINES) begin
                //in the active draw stage
                if (ad_out) begin
                    if (hcount_out == ACTIVE_H_PIXELS - 1) begin
                        ad_out <= 0;
                        h_blanking1 <= 1;
                    end 
                    //always increase the horizontal count during active draw
                    hcount_out <= hcount_out + 1;
                    
                end else begin
                    if (h_blanking1) begin
                        if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH - 1) begin
                            hs_out <= 1;
                            h_blanking1 <= 0;
                        end
                        hcount_out <= hcount_out + 1;
                    end else if (hs_out) begin
                        if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH - 1) begin
                            hs_out <= 0;
                        end
                        hcount_out <= hcount_out + 1;
                    end else begin
                        // we are in the second blanking period
                        if (hcount_out == TOTAL_PIXELS - 1) begin  
                            if (vcount_out == ACTIVE_LINES - 1) begin
                                v_blanking <= 1;
                                hcount_out <= 0;
                                vcount_out <= vcount_out + 1;
                            end  else begin                  
                                hcount_out <= 0;
                                ad_out <= 1;
                                vcount_out <= vcount_out + 1;
                            end
                        end else begin
                            hcount_out <= hcount_out + 1;
                        end
                    end
                end
            end else if (v_blanking) begin
                //first vertical blanking

                //nfout must last for 1 cycle
                if(nf_out) begin
                    nf_out <= 0;
                end
                //defining new frame out
                if(hcount_out == ACTIVE_H_PIXELS-1) begin
                    if (vcount_out == ACTIVE_LINES) begin
                        if (fc_out == 59)  begin
                            fc_out <= 0;
                        end else begin
                            fc_out <= fc_out + 1;
                        end
                        nf_out <= 1;         
                    end
                end
                if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH - 1) begin
                    hs_out <= 1;
                end
                if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH - 1) begin
                    hs_out <= 0;
                end

                if (hcount_out == TOTAL_PIXELS - 1) begin
                    if (vcount_out == ACTIVE_LINES + V_FRONT_PORCH - 1) begin
                        v_blanking <= 0;
                        vs_out <= 1;
                    end
                    vcount_out <= vcount_out + 1;
                    hcount_out <= 0;
                end else begin
                    hcount_out <= hcount_out + 1;
                end
            end else if (vs_out) begin
                //keeping hsout cycle
                if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH - 1) begin
                    hs_out <= 1;
                end
                if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH - 1) begin
                    hs_out <= 0;
                end

                if (hcount_out == TOTAL_PIXELS - 1) begin
                    if (vcount_out == ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH - 1) begin        
                        vs_out <= 0;
                    end
                    vcount_out <= vcount_out + 1;
                    hcount_out <= 0;
                end else begin
                    hcount_out <= hcount_out + 1;
                end
            end else begin
                //second vertical blanking
                //keeping hsout cycle
                if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH - 1) begin
                    hs_out <= 1;
                end
                if (hcount_out == ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH - 1) begin
                    hs_out <= 0;
                end
                //actual second blanking behavior
                if (hcount_out == TOTAL_PIXELS - 1) begin
                    if (vcount_out == TOTAL_LINES - 1) begin        
                        ad_out <= 1;
                        vcount_out <= 0;
                    end else begin
                        vcount_out <= vcount_out + 1;
                    end
                    hcount_out <= 0;

                end else begin
                    hcount_out <= hcount_out + 1;
                end
            end
        end
    end
  end
 
endmodule