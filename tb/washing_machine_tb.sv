`timescale 1ns/1ps

module washing_machine_tb;
    logic clk = 1'b0;
    logic rst_n;
    logic coin_inserted, cancel;
    logic [1:0] mode_select;
    logic water_inlet, water_outlet, motor_enable, motor_mode;
    logic detergent_release, door_lock, refund_coin, busy, done;

    washing_machine_controller dut (.*);

    always #5 clk = ~clk;

    task automatic reset_dut;
        rst_n = 1'b0;
        coin_inserted = 1'b0;
        cancel = 1'b0;
        mode_select = 2'd0;
        repeat (2) @(posedge clk);
        rst_n = 1'b1;
    endtask

    task automatic start_cycle(input logic [1:0] mode);
        @(posedge clk);
        mode_select = mode;
        coin_inserted = 1'b1;
        @(posedge clk);
        coin_inserted = 1'b0;
    endtask

    task automatic run_mode(input logic [1:0] mode, input string name);
        reset_dut();
        start_cycle(mode);
        wait (done);
        $display("[PASS] %s mode completed", name);
    endtask

    task automatic cancel_before_paid_cycle;
        reset_dut();
        start_cycle(2'd0);
        wait (dut.current_state == dut.SOAK);
        cancel = 1'b1;
        @(posedge clk);
        cancel = 1'b0;
        #1;
        if (!refund_coin) $fatal(1, "SOAK cancellation did not refund");
        if (dut.current_state != dut.IDLE) $fatal(1, "SOAK cancellation did not return IDLE");
        $display("[PASS] SOAK cancellation refunded coin");
    endtask

    task automatic cancel_during_wash;
        reset_dut();
        start_cycle(2'd0);
        wait (dut.current_state == dut.WASH);
        cancel = 1'b1;
        @(posedge clk);
        cancel = 1'b0;
        #1;
        if (refund_coin) $fatal(1, "WASH cancellation incorrectly refunded");
        wait (dut.current_state == dut.IDLE);
        $display("[PASS] WASH cancellation drained without refund");
    endtask

    initial begin
        reset_dut();
        if (dut.current_state != dut.IDLE) $fatal(1, "Reset did not enter IDLE");
        $display("[PASS] Reset enters IDLE");

        run_mode(2'd0, "SHORT");
        run_mode(2'd1, "MEDIUM");
        run_mode(2'd2, "LONG");
        cancel_before_paid_cycle();
        cancel_during_wash();

        $display("All washing-machine tests passed.");
        $finish;
    end

    always @(posedge clk) begin
        $display("[%0t] state=%0d busy=%0b done=%0b", $time,
                 dut.current_state, busy, done);
    end
endmodule
