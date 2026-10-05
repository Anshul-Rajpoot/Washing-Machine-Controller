// Moore FSM based washing machine controller with internal timing.
//
// The controller captures the selected wash mode in READY, then uses an
// internal counter to time SOAK, WASH, DRAIN, RINSE, and SPIN.

module washing_machine_controller (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       coin_inserted,
    input  logic       cancel,
    input  logic [1:0] mode_select,

    output logic       water_inlet,
    output logic       water_outlet,
    output logic       motor_enable,
    output logic       motor_mode,
    output logic       detergent_release,
    output logic       door_lock,
    output logic       refund_coin,
    output logic       busy,
    output logic       done
);
    localparam logic [1:0] SHORT  = 2'd0;
    localparam logic [1:0] MEDIUM = 2'd1;
    localparam logic [1:0] LONG   = 2'd2;

    localparam logic MOTOR_WASH = 1'b0;
    localparam logic MOTOR_SPIN = 1'b1;

    typedef enum logic [2:0] {
        IDLE, READY, SOAK, WASH, DRAIN, RINSE, SPIN, DONE
    } state_t;

    state_t current_state, next_state;
    logic [1:0] mode_reg;
    logic [4:0] soak_time, wash_time, drain_time, rinse_time, spin_time;
    logic [4:0] phase_time, timer_count;
    logic phase_done;
    logic cancel_during_cycle;

    always_comb begin
        unique case (mode_reg)
            SHORT: begin
                soak_time = 5'd3; wash_time = 5'd6; drain_time = 5'd1;
                rinse_time = 5'd3; spin_time = 5'd2;
            end
            MEDIUM: begin
                soak_time = 5'd6; wash_time = 5'd12; drain_time = 5'd3;
                rinse_time = 5'd6; spin_time = 5'd3;
            end
            LONG: begin
                soak_time = 5'd9; wash_time = 5'd18; drain_time = 5'd4;
                rinse_time = 5'd9; spin_time = 5'd5;
            end
            default: begin
                soak_time = 5'd3; wash_time = 5'd6; drain_time = 5'd1;
                rinse_time = 5'd3; spin_time = 5'd2;
            end
        endcase
    end

    always_comb begin
        phase_time = 5'd1;
        unique case (current_state)
            SOAK: phase_time = soak_time;
            WASH: phase_time = wash_time;
            DRAIN: phase_time = drain_time;
            RINSE: phase_time = rinse_time;
            SPIN: phase_time = spin_time;
            default: ;
        endcase
    end

    assign phase_done = timer_count >= (phase_time - 5'd1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            mode_reg <= SHORT;
            timer_count <= 5'd0;
            refund_coin <= 1'b0;
            cancel_during_cycle <= 1'b0;
        end else begin
            current_state <= next_state;

            if (current_state == READY) begin
                unique case (mode_select)
                    SHORT, MEDIUM, LONG: mode_reg <= mode_select;
                    default: mode_reg <= SHORT;
                endcase
            end

            refund_coin <= cancel &&
                ((current_state == READY) || (current_state == SOAK));

            if ((current_state == WASH && cancel) ||
                (current_state == DRAIN && cancel) ||
                (current_state == RINSE && cancel) ||
                (current_state == SPIN && cancel)) begin
                cancel_during_cycle <= 1'b1;
            end else if (next_state == IDLE) begin
                cancel_during_cycle <= 1'b0;
            end

            if (next_state != current_state) begin
                timer_count <= 5'd0;
            end else if ((current_state == SOAK) ||
                         (current_state == WASH) ||
                         (current_state == DRAIN) ||
                         (current_state == RINSE) ||
                         (current_state == SPIN)) begin
                if (!phase_done)
                    timer_count <= timer_count + 5'd1;
            end else begin
                timer_count <= 5'd0;
            end
        end
    end

    always_comb begin
        next_state = current_state;
        unique case (current_state)
            IDLE:  if (coin_inserted) next_state = READY;
            READY: if (cancel) next_state = IDLE; else next_state = SOAK;
            SOAK:  if (cancel) next_state = IDLE;
                   else if (phase_done) next_state = WASH;
            WASH:  if (cancel) next_state = DRAIN;
                   else if (phase_done) next_state = DRAIN;
            DRAIN: if (phase_done)
                       next_state = (cancel_during_cycle || cancel) ? IDLE : RINSE;
            RINSE: if (cancel) next_state = DRAIN;
                   else if (phase_done) next_state = SPIN;
            SPIN:  if (cancel) next_state = DRAIN;
                   else if (phase_done) next_state = DONE;
            DONE:  if (coin_inserted) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always_comb begin
        water_inlet = 1'b0;
        water_outlet = 1'b0;
        motor_enable = 1'b0;
        motor_mode = MOTOR_WASH;
        detergent_release = 1'b0;
        door_lock = 1'b0;
        busy = 1'b0;
        done = 1'b0;

        unique case (current_state)
            READY: begin busy = 1'b1; end
            SOAK: begin
                water_inlet = 1'b1; detergent_release = 1'b1;
                door_lock = 1'b1; busy = 1'b1;
            end
            WASH: begin
                motor_enable = 1'b1; door_lock = 1'b1; busy = 1'b1;
            end
            DRAIN: begin
                water_outlet = 1'b1; door_lock = 1'b1; busy = 1'b1;
            end
            RINSE: begin
                water_inlet = 1'b1; motor_enable = 1'b1;
                door_lock = 1'b1; busy = 1'b1;
            end
            SPIN: begin
                motor_enable = 1'b1; motor_mode = MOTOR_SPIN;
                water_outlet = 1'b1; door_lock = 1'b1; busy = 1'b1;
            end
            DONE: begin done = 1'b1; end
            default: ;
        endcase
    end
endmodule
