`default_nettype none
`timescale 1ns/1ps

module upscaled_frame_buffer #(
    parameter FRAME_WIDTH = 512
) (
    input wire clk_in,
    input wire rst_in,
    input wire [7:0] r_in [3:0][3:0], g_in [3:0][3:0], b_in [3:0][3:0],
    input wire valid_write_in,
    input wire valid_read_addr_in,
    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,
    output logic [7:0] r_out, g_out, b_out
);
    // Hold r, g, b values for 4 cycles (to update each column every cycle)
    logic [7:0] r_hold [3:0][3:0], g_hold [3:0][3:0], b_hold [3:0][3:0];
    logic [$clog2(FRAME_WIDTH)-1:0] write_address, read_address;
    logic write_enable;
    logic [23:0] write_single_col [3:0];
    logic [23:0] read_single_col [3:0];

    // hcount's LSBs as a read address
    assign read_address = hcount_in[$clog2(FRAME_WIDTH)-1:0];

    // First column of held pixel values are written to BRAM
    assign write_single_col[0] = {r_hold[0][0], g_hold[0][0], b_hold[0][0]};
    assign write_single_col[1] = {r_hold[1][0], g_hold[1][0], b_hold[1][0]};
    assign write_single_col[2] = {r_hold[2][0], g_hold[2][0], b_hold[2][0]};
    assign write_single_col[3] = {r_hold[3][0], g_hold[3][0], b_hold[3][0]};

    // Step 1: Write upscaled pixels to BRAM
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            write_address   <= 0;
            write_enable    <= 1'b0;
        end else begin
            // write address increment only when write is enabled
            write_address <= (write_enable)? write_address+1: 0;

            // write enable is on when valid_write
            // or off when writing is completed
            write_enable  <= (valid_write_in)? 1'b1 : (write_address >= FRAME_WIDTH-1)? 1'b0 : write_enable;

            // new array of pixels; store the input
            if (valid_write_in) begin
                r_hold <= r_in;
                g_hold <= g_in;
                b_hold <= b_in;

            end else begin
                // Shift held registers to left each cycle
                for (int i=0; i<3; i=i+1) begin
                    for (int j=0; j<4; j=j+1) begin
                        r_hold[j][i] <= r_hold[j][i+1];
                        g_hold[j][i] <= g_hold[j][i+1];
                        b_hold[j][i] <= b_hold[j][i+1];
                    end
                end
            end

        end
    end    

    // Step 2: Read pixel values of a vertical column and mux the right row (with v count)
    // TODO: replacing the subsequent comb. block into a case statement brings the following error
    //       [ERROR: [Synth 8-9570] illegal case item comparison of a packed type with an unpacked type]
    always_comb begin
        if (valid_read_addr_in) begin
            case (vcount_in[1:0])
                2'b00: {r_out, g_out, b_out} = read_single_col[0];
                2'b01: {r_out, g_out, b_out} = read_single_col[1];
                2'b10: {r_out, g_out, b_out} = read_single_col[2];
                2'b11: {r_out, g_out, b_out} = read_single_col[3];
            endcase
        end else begin
            {r_out, g_out, b_out} = 24'b0;
        end
    end

    // ========== BRAM Config ========== //
    // BRAM Port A: Write upscaled pixels
    //      Port B: Scan pixel values to display

    genvar i;
    generate
        for (i=0; i<4; i=i+1) begin
            xilinx_true_dual_port_read_first_2_clock_ram #(
                .RAM_WIDTH(24), // Color {8'b, 8'b, 8'b} is 24 bits wide
                .RAM_DEPTH(FRAME_WIDTH)) // Size of pixel row
                single_row_buffer (
                .addra(write_address),      
                .clka(clk_in),
                .wea(write_enable),
                .dina(write_single_col[i]),
                .ena(1'b1),
                .regcea(1'b1),
                .rsta(rst_in),
                .douta(),       // never read from this side
                .addrb(read_address),
                .dinb(24'b0),        // write data unnecessary
                .clkb(clk_in),
                .web(1'b0),     // disable writes
                .enb(valid_read_addr_in),
                .rstb(rst_in),
                .regceb(1'b1),
                .doutb(read_single_col[i])
            );
        end
    endgenerate
endmodule

`default_nettype wire