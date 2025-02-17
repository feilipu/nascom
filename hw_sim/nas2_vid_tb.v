module nas_video_tb
  (
   );

    reg clk;
    reg reset_n;
    time frame_start;

    // UUT
    nas_vid u_nas_vid
      ( // Out
        .clk_cpu (),
        .to_ic32_p12 (),
        .to_lk4 (),

        .vid_sync(),
        .vid_data(),

        // In
        .clk (clk),
        .vdusel_n (1'b1),
        .wr_n  (1'b1),
        .rd_n  (1'b1),
        .cpu_d (8'b0),
        .cpu_a (16'b0)
        );

    initial begin
        frame_start = 0;
        reset_n = 1'b0;
        // CHEAT for debug
//        force u_nas_vid.allow_feedback = 1'b0;

        clk = 1'b0;
        #31.250;                 // 16MHz half period is 31.25ns
        clk = 1'b1;
        #31.250;
        clk = 1'b0;
        #31.250;
        reset_n = 1'b1;
        forever begin
            clk = 1'b1;
            #31.250;
            clk = 1'b0;
            #31.250;
        end
    end

    integer i;
    initial begin
        $timeformat(-9, 3, "ns", 20);
        $dumpfile("nas2_vid_tb.vcd");
        $dumpvars(0,nas_video_tb);
        for (i = 1; i<10; i=i+1) begin
            $display("%d..", i);
            #10000000;
        end
        $display("End");
        $finish();
    end

    // This signal is glitchy. Need to filter it in order
    // to detect and report the frame periof correctly.
    wire      active_v_filtered;
    assign    #4 active_v_filtered = u_nas_vid.active_v;

    always @(posedge active_v_filtered) begin
        if (frame_start != 0) begin
            $display("Frame period is %t",$time - frame_start);
        end
        frame_start = $time;
    end

endmodule // nas_video_tb
