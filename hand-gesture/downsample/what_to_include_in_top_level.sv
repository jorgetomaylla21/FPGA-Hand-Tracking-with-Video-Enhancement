// downsample_sig_gen
logic [10:0] hcount_ds, hcount_ds_pipe;
logic [9:0] vcount_ds, vcount_ds_pipe;
logic valid_ds, valid_ds_pipe;

// rotate module (Done)
logic valid_addr_rot;
logic [16:0] img_addr_rot;

//values from the frame buffer: Done
logic [15:0] frame_buff_raw; //output of frame buffer (direct)
logic [15:0] frame_buff; //output of frame buffer OR black (based on pipeline valid)

//remapped frame_buffer outputs with 8 bits for r, g, b
logic [7:0] fb_red, fb_green, fb_blue;
logic [7:0] fb_red_pipe, fb_green_pipe, fb_blue_pipe;
logic [7:0] fb_red_pipe_2, fb_green_pipe_2, fb_blue_pipe_2;

// For threshold downsampling 
logic [10:0] hcount_ds_write;
logic [9:0]  vcount_ds_write;
logic [12:0] downsample_write_addr;
logic mask_ds, valid_ds_write;


video_sig_gen mvg(
    .clk_pixel_in(clk_pixel),
    .rst_in(sys_rst),
    .hcount_out(hcount),
    .vcount_out(vcount),
    .vs_out(vert_sync),
    .hs_out(hor_sync),
    .ad_out(active_draw),
    .nf_out(new_frame),
    .fc_out(frame_count)
);

downsample_sig_gen dssg_m (
    .clk_in(clk_pixel),
    .hcount_in(hcount),
    .vcount_in(vcount),
    .hcount_ds_out(hcount_ds),
    .vcount_ds_out(vcount_ds),
    .valid_ds_out(valid_ds)
);

// Rotate address
rotate rotate_m (
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .hcount_in(hcount_ds),
    .vcount_in(vcount_ds),
    .valid_addr_in(valid_ds),
    .pixel_addr_out(img_addr_rot),
    .valid_addr_out(valid_addr_rot)
);

xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(16), //each entry in this memory is 16 bits
    .RAM_DEPTH(320*240)) //there are 240*320 or 76800 entries for full frame
frame_buffer (
    .addra(hcount_rec + 320*vcount_rec), //pixels are stored using this math
    .clka(clk_pixel),
    .wea(data_valid_rec),
    .dina(pixel_data_rec),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(img_addr_rot),//transformed lookup pixel
    .dinb(16'b0),
    .clkb(clk_pixel),
    .web(1'b0),
    .enb(valid_addr_rot),
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb(frame_buff_raw)
);

always_ff @(posedge clk_pixel)begin
    valid_addr_rot_pipe[0] <= valid_addr_rot;
    valid_addr_rot_pipe[1] <= valid_addr_rot_pipe[0];
end
assign frame_buff = valid_addr_rot_pipe[1]?frame_buff_raw:16'b0;

//split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
assign fb_red = {frame_buff[15:11],3'b0};
assign fb_green = {frame_buff[10:5], 2'b0};
assign fb_blue = {frame_buff[4:0],3'b0};

// ** IMPORTANT ** 
// TODO: connect fb_red, fb_green, fb_blue to the thresholding module sequence
//        from the lab (frame_buff(we're here) -> YCrCb -> Channel Select -> threshold (see below))
// The most important thing is to pipeline "valid_addr_rot" to "downsample_threshold" module
// (Note that valid_addr_rot_pipe[1] is pipelined up to frame_buff variable)

threshold(
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .pixel_in(selected_channel),
    .lower_bound_in(lower_threshold),
    .upper_bound_in(upper_threshold),
    .mask_out(mask) //single bit if pixel within mask.
);

downsample_threshold downsample_threshold_m (
    .clk_in(clk_pixel),
    .valid_ds_in(),         // TODO: *IMPORTANT* pipeline valid bit upto here
    .threshold_ds_in(),     // TODO: Choose downsampling threshold value (can use sw[~] or a fixed value)
    .mask_in(mask),

    .mask_ds_out(mask_ds),  // Thresholded patch value (1 for over threshold, otherwise 0)
    .hcount_write_out(hcount_ds_write),
    .vcount_write_out(vcount_ds_write),
    .valid_mask_out(valid_ds_write)
);

// convert 64 (width) x 48 (height) counters to write address
// TODO: Change x64 to bit shift if you want; but may not be flexible for different filter sizes other than 5
assign downsample_write_addr = hcount_ds_write + vcount_ds_write * 64;  

xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(1), // 1 bit for valid
    .RAM_DEPTH(64*48)) // (320/5)x(240/5) = 64x48 = 3072 pixels
downsampled_frame_buffer (
    .addra(downsample_write_addr),
    .clka(clk_pixel),
    .wea(valid_ds_write),
    .dina(mask_ds),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(sys_rst),
    .douta(), //never read from this side
    .addrb(),               // TODO: lookup address
    .dinb(16'b0),
    .clkb(clk_pixel),
    .web(1'b0),
    .enb(valid_addr_rot),   // TODO: lookup valid
    .rstb(sys_rst),
    .regceb(1'b1),
    .doutb()                // TODO: output read data
);