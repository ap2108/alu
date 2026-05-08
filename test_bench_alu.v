`define PASS 1'b1
`define FAIL 1'b0
`define NUM_TESTS 500

module test_bench_alu();

    // --------------------------------------------------------
    // DUT signals
    // --------------------------------------------------------
    reg         CLK, RST, CE, MODE, CIN;
    reg  [1:0]  INP_VALID;
    reg  [3:0]  CMD;
    reg  [7:0]  OPA, OPB;

    wire [15:0] RES;
    wire        ERR, OFLOW, COUT, G, E, L;

    // --------------------------------------------------------
    // Expected output fields (decoded per stimulus)
    // --------------------------------------------------------
    reg [15:0]  Exp_RES;
    reg         exp_cout, exp_e, exp_g, exp_l, exp_oflow, exp_err;
    reg [7:0]   Feature_ID;
    
    // --------------------------------------------------------
    // Comparison bundles  {RES,COUT,E,G,L,OFLOW,ERR} = 23 bits
    // --------------------------------------------------------
    wire [22:0] actual_bundle   = {RES, COUT, E, G, L, OFLOW, ERR};
    wire [22:0] expected_bundle = {Exp_RES, exp_cout, exp_e, exp_g, exp_l, exp_oflow, exp_err};

    // --------------------------------------------------------
    // Pass/fail counters
    // --------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;
    integer bit_idx;

    // --------------------------------------------------------
    // DUT
    // --------------------------------------------------------
    alu DUT (
        .clk       (CLK),
        .rst       (RST),
        .ce        (CE),
        .mode      (MODE),
        .inp_valid (INP_VALID),
        .cmd       (CMD),
        .ina       (OPA),
        .inb       (OPB),
        .cin       (CIN),
        .res       (RES),
        .err       (ERR),
        .oflow     (OFLOW),
        .cout      (COUT),
        .g         (G),
        .e         (E),
        .l         (L)
    );

    // --------------------------------------------------------
    // Clock: period = 120 time units
    // --------------------------------------------------------
    initial CLK = 0;
    always #60 CLK = ~CLK;
    
    // --------------------------------------------------------
    // Reset task
    // --------------------------------------------------------
    task do_reset;
        begin
            RST = 1; CE = 1;
            @(posedge CLK); #1;
            RST = 0;
        end
    endtask

    // --------------------------------------------------------
    // GLOBAL REGISTERS
    // --------------------------------------------------------
    reg [7:0]  opa_prev, opb_prev;
    reg [3:0]  cmd_prev;
    reg        cin_prev, ce_prev, mode_prev;
    reg [1:0]  iv_prev;
    reg [7:0]  fid_prev;

    reg [22:0] exp_prev;

    reg first_cycle;

    initial begin
        first_cycle = 1'b1;
    end


    task drive_and_check;
        input [7:0]  fid;
        input [7:0]  opa_in, opb_in;
        input [3:0]  cmd_in;
        input        cin_in, ce_in, mode_in;
        input [1:0]  iv_in;
        input [15:0] exp_res_in;
        input        exp_cout_in, exp_e_in, exp_g_in, exp_l_in, exp_oflow_in, exp_err_in;

        reg        pass;
        reg [22:0] act_bnd;

        begin

            // ----------------------------------------------------
            // SINGLE POSEDGE
            // ----------------------------------------------------
            @(posedge CLK);
            #1;

            // ----------------------------------------------------
            // CHECK PREVIOUS TRANSACTION
            // ----------------------------------------------------
            if (!first_cycle) begin

                act_bnd = actual_bundle;

                pass = 1'b1;

                for (bit_idx = 0; bit_idx < 23; bit_idx = bit_idx + 1) begin
                    if (exp_prev[bit_idx] !== 1'bx) begin
                        if (exp_prev[bit_idx] !== act_bnd[bit_idx])
                            pass = 1'b0;
                    end
                end

                if (pass) begin

                    $display("PASS | FID=%0d | OPA=%d OPB=%d CMD=%d MODE=%b INP_VALID=%2b | RES=%d COUT=%b EGL=%b%b%b OFLOW=%b ERR=%b",
                            fid_prev, opa_prev, opb_prev, cmd_prev,
                            mode_prev, iv_prev,
                            RES, COUT, E, G, L, OFLOW, ERR);

                    pass_count = pass_count + 1;

                end
                else begin

                    $write("FAIL | FID=%0d | OPA=%d OPB=%d CMD=%d MODE=%b INP_VALID=%2b |",
                            fid_prev, opa_prev, opb_prev, cmd_prev,
                            mode_prev, iv_prev);

                    $display(" [EXP/GOT: RES=%d/%d COUT=%b/%b EGL=%b%b%b/%b%b%b OFLOW=%b/%b ERR=%b/%b]",
                            exp_prev[22:7], RES,
                            exp_prev[6],    COUT,
                            exp_prev[5],    E,
                            exp_prev[4],    G,
                            exp_prev[3],    L,
                            exp_prev[2],    OFLOW,
                            exp_prev[1],    ERR);

                    fail_count = fail_count + 1;
                end
            end

            // ----------------------------------------------------
            // DRIVE NEW INPUTS
            // ----------------------------------------------------
            OPA       <= opa_in;
            OPB       <= opb_in;
            CMD       <= cmd_in;
            CIN       <= cin_in;
            CE        <= ce_in;
            MODE      <= mode_in;
            INP_VALID <= iv_in;

            Feature_ID <= fid;

            // ----------------------------------------------------
            // SAVE INPUTS FOR NEXT CYCLE DISPLAY
            // ----------------------------------------------------
            fid_prev   = fid;

            opa_prev   = opa_in;
            opb_prev   = opb_in;

            cmd_prev   = cmd_in;

            cin_prev   = cin_in;
            ce_prev    = ce_in;
            mode_prev  = mode_in;

            iv_prev    = iv_in;

            // ----------------------------------------------------
            // SAVE EXPECTED VALUES FOR NEXT CHECK
            // ----------------------------------------------------
            exp_prev = {
                exp_res_in,
                exp_cout_in,
                exp_e_in,
                exp_g_in,
                exp_l_in,
                exp_oflow_in,
                exp_err_in
            };

            first_cycle = 1'b0;

        end
    endtask
    
    // --------------------------------------------------------
    // Hardcoded stimulus application
    // --------------------------------------------------------
    initial begin
        RST = 0; CE = 1; MODE = 0; CMD = 0;
        OPA = 0; OPB = 0; CIN = 0; INP_VALID = 2'b11;
        do_reset();

        // Stimulus 1: FID=2
        drive_and_check(
            8'b00000010,          // feature_id
            8'b00001101, 8'b00000101,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 2: FID=3
        drive_and_check(
            8'b00000011,          // feature_id
            8'b10111010, 8'b01110011,  // opa, opb
            4'b0001,              // cmd
            1'b1, 1'b0, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 3: FID=4
        drive_and_check(
            8'b00000100,          // feature_id
            8'b10000010, 8'b11111111,  // opa, opb
            4'b0001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010000010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 4: FID=5
        drive_and_check(
            8'b00000101,          // feature_id
            8'b00110011, 8'b10111110,  // opa, opb
            4'b0101,              // cmd
            1'b0, 1'b0, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010000010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 5: FID=6
        drive_and_check(
            8'b00000110,          // feature_id
            8'b00110101, 8'b00111001,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001101110,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 6: FID=6
        drive_and_check(
            8'b00000110,          // feature_id
            8'b01010101, 8'b00101111,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010000100,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 7: FID=6
        drive_and_check(
            8'b00000110,          // feature_id
            8'b01100010, 8'b10011010,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011111100,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 8: FID=6
        drive_and_check(
            8'b00000110,          // feature_id
            8'b01001110, 8'b01011011,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010101001,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 9: FID=6
        drive_and_check(
            8'b00000110,          // feature_id
            8'b00101111, 8'b10111000,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011100111,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 10: FID=6
        drive_and_check(
            8'b00000110,          // feature_id
            8'b00010010, 8'b01010011,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001100101,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 11: FID=6
        drive_and_check(
            8'b00000110,          // feature_id
            8'b01000000, 8'b00011011,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001011011,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 12: FID=6
        drive_and_check(
            8'b00000110,          // feature_id
            8'b10110100, 8'b00111010,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011101110,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 13: FID=6
        drive_and_check(
            8'b00000110,          // feature_id
            8'b00010010, 8'b01110101,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010000111,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 14: FID=6
        drive_and_check(
            8'b00000110,          // feature_id
            8'b01011100, 8'b00111001,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010010101,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 15: FID=7
        drive_and_check(
            8'b00000111,          // feature_id
            8'b11011011, 8'b11110000,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011001011,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 16: FID=7
        drive_and_check(
            8'b00000111,          // feature_id
            8'b11001010, 8'b11010000,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010011010,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 17: FID=7
        drive_and_check(
            8'b00000111,          // feature_id
            8'b11101010, 8'b00110110,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000100000,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 18: FID=7
        drive_and_check(
            8'b00000111,          // feature_id
            8'b00101010, 8'b11010110,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 19: FID=7
        drive_and_check(
            8'b00000111,          // feature_id
            8'b11100100, 8'b11110011,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011010111,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 20: FID=7
        drive_and_check(
            8'b00000111,          // feature_id
            8'b11000110, 8'b00111010,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 21: FID=7
        drive_and_check(
            8'b00000111,          // feature_id
            8'b01111001, 8'b11100011,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001011100,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 22: FID=7
        drive_and_check(
            8'b00000111,          // feature_id
            8'b11011000, 8'b01100100,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000111100,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 23: FID=7
        drive_and_check(
            8'b00000111,          // feature_id
            8'b10111101, 8'b10111010,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001110111,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 24: FID=7
        drive_and_check(
            8'b00000111,          // feature_id
            8'b10100101, 8'b11111100,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010100001,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 25: FID=8
        drive_and_check(
            8'b00001000,          // feature_id
            8'b01100011, 8'b10010111,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011111011,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 26: FID=8
        drive_and_check(
            8'b00001000,          // feature_id
            8'b11000011, 8'b00100001,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011100101,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 27: FID=8
        drive_and_check(
            8'b00001000,          // feature_id
            8'b00011000, 8'b10001110,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010100111,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 28: FID=8
        drive_and_check(
            8'b00001000,          // feature_id
            8'b00011001, 8'b10011011,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010110101,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 29: FID=8
        drive_and_check(
            8'b00001000,          // feature_id
            8'b00100110, 8'b10111110,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011100101,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 30: FID=8
        drive_and_check(
            8'b00001000,          // feature_id
            8'b00101100, 8'b11000011,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011110000,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 31: FID=8
        drive_and_check(
            8'b00001000,          // feature_id
            8'b00010101, 8'b00110110,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001001100,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 32: FID=8
        drive_and_check(
            8'b00001000,          // feature_id
            8'b11010111, 8'b00100110,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011111110,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 33: FID=8
        drive_and_check(
            8'b00001000,          // feature_id
            8'b01010000, 8'b00111100,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010001101,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 34: FID=8
        drive_and_check(
            8'b00001000,          // feature_id
            8'b01110100, 8'b00111110,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010110011,  // exp_res
            1'b0, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 35: FID=9
        drive_and_check(
            8'b00001001,          // feature_id
            8'b11010110, 8'b10111001,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010010000,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 36: FID=9
        drive_and_check(
            8'b00001001,          // feature_id
            8'b01100101, 8'b10101101,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010011,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 37: FID=9
        drive_and_check(
            8'b00001001,          // feature_id
            8'b11001100, 8'b01011000,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000100101,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 38: FID=9
        drive_and_check(
            8'b00001001,          // feature_id
            8'b01001111, 8'b11111011,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001001011,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 39: FID=9
        drive_and_check(
            8'b00001001,          // feature_id
            8'b11011010, 8'b11010101,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010110000,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 40: FID=9
        drive_and_check(
            8'b00001001,          // feature_id
            8'b10000011, 8'b11110111,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001111011,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 41: FID=9
        drive_and_check(
            8'b00001001,          // feature_id
            8'b11111101, 8'b10101001,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010100111,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 42: FID=9
        drive_and_check(
            8'b00001001,          // feature_id
            8'b01101111, 8'b10101111,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000011111,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 43: FID=9
        drive_and_check(
            8'b00001001,          // feature_id
            8'b11011110, 8'b10101000,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010000111,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 44: FID=9
        drive_and_check(
            8'b00001001,          // feature_id
            8'b11110100, 8'b10110100,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010101001,  // exp_res
            1'b1, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 45: FID=10
        drive_and_check(
            8'b00001010,          // feature_id
            8'b10101100, 8'b10010010,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000011010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 46: FID=10
        drive_and_check(
            8'b00001010,          // feature_id
            8'b10011000, 8'b10000100,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 47: FID=10
        drive_and_check(
            8'b00001010,          // feature_id
            8'b11101000, 8'b00011000,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011010000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 48: FID=10
        drive_and_check(
            8'b00001010,          // feature_id
            8'b01010001, 8'b00111011,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 49: FID=10
        drive_and_check(
            8'b00001010,          // feature_id
            8'b11101010, 8'b00101100,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010111110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 50: FID=10
        drive_and_check(
            8'b00001010,          // feature_id
            8'b11100001, 8'b01011111,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010000010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 51: FID=10
        drive_and_check(
            8'b00001010,          // feature_id
            8'b00111010, 8'b00001001,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000110001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 52: FID=10
        drive_and_check(
            8'b00001010,          // feature_id
            8'b11001100, 8'b00100100,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010101000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 53: FID=10
        drive_and_check(
            8'b00001010,          // feature_id
            8'b11011010, 8'b10110100,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000100110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 54: FID=10
        drive_and_check(
            8'b00001010,          // feature_id
            8'b10010110, 8'b10000111,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000001111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 55: FID=11
        drive_and_check(
            8'b00001011,          // feature_id
            8'b00111110, 8'b11001100,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001110010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 56: FID=11
        drive_and_check(
            8'b00001011,          // feature_id
            8'b01101111, 8'b01111100,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011110011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 57: FID=11
        drive_and_check(
            8'b00001011,          // feature_id
            8'b01110001, 8'b10111010,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010110111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 58: FID=11
        drive_and_check(
            8'b00001011,          // feature_id
            8'b10110100, 8'b11111000,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010111100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 59: FID=11
        drive_and_check(
            8'b00001011,          // feature_id
            8'b00110100, 8'b10010010,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010100010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 60: FID=11
        drive_and_check(
            8'b00001011,          // feature_id
            8'b00010001, 8'b10100110,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001101011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 61: FID=11
        drive_and_check(
            8'b00001011,          // feature_id
            8'b10000110, 8'b11101001,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010011101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 62: FID=11
        drive_and_check(
            8'b00001011,          // feature_id
            8'b10001010, 8'b11010100,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010110110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 63: FID=11
        drive_and_check(
            8'b00001011,          // feature_id
            8'b01101100, 8'b11100101,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010000111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 64: FID=11
        drive_and_check(
            8'b00001011,          // feature_id
            8'b00100110, 8'b11011000,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001001110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 65: FID=12
        drive_and_check(
            8'b00001100,          // feature_id
            8'b01101111, 8'b00111101,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000110001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 66: FID=12
        drive_and_check(
            8'b00001100,          // feature_id
            8'b11001010, 8'b00001001,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 67: FID=12
        drive_and_check(
            8'b00001100,          // feature_id
            8'b01101010, 8'b00000100,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001100101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 68: FID=12
        drive_and_check(
            8'b00001100,          // feature_id
            8'b01110111, 8'b00000111,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001101111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 69: FID=12
        drive_and_check(
            8'b00001100,          // feature_id
            8'b00011010, 8'b00001011,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000001110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 70: FID=12
        drive_and_check(
            8'b00001100,          // feature_id
            8'b00011110, 8'b00010101,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000001000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 71: FID=12
        drive_and_check(
            8'b00001100,          // feature_id
            8'b10010000, 8'b01100010,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000101101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 72: FID=12
        drive_and_check(
            8'b00001100,          // feature_id
            8'b10001110, 8'b01111101,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 73: FID=12
        drive_and_check(
            8'b00001100,          // feature_id
            8'b10011011, 8'b01110111,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000100011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 74: FID=12
        drive_and_check(
            8'b00001100,          // feature_id
            8'b01010110, 8'b01000000,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 75: FID=13
        drive_and_check(
            8'b00001101,          // feature_id
            8'b00010101, 8'b11111001,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000011011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 76: FID=13
        drive_and_check(
            8'b00001101,          // feature_id
            8'b01010110, 8'b10111111,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010010110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 77: FID=13
        drive_and_check(
            8'b00001101,          // feature_id
            8'b00101011, 8'b10010101,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010010101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 78: FID=13
        drive_and_check(
            8'b00001101,          // feature_id
            8'b00110011, 8'b01110110,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010111100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 79: FID=13
        drive_and_check(
            8'b00001101,          // feature_id
            8'b01010011, 8'b10010000,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011000010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 80: FID=13
        drive_and_check(
            8'b00001101,          // feature_id
            8'b11011010, 8'b11111101,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011011100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 81: FID=13
        drive_and_check(
            8'b00001101,          // feature_id
            8'b00010111, 8'b00110011,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011100011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 82: FID=13
        drive_and_check(
            8'b00001101,          // feature_id
            8'b00001000, 8'b01011100,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010101011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 83: FID=13
        drive_and_check(
            8'b00001101,          // feature_id
            8'b00000001, 8'b00111000,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011001000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 84: FID=13
        drive_and_check(
            8'b00001101,          // feature_id
            8'b00010111, 8'b01011111,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010110111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 85: FID=14
        drive_and_check(
            8'b00001110,          // feature_id
            8'b00101101, 8'b01011000,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000000101110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 86: FID=14
        drive_and_check(
            8'b00001110,          // feature_id
            8'b01111101, 8'b00000001,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000001111110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 87: FID=14
        drive_and_check(
            8'b00001110,          // feature_id
            8'b11001100, 8'b00101111,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000011001101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 88: FID=14
        drive_and_check(
            8'b00001110,          // feature_id
            8'b00011110, 8'b00011111,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000000011111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 89: FID=14
        drive_and_check(
            8'b00001110,          // feature_id
            8'b11101011, 8'b10010101,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000011101100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 90: FID=15
        drive_and_check(
            8'b00001111,          // feature_id
            8'b11111111, 8'b01010111,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 91: FID=16
        drive_and_check(
            8'b00010000,          // feature_id
            8'b10000111, 8'b11001110,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000010000110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 92: FID=16
        drive_and_check(
            8'b00010000,          // feature_id
            8'b10000110, 8'b10100111,  // opa, opb
            4'b0101,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000010000101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 93: FID=16
        drive_and_check(
            8'b00010000,          // feature_id
            8'b01011101, 8'b01110101,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000001011100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 94: FID=16
        drive_and_check(
            8'b00010000,          // feature_id
            8'b01110000, 8'b10111110,  // opa, opb
            4'b0101,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000001101111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 95: FID=16
        drive_and_check(
            8'b00010000,          // feature_id
            8'b01010011, 8'b01000000,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000001010010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 96: FID=17
        drive_and_check(
            8'b00010001,          // feature_id
            8'b00000000, 8'b01111010,  // opa, opb
            4'b0101,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000011111111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 97: FID=18
        drive_and_check(
            8'b00010010,          // feature_id
            8'b11100011, 8'b11101110,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000011101111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 98: FID=18
        drive_and_check(
            8'b00010010,          // feature_id
            8'b00100110, 8'b11110111,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000011111000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 99: FID=18
        drive_and_check(
            8'b00010010,          // feature_id
            8'b00001100, 8'b00101001,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000000101010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 100: FID=18
        drive_and_check(
            8'b00010010,          // feature_id
            8'b10111001, 8'b01101010,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000001101011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 101: FID=18
        drive_and_check(
            8'b00010010,          // feature_id
            8'b10011011, 8'b10001101,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000010001110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 102: FID=19
        drive_and_check(
            8'b00010011,          // feature_id
            8'b10111001, 8'b11111111,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 103: FID=20
        drive_and_check(
            8'b00010100,          // feature_id
            8'b11011110, 8'b11101010,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000011101001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 104: FID=20
        drive_and_check(
            8'b00010100,          // feature_id
            8'b01000101, 8'b11101100,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000011101011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 105: FID=20
        drive_and_check(
            8'b00010100,          // feature_id
            8'b10011010, 8'b00000011,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000000000010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 106: FID=20
        drive_and_check(
            8'b00010100,          // feature_id
            8'b10000111, 8'b01011001,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000001011000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 107: FID=20
        drive_and_check(
            8'b00010100,          // feature_id
            8'b11101100, 8'b00010111,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000000010110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 108: FID=21
        drive_and_check(
            8'b00010101,          // feature_id
            8'b10101110, 8'b00000000,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000011111111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 109: FID=22
        drive_and_check(
            8'b00010110,          // feature_id
            8'b10001010, 8'b10001010,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 110: FID=22
        drive_and_check(
            8'b00010110,          // feature_id
            8'b10111111, 8'b10111111,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 111: FID=22
        drive_and_check(
            8'b00010110,          // feature_id
            8'b11000000, 8'b11000000,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 112: FID=22
        drive_and_check(
            8'b00010110,          // feature_id
            8'b01101001, 8'b01101001,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 113: FID=22
        drive_and_check(
            8'b00010110,          // feature_id
            8'b10011110, 8'b10011110,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 114: FID=24
        drive_and_check(
            8'b00011000,          // feature_id
            8'b10111100, 8'b01101101,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 115: FID=24
        drive_and_check(
            8'b00011000,          // feature_id
            8'b11101110, 8'b10111011,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 116: FID=24
        drive_and_check(
            8'b00011000,          // feature_id
            8'b01010000, 8'b00001001,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 117: FID=24
        drive_and_check(
            8'b00011000,          // feature_id
            8'b11111110, 8'b01101110,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 118: FID=24
        drive_and_check(
            8'b00011000,          // feature_id
            8'b11010101, 8'b11001111,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 119: FID=26
        drive_and_check(
            8'b00011010,          // feature_id
            8'b10011111, 8'b11111110,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 120: FID=26
        drive_and_check(
            8'b00011010,          // feature_id
            8'b00101011, 8'b01011010,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 121: FID=26
        drive_and_check(
            8'b00011010,          // feature_id
            8'b00010001, 8'b01001101,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 122: FID=26
        drive_and_check(
            8'b00011010,          // feature_id
            8'b01000010, 8'b11101011,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 123: FID=26
        drive_and_check(
            8'b00011010,          // feature_id
            8'b01000001, 8'b01110101,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 124: FID=27
        drive_and_check(
            8'b00011011,          // feature_id
            8'b01001111, 8'b01100100,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 125: FID=27
        drive_and_check(
            8'b00011011,          // feature_id
            8'b01110110, 8'b10101010,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 126: FID=27
        drive_and_check(
            8'b00011011,          // feature_id
            8'b01100010, 8'b00001011,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 127: FID=27
        drive_and_check(
            8'b00011011,          // feature_id
            8'b10010000, 8'b00000000,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 128: FID=27
        drive_and_check(
            8'b00011011,          // feature_id
            8'b00001010, 8'b00011111,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 129: FID=27
        drive_and_check(
            8'b00011011,          // feature_id
            8'b11110110, 8'b00010101,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0001010100111010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 130: FID=27
        drive_and_check(
            8'b00011011,          // feature_id
            8'b10000111, 8'b00111001,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0001111011010000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 131: FID=27
        drive_and_check(
            8'b00011011,          // feature_id
            8'b10110011, 8'b10101000,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0111011011010100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 132: FID=27
        drive_and_check(
            8'b00011011,          // feature_id
            8'b01011001, 8'b00111001,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0001010001100100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 133: FID=27
        drive_and_check(
            8'b00011011,          // feature_id
            8'b10011000, 8'b00110101,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0010000001000110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 134: FID=28
        drive_and_check(
            8'b00011100,          // feature_id
            8'b01101101, 8'b10101100,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 135: FID=28
        drive_and_check(
            8'b00011100,          // feature_id
            8'b10011010, 8'b01011000,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 136: FID=28
        drive_and_check(
            8'b00011100,          // feature_id
            8'b01001000, 8'b00111011,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 137: FID=28
        drive_and_check(
            8'b00011100,          // feature_id
            8'b01101111, 8'b00011001,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 138: FID=28
        drive_and_check(
            8'b00011100,          // feature_id
            8'b00001111, 8'b10011110,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 139: FID=29
        drive_and_check(
            8'b00011101,          // feature_id
            8'b10110101, 8'b11001001,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 140: FID=29
        drive_and_check(
            8'b00011101,          // feature_id
            8'b01111010, 8'b10111010,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 141: FID=29
        drive_and_check(
            8'b00011101,          // feature_id
            8'b00101001, 8'b01101011,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 142: FID=29
        drive_and_check(
            8'b00011101,          // feature_id
            8'b00010100, 8'b11010110,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 143: FID=29
        drive_and_check(
            8'b00011101,          // feature_id
            8'b11101111, 8'b01111001,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 144: FID=29
        drive_and_check(
            8'b00011101,          // feature_id
            8'b11000110, 8'b01010001,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0010110001001100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 145: FID=29
        drive_and_check(
            8'b00011101,          // feature_id
            8'b11110101, 8'b10110010,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1010001010110100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 146: FID=29
        drive_and_check(
            8'b00011101,          // feature_id
            8'b00111000, 8'b11001000,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0101011110000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 147: FID=29
        drive_and_check(
            8'b00011101,          // feature_id
            8'b11111111, 8'b11111101,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111101100000110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 148: FID=29
        drive_and_check(
            8'b00011101,          // feature_id
            8'b10111111, 8'b10100101,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0101000100110110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 149: FID=30
        drive_and_check(
            8'b00011110,          // feature_id
            8'b01010101, 8'b01011011,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 150: FID=30
        drive_and_check(
            8'b00011110,          // feature_id
            8'b00110110, 8'b11111100,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 151: FID=30
        drive_and_check(
            8'b00011110,          // feature_id
            8'b10100010, 8'b00111110,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 152: FID=30
        drive_and_check(
            8'b00011110,          // feature_id
            8'b11111110, 8'b00001010,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 153: FID=30
        drive_and_check(
            8'b00011110,          // feature_id
            8'b10111011, 8'b00101110,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 154: FID=31
        drive_and_check(
            8'b00011111,          // feature_id
            8'b11111110, 8'b00011110,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000011100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 155: FID=31
        drive_and_check(
            8'b00011111,          // feature_id
            8'b01011001, 8'b11001110,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000100111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 156: FID=31
        drive_and_check(
            8'b00011111,          // feature_id
            8'b00101001, 8'b10111100,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111100101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 157: FID=31
        drive_and_check(
            8'b00011111,          // feature_id
            8'b11111101, 8'b01101010,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001100111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 158: FID=31
        drive_and_check(
            8'b00011111,          // feature_id
            8'b01110000, 8'b11010011,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001000011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 159: FID=31
        drive_and_check(
            8'b00011111,          // feature_id
            8'b01100010, 8'b00001011,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001101101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 160: FID=31
        drive_and_check(
            8'b00011111,          // feature_id
            8'b01001100, 8'b11001100,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000011000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 161: FID=31
        drive_and_check(
            8'b00011111,          // feature_id
            8'b00000001, 8'b10010100,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111110010101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 162: FID=31
        drive_and_check(
            8'b00011111,          // feature_id
            8'b10100111, 8'b00100001,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111001000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 163: FID=31
        drive_and_check(
            8'b00011111,          // feature_id
            8'b01011011, 8'b10100001,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111111100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 164: FID=32
        drive_and_check(
            8'b00100000,          // feature_id
            8'b11000001, 8'b10110000,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101110001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 165: FID=32
        drive_and_check(
            8'b00100000,          // feature_id
            8'b11000011, 8'b10010001,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101010100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 166: FID=32
        drive_and_check(
            8'b00100000,          // feature_id
            8'b00100000, 8'b01100101,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010000101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 167: FID=32
        drive_and_check(
            8'b00100000,          // feature_id
            8'b10000110, 8'b10111000,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100111110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 168: FID=32
        drive_and_check(
            8'b00100000,          // feature_id
            8'b01100011, 8'b01101101,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011010000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 169: FID=32
        drive_and_check(
            8'b00100000,          // feature_id
            8'b01100010, 8'b00100011,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010000101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 170: FID=32
        drive_and_check(
            8'b00100000,          // feature_id
            8'b11111001, 8'b10000001,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101111010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 171: FID=32
        drive_and_check(
            8'b00100000,          // feature_id
            8'b10000010, 8'b11111000,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101111010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 172: FID=32
        drive_and_check(
            8'b00100000,          // feature_id
            8'b01100001, 8'b01110100,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011010101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 173: FID=32
        drive_and_check(
            8'b00100000,          // feature_id
            8'b10011110, 8'b11000011,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101100001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 174: FID=33
        drive_and_check(
            8'b00100001,          // feature_id
            8'b00010101, 8'b00010101,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000101010,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 175: FID=33
        drive_and_check(
            8'b00100001,          // feature_id
            8'b11011010, 8'b11011010,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111110110100,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 176: FID=33
        drive_and_check(
            8'b00100001,          // feature_id
            8'b11010100, 8'b11010100,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111110101000,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 177: FID=33
        drive_and_check(
            8'b00100001,          // feature_id
            8'b10001101, 8'b10001101,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100011010,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 178: FID=33
        drive_and_check(
            8'b00100001,          // feature_id
            8'b10100011, 8'b10100011,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101000110,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 179: FID=34
        drive_and_check(
            8'b00100010,          // feature_id
            8'b01011100, 8'b10011110,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111111010,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 180: FID=34
        drive_and_check(
            8'b00100010,          // feature_id
            8'b01101100, 8'b00100101,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010010001,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 181: FID=34
        drive_and_check(
            8'b00100010,          // feature_id
            8'b11111100, 8'b11100010,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111011110,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 182: FID=34
        drive_and_check(
            8'b00100010,          // feature_id
            8'b01011100, 8'b00100011,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001111111,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 183: FID=34
        drive_and_check(
            8'b00100010,          // feature_id
            8'b11010010, 8'b11000010,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111110010100,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 184: FID=35
        drive_and_check(
            8'b00100011,          // feature_id
            8'b00001101, 8'b01010001,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001011110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 185: FID=35
        drive_and_check(
            8'b00100011,          // feature_id
            8'b00011010, 8'b01100101,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001111111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 186: FID=35
        drive_and_check(
            8'b00100011,          // feature_id
            8'b10010010, 8'b10101111,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101000001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 187: FID=35
        drive_and_check(
            8'b00100011,          // feature_id
            8'b10110001, 8'b01000011,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111110100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 188: FID=35
        drive_and_check(
            8'b00100011,          // feature_id
            8'b10110011, 8'b11010011,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111110000110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 189: FID=36
        drive_and_check(
            8'b00100100,          // feature_id
            8'b10100010, 8'b10110110,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111101100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 190: FID=36
        drive_and_check(
            8'b00100100,          // feature_id
            8'b01101101, 8'b00011100,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001010001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 191: FID=36
        drive_and_check(
            8'b00100100,          // feature_id
            8'b11010100, 8'b00101000,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111110101100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 192: FID=36
        drive_and_check(
            8'b00100100,          // feature_id
            8'b11101100, 8'b11101000,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 193: FID=36
        drive_and_check(
            8'b00100100,          // feature_id
            8'b11110010, 8'b10110100,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000111110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 194: FID=36
        drive_and_check(
            8'b00100100,          // feature_id
            8'b10111110, 8'b10000110,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000111000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 195: FID=36
        drive_and_check(
            8'b00100100,          // feature_id
            8'b10100111, 8'b10000100,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000100011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 196: FID=36
        drive_and_check(
            8'b00100100,          // feature_id
            8'b01101001, 8'b00011010,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001001111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 197: FID=36
        drive_and_check(
            8'b00100100,          // feature_id
            8'b10100011, 8'b10011000,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000001011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 198: FID=36
        drive_and_check(
            8'b00100100,          // feature_id
            8'b01100000, 8'b00100001,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000111111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b0, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 199: FID=37
        drive_and_check(
            8'b00100101,          // feature_id
            8'b01000010, 8'b10001010,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010111000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 200: FID=37
        drive_and_check(
            8'b00100101,          // feature_id
            8'b10011111, 8'b01110010,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100101101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 201: FID=37
        drive_and_check(
            8'b00100101,          // feature_id
            8'b01001101, 8'b10000001,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011001100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 202: FID=37
        drive_and_check(
            8'b00100101,          // feature_id
            8'b10100010, 8'b01010101,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101001101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 203: FID=37
        drive_and_check(
            8'b00100101,          // feature_id
            8'b01110011, 8'b10111110,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010110101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 204: FID=37
        drive_and_check(
            8'b00100101,          // feature_id
            8'b10010110, 8'b01010000,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101000110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 205: FID=37
        drive_and_check(
            8'b00100101,          // feature_id
            8'b00111000, 8'b10101100,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010001100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 206: FID=37
        drive_and_check(
            8'b00100101,          // feature_id
            8'b01000010, 8'b10001010,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010111000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 207: FID=37
        drive_and_check(
            8'b00100101,          // feature_id
            8'b01011010, 8'b10111101,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010011101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 208: FID=37
        drive_and_check(
            8'b00100101,          // feature_id
            8'b01001100, 8'b11000001,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010001011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'b1, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 209: FID=38
        drive_and_check(
            8'b00100110,          // feature_id
            8'b00100011, 8'b00100011,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 210: FID=38
        drive_and_check(
            8'b00100110,          // feature_id
            8'b00100010, 8'b00100010,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 211: FID=38
        drive_and_check(
            8'b00100110,          // feature_id
            8'b11100100, 8'b11100100,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 212: FID=38
        drive_and_check(
            8'b00100110,          // feature_id
            8'b01111101, 8'b01111101,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 213: FID=38
        drive_and_check(
            8'b00100110,          // feature_id
            8'b01100100, 8'b01100100,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'bx, 1'b1, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 214: FID=39
        drive_and_check(
            8'b00100111,          // feature_id
            8'b10100110, 8'b10010100,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010010,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 215: FID=39
        drive_and_check(
            8'b00100111,          // feature_id
            8'b00011001, 8'b10111011,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001011110,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 216: FID=39
        drive_and_check(
            8'b00100111,          // feature_id
            8'b11100111, 8'b11010011,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010100,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 217: FID=39
        drive_and_check(
            8'b00100111,          // feature_id
            8'b01100001, 8'b10100111,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010111010,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 218: FID=39
        drive_and_check(
            8'b00100111,          // feature_id
            8'b00111001, 8'b10111100,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001111101,  // exp_res
            1'bx, 1'bx, 1'b1, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 219: FID=40
        drive_and_check(
            8'b00101000,          // feature_id
            8'b01010101, 8'b01010110,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111111111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 220: FID=40
        drive_and_check(
            8'b00101000,          // feature_id
            8'b00011011, 8'b00100011,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111111000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 221: FID=40
        drive_and_check(
            8'b00101000,          // feature_id
            8'b10101111, 8'b00100000,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111110001111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 222: FID=40
        drive_and_check(
            8'b00101000,          // feature_id
            8'b10100001, 8'b00010010,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111110001111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 223: FID=40
        drive_and_check(
            8'b00101000,          // feature_id
            8'b10111001, 8'b10111101,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111111100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'b1, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 224: FID=41
        drive_and_check(
            8'b00101001,          // feature_id
            8'b11111001, 8'b11110101,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011110001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 225: FID=41
        drive_and_check(
            8'b00101001,          // feature_id
            8'b00001100, 8'b00010001,  // opa, opb
            4'b0000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 226: FID=41
        drive_and_check(
            8'b00101001,          // feature_id
            8'b11010001, 8'b00010010,  // opa, opb
            4'b0000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 227: FID=41
        drive_and_check(
            8'b00101001,          // feature_id
            8'b10100011, 8'b00111000,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000100000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 228: FID=41
        drive_and_check(
            8'b00101001,          // feature_id
            8'b10111011, 8'b01000100,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 229: FID=41
        drive_and_check(
            8'b00101001,          // feature_id
            8'b10110101, 8'b10011000,  // opa, opb
            4'b0000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010010000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 230: FID=41
        drive_and_check(
            8'b00101001,          // feature_id
            8'b11110000, 8'b11101000,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011100000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 231: FID=41
        drive_and_check(
            8'b00101001,          // feature_id
            8'b11001011, 8'b00010010,  // opa, opb
            4'b0000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000000010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 232: FID=41
        drive_and_check(
            8'b00101001,          // feature_id
            8'b11101000, 8'b11111001,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011101000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 233: FID=41
        drive_and_check(
            8'b00101001,          // feature_id
            8'b00110101, 8'b11010010,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000010000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 234: FID=42
        drive_and_check(
            8'b00101010,          // feature_id
            8'b11010110, 8'b00110010,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111101101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 235: FID=42
        drive_and_check(
            8'b00101010,          // feature_id
            8'b10011101, 8'b00111000,  // opa, opb
            4'b0001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111100111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 236: FID=42
        drive_and_check(
            8'b00101010,          // feature_id
            8'b00110001, 8'b11011100,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111101111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 237: FID=42
        drive_and_check(
            8'b00101010,          // feature_id
            8'b01001011, 8'b01001010,  // opa, opb
            4'b0001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111110110101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 238: FID=42
        drive_and_check(
            8'b00101010,          // feature_id
            8'b00000000, 8'b11000010,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111111111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 239: FID=42
        drive_and_check(
            8'b00101010,          // feature_id
            8'b10011011, 8'b00001010,  // opa, opb
            4'b0001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111110101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 240: FID=42
        drive_and_check(
            8'b00101010,          // feature_id
            8'b00111100, 8'b10000111,  // opa, opb
            4'b0001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111111011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 241: FID=42
        drive_and_check(
            8'b00101010,          // feature_id
            8'b11100000, 8'b11101001,  // opa, opb
            4'b0001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100011111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 242: FID=42
        drive_and_check(
            8'b00101010,          // feature_id
            8'b10011000, 8'b01110101,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111101111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 243: FID=42
        drive_and_check(
            8'b00101010,          // feature_id
            8'b11001111, 8'b10001010,  // opa, opb
            4'b0001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101110101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 244: FID=43
        drive_and_check(
            8'b00101011,          // feature_id
            8'b01000011, 8'b00011111,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001011111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 245: FID=43
        drive_and_check(
            8'b00101011,          // feature_id
            8'b10001101, 8'b10110001,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010111101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 246: FID=43
        drive_and_check(
            8'b00101011,          // feature_id
            8'b10000011, 8'b01000110,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011000111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 247: FID=43
        drive_and_check(
            8'b00101011,          // feature_id
            8'b10111000, 8'b01101101,  // opa, opb
            4'b0010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011111101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 248: FID=43
        drive_and_check(
            8'b00101011,          // feature_id
            8'b00010000, 8'b01111100,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001111100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 249: FID=43
        drive_and_check(
            8'b00101011,          // feature_id
            8'b00101101, 8'b00001001,  // opa, opb
            4'b0010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000101101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 250: FID=43
        drive_and_check(
            8'b00101011,          // feature_id
            8'b01111101, 8'b00111110,  // opa, opb
            4'b0010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001111111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 251: FID=43
        drive_and_check(
            8'b00101011,          // feature_id
            8'b10010010, 8'b00010001,  // opa, opb
            4'b0010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010010011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 252: FID=43
        drive_and_check(
            8'b00101011,          // feature_id
            8'b11000100, 8'b01110100,  // opa, opb
            4'b0010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011110100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 253: FID=43
        drive_and_check(
            8'b00101011,          // feature_id
            8'b00001100, 8'b00110101,  // opa, opb
            4'b0010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000111101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 254: FID=44
        drive_and_check(
            8'b00101100,          // feature_id
            8'b00010011, 8'b10010010,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101101100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 255: FID=44
        drive_and_check(
            8'b00101100,          // feature_id
            8'b00100000, 8'b11110001,  // opa, opb
            4'b0011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100001110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 256: FID=44
        drive_and_check(
            8'b00101100,          // feature_id
            8'b11101001, 8'b01110110,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 257: FID=44
        drive_and_check(
            8'b00101100,          // feature_id
            8'b01111100, 8'b10111101,  // opa, opb
            4'b0011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100000010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 258: FID=44
        drive_and_check(
            8'b00101100,          // feature_id
            8'b00011110, 8'b11000101,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100100000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 259: FID=44
        drive_and_check(
            8'b00101100,          // feature_id
            8'b11000111, 8'b10010110,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100101000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 260: FID=44
        drive_and_check(
            8'b00101100,          // feature_id
            8'b00101111, 8'b10010110,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 261: FID=44
        drive_and_check(
            8'b00101100,          // feature_id
            8'b11111011, 8'b11011101,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 262: FID=44
        drive_and_check(
            8'b00101100,          // feature_id
            8'b10110111, 8'b11010001,  // opa, opb
            4'b0011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100001000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 263: FID=44
        drive_and_check(
            8'b00101100,          // feature_id
            8'b00100010, 8'b11100001,  // opa, opb
            4'b0011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100011100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 264: FID=45
        drive_and_check(
            8'b00101101,          // feature_id
            8'b10010011, 8'b01100001,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011110010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 265: FID=45
        drive_and_check(
            8'b00101101,          // feature_id
            8'b10010010, 8'b01010111,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011000101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 266: FID=45
        drive_and_check(
            8'b00101101,          // feature_id
            8'b11110110, 8'b11010001,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000100111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 267: FID=45
        drive_and_check(
            8'b00101101,          // feature_id
            8'b00010011, 8'b11101100,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011111111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 268: FID=45
        drive_and_check(
            8'b00101101,          // feature_id
            8'b11111010, 8'b01011010,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010100000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 269: FID=45
        drive_and_check(
            8'b00101101,          // feature_id
            8'b00001110, 8'b11111111,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011110001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 270: FID=45
        drive_and_check(
            8'b00101101,          // feature_id
            8'b00101110, 8'b00011100,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000110010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 271: FID=45
        drive_and_check(
            8'b00101101,          // feature_id
            8'b11100100, 8'b01010100,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010110000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 272: FID=45
        drive_and_check(
            8'b00101101,          // feature_id
            8'b10010000, 8'b01010100,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011000100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 273: FID=45
        drive_and_check(
            8'b00101101,          // feature_id
            8'b01000011, 8'b10110000,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011110011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 274: FID=46
        drive_and_check(
            8'b00101110,          // feature_id
            8'b00000110, 8'b11110010,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100001011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 275: FID=46
        drive_and_check(
            8'b00101110,          // feature_id
            8'b00000000, 8'b10011001,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101100110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 276: FID=46
        drive_and_check(
            8'b00101110,          // feature_id
            8'b11101100, 8'b01111101,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101101110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 277: FID=46
        drive_and_check(
            8'b00101110,          // feature_id
            8'b00101101, 8'b10001001,  // opa, opb
            4'b0101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101011011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 278: FID=46
        drive_and_check(
            8'b00101110,          // feature_id
            8'b01010011, 8'b01110000,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111011100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 279: FID=46
        drive_and_check(
            8'b00101110,          // feature_id
            8'b00100100, 8'b10100101,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101111110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 280: FID=46
        drive_and_check(
            8'b00101110,          // feature_id
            8'b00100101, 8'b00111111,  // opa, opb
            4'b0101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111111100101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 281: FID=46
        drive_and_check(
            8'b00101110,          // feature_id
            8'b01000101, 8'b00001111,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111110110101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 282: FID=46
        drive_and_check(
            8'b00101110,          // feature_id
            8'b01110001, 8'b10011011,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111100010101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 283: FID=46
        drive_and_check(
            8'b00101110,          // feature_id
            8'b00111100, 8'b10110011,  // opa, opb
            4'b0101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b1111111101110000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 284: FID=47
        drive_and_check(
            8'b00101111,          // feature_id
            8'b01110001, 8'b00111110,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b1111111110001110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 285: FID=47
        drive_and_check(
            8'b00101111,          // feature_id
            8'b11111101, 8'b01001100,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b1111111100000010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 286: FID=47
        drive_and_check(
            8'b00101111,          // feature_id
            8'b00101010, 8'b01011001,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b1111111111010101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 287: FID=47
        drive_and_check(
            8'b00101111,          // feature_id
            8'b01100100, 8'b11100111,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b1111111110011011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 288: FID=47
        drive_and_check(
            8'b00101111,          // feature_id
            8'b11101100, 8'b01101111,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b1111111100010011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 289: FID=47
        drive_and_check(
            8'b00101111,          // feature_id
            8'b01011001, 8'b11110000,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b1111111110100110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 290: FID=47
        drive_and_check(
            8'b00101111,          // feature_id
            8'b00100011, 8'b01011101,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b1111111111011100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 291: FID=47
        drive_and_check(
            8'b00101111,          // feature_id
            8'b00110100, 8'b01100011,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b1111111111001011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 292: FID=47
        drive_and_check(
            8'b00101111,          // feature_id
            8'b11010101, 8'b00010101,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b1111111100101010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 293: FID=47
        drive_and_check(
            8'b00101111,          // feature_id
            8'b11110000, 8'b10010011,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b1111111100001111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 294: FID=48
        drive_and_check(
            8'b00110000,          // feature_id
            8'b11010101, 8'b01011000,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b1111111110100111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 295: FID=48
        drive_and_check(
            8'b00110000,          // feature_id
            8'b10000001, 8'b00100110,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b1111111111011001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 296: FID=48
        drive_and_check(
            8'b00110000,          // feature_id
            8'b10010100, 8'b10111111,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b1111111101000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 297: FID=48
        drive_and_check(
            8'b00110000,          // feature_id
            8'b01011000, 8'b11001011,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b1111111100110100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 298: FID=48
        drive_and_check(
            8'b00110000,          // feature_id
            8'b00100010, 8'b00001000,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b1111111111110111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 299: FID=48
        drive_and_check(
            8'b00110000,          // feature_id
            8'b00111100, 8'b01111110,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b1111111110000001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 300: FID=48
        drive_and_check(
            8'b00110000,          // feature_id
            8'b01001000, 8'b10001001,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b1111111101110110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 301: FID=48
        drive_and_check(
            8'b00110000,          // feature_id
            8'b01110110, 8'b10011001,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b1111111101100110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 302: FID=48
        drive_and_check(
            8'b00110000,          // feature_id
            8'b01111100, 8'b00010010,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b1111111111101101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 303: FID=48
        drive_and_check(
            8'b00110000,          // feature_id
            8'b10110100, 8'b10010100,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b1111111101101011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 304: FID=49
        drive_and_check(
            8'b00110001,          // feature_id
            8'b01101010, 8'b01001110,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000000110101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 305: FID=49
        drive_and_check(
            8'b00110001,          // feature_id
            8'b10010011, 8'b10100111,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000001001001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 306: FID=49
        drive_and_check(
            8'b00110001,          // feature_id
            8'b01111011, 8'b00100110,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000000111101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 307: FID=49
        drive_and_check(
            8'b00110001,          // feature_id
            8'b00011010, 8'b00101011,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000000001101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 308: FID=49
        drive_and_check(
            8'b00110001,          // feature_id
            8'b10010110, 8'b01101100,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000001001011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 309: FID=50
        drive_and_check(
            8'b00110010,          // feature_id
            8'b11010011, 8'b00001111,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000001101001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 310: FID=50
        drive_and_check(
            8'b00110010,          // feature_id
            8'b00000101, 8'b10110000,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000000000010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 311: FID=50
        drive_and_check(
            8'b00110010,          // feature_id
            8'b00010011, 8'b10010101,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000000001001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 312: FID=50
        drive_and_check(
            8'b00110010,          // feature_id
            8'b10000011, 8'b11111101,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000001000001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 313: FID=50
        drive_and_check(
            8'b00110010,          // feature_id
            8'b11111011, 8'b10110000,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000001111101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 314: FID=51
        drive_and_check(
            8'b00110011,          // feature_id
            8'b01101101, 8'b01110110,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000011011010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 315: FID=51
        drive_and_check(
            8'b00110011,          // feature_id
            8'b11011001, 8'b10111010,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000110110010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 316: FID=51
        drive_and_check(
            8'b00110011,          // feature_id
            8'b00010110, 8'b10000011,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000000101100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 317: FID=51
        drive_and_check(
            8'b00110011,          // feature_id
            8'b11001110, 8'b10100101,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000110011100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 318: FID=51
        drive_and_check(
            8'b00110011,          // feature_id
            8'b01110001, 8'b10111110,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000011100010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 319: FID=52
        drive_and_check(
            8'b00110100,          // feature_id
            8'b11100000, 8'b10100000,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000111000000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 320: FID=52
        drive_and_check(
            8'b00110100,          // feature_id
            8'b11001111, 8'b00111110,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000110011110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 321: FID=52
        drive_and_check(
            8'b00110100,          // feature_id
            8'b11110011, 8'b11100011,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000111100110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 322: FID=52
        drive_and_check(
            8'b00110100,          // feature_id
            8'b11111100, 8'b10011010,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000111111000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 323: FID=52
        drive_and_check(
            8'b00110100,          // feature_id
            8'b11010011, 8'b11101001,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'b0000000110100110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 324: FID=53
        drive_and_check(
            8'b00110101,          // feature_id
            8'b11010100, 8'b10110100,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000001011010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 325: FID=53
        drive_and_check(
            8'b00110101,          // feature_id
            8'b11111110, 8'b10010110,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000001001011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 326: FID=53
        drive_and_check(
            8'b00110101,          // feature_id
            8'b01011100, 8'b11001101,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000001100110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 327: FID=53
        drive_and_check(
            8'b00110101,          // feature_id
            8'b00010011, 8'b10100111,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000001010011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 328: FID=53
        drive_and_check(
            8'b00110101,          // feature_id
            8'b00110011, 8'b11110100,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000001111010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 329: FID=54
        drive_and_check(
            8'b00110110,          // feature_id
            8'b10110011, 8'b00010101,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000000001010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 330: FID=54
        drive_and_check(
            8'b00110110,          // feature_id
            8'b01110111, 8'b11011101,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000001101110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 331: FID=54
        drive_and_check(
            8'b00110110,          // feature_id
            8'b01100110, 8'b10110001,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000001011000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 332: FID=54
        drive_and_check(
            8'b00110110,          // feature_id
            8'b11010111, 8'b01100101,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000000110010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 333: FID=54
        drive_and_check(
            8'b00110110,          // feature_id
            8'b11100110, 8'b01001111,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000000100111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 334: FID=55
        drive_and_check(
            8'b00110111,          // feature_id
            8'b10111101, 8'b00110010,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000001100100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 335: FID=55
        drive_and_check(
            8'b00110111,          // feature_id
            8'b01100011, 8'b11101011,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000111010110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 336: FID=55
        drive_and_check(
            8'b00110111,          // feature_id
            8'b00100011, 8'b01000011,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000010000110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 337: FID=55
        drive_and_check(
            8'b00110111,          // feature_id
            8'b00111010, 8'b11001101,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000110011010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 338: FID=55
        drive_and_check(
            8'b00110111,          // feature_id
            8'b10010001, 8'b11010100,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000110101000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 339: FID=56
        drive_and_check(
            8'b00111000,          // feature_id
            8'b10111100, 8'b10111110,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000101111100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 340: FID=56
        drive_and_check(
            8'b00111000,          // feature_id
            8'b10000110, 8'b10111000,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000101110000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 341: FID=56
        drive_and_check(
            8'b00111000,          // feature_id
            8'b00111111, 8'b11110100,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000111101000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 342: FID=56
        drive_and_check(
            8'b00111000,          // feature_id
            8'b11100011, 8'b10101111,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000101011110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 343: FID=56
        drive_and_check(
            8'b00111000,          // feature_id
            8'b01011010, 8'b11101111,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'b0000000111011110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 344: FID=57
        drive_and_check(
            8'b00111001,          // feature_id
            8'b01101100, 8'b00000100,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011000110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 345: FID=57
        drive_and_check(
            8'b00111001,          // feature_id
            8'b10010010, 8'b00000100,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000101001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 346: FID=57
        drive_and_check(
            8'b00111001,          // feature_id
            8'b10001111, 8'b00000011,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001111100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 347: FID=57
        drive_and_check(
            8'b00111001,          // feature_id
            8'b00011111, 8'b00000001,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000111110,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 348: FID=57
        drive_and_check(
            8'b00111001,          // feature_id
            8'b01101110, 8'b00000101,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011001101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 349: FID=57
        drive_and_check(
            8'b00111001,          // feature_id
            8'b01101001, 8'b00000000,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001101001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 350: FID=57
        drive_and_check(
            8'b00111001,          // feature_id
            8'b11000011, 8'b00000000,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011000011,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 351: FID=57
        drive_and_check(
            8'b00111001,          // feature_id
            8'b00000100, 8'b00000001,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000001000,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 352: FID=57
        drive_and_check(
            8'b00111001,          // feature_id
            8'b00111010, 8'b00000111,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000011101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 353: FID=57
        drive_and_check(
            8'b00111001,          // feature_id
            8'b10001010, 8'b00000000,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010001010,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 354: FID=58
        drive_and_check(
            8'b00111010,          // feature_id
            8'b01110011, 8'b01111001,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 355: FID=58
        drive_and_check(
            8'b00111010,          // feature_id
            8'b00000101, 8'b00001101,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 356: FID=58
        drive_and_check(
            8'b00111010,          // feature_id
            8'b10010110, 8'b00010101,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 357: FID=58
        drive_and_check(
            8'b00111010,          // feature_id
            8'b00000000, 8'b10101101,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 358: FID=58
        drive_and_check(
            8'b00111010,          // feature_id
            8'b10001110, 8'b00110100,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 359: FID=58
        drive_and_check(
            8'b00111010,          // feature_id
            8'b11101011, 8'b00101011,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 360: FID=58
        drive_and_check(
            8'b00111010,          // feature_id
            8'b00101011, 8'b11001001,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 361: FID=58
        drive_and_check(
            8'b00111010,          // feature_id
            8'b11101111, 8'b01111000,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 362: FID=58
        drive_and_check(
            8'b00111010,          // feature_id
            8'b00001010, 8'b10110100,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 363: FID=58
        drive_and_check(
            8'b00111010,          // feature_id
            8'b11100000, 8'b01011011,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 364: FID=59
        drive_and_check(
            8'b00111011,          // feature_id
            8'b11110001, 8'b00000101,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010001111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 365: FID=59
        drive_and_check(
            8'b00111011,          // feature_id
            8'b00001001, 8'b00000011,  // opa, opb
            4'b1101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000100001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 366: FID=59
        drive_and_check(
            8'b00111011,          // feature_id
            8'b11101011, 8'b00000110,  // opa, opb
            4'b1101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010101111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 367: FID=59
        drive_and_check(
            8'b00111011,          // feature_id
            8'b01011101, 8'b00000000,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001011101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 368: FID=59
        drive_and_check(
            8'b00111011,          // feature_id
            8'b11101010, 8'b00000011,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000001011101,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 369: FID=59
        drive_and_check(
            8'b00111011,          // feature_id
            8'b00001001, 8'b00000000,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000001001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 370: FID=59
        drive_and_check(
            8'b00111011,          // feature_id
            8'b10010100, 8'b00000000,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010010100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 371: FID=59
        drive_and_check(
            8'b00111011,          // feature_id
            8'b01111000, 8'b00000110,  // opa, opb
            4'b1101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000011100001,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 372: FID=59
        drive_and_check(
            8'b00111011,          // feature_id
            8'b00010010, 8'b00000111,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000000100100,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 373: FID=59
        drive_and_check(
            8'b00111011,          // feature_id
            8'b11111101, 8'b00000011,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'b0000000010111111,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );
        // Stimulus 374: FID=60
        drive_and_check(
            8'b00111100,          // feature_id
            8'b00011101, 8'b10100010,  // opa, opb
            4'b1101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 375: FID=60
        drive_and_check(
            8'b00111100,          // feature_id
            8'b10001101, 8'b01111010,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 376: FID=60
        drive_and_check(
            8'b00111100,          // feature_id
            8'b10000011, 8'b10100011,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 377: FID=60
        drive_and_check(
            8'b00111100,          // feature_id
            8'b00110011, 8'b10100100,  // opa, opb
            4'b1101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 378: FID=60
        drive_and_check(
            8'b00111100,          // feature_id
            8'b11011100, 8'b11010110,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 379: FID=60
        drive_and_check(
            8'b00111100,          // feature_id
            8'b11010110, 8'b01100001,  // opa, opb
            4'b1101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 380: FID=60
        drive_and_check(
            8'b00111100,          // feature_id
            8'b10101110, 8'b10111111,  // opa, opb
            4'b1101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 381: FID=60
        drive_and_check(
            8'b00111100,          // feature_id
            8'b01000010, 8'b01100010,  // opa, opb
            4'b1101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 382: FID=60
        drive_and_check(
            8'b00111100,          // feature_id
            8'b01111101, 8'b00101100,  // opa, opb
            4'b1101,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 383: FID=60
        drive_and_check(
            8'b00111100,          // feature_id
            8'b01011001, 8'b11101001,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 384: FID=61
        drive_and_check(
            8'b00111101,          // feature_id
            8'b10110001, 8'b00010110,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 385: FID=61
        drive_and_check(
            8'b00111101,          // feature_id
            8'b10000011, 8'b10100100,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 386: FID=61
        drive_and_check(
            8'b00111101,          // feature_id
            8'b01111101, 8'b01011100,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 387: FID=61
        drive_and_check(
            8'b00111101,          // feature_id
            8'b10111100, 8'b00110100,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 388: FID=61
        drive_and_check(
            8'b00111101,          // feature_id
            8'b01100110, 8'b10000101,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 389: FID=62
        drive_and_check(
            8'b00111110,          // feature_id
            8'b11110010, 8'b00000010,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 390: FID=62
        drive_and_check(
            8'b00111110,          // feature_id
            8'b01010011, 8'b00100111,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 391: FID=62
        drive_and_check(
            8'b00111110,          // feature_id
            8'b11100000, 8'b01111110,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 392: FID=62
        drive_and_check(
            8'b00111110,          // feature_id
            8'b11000011, 8'b10100110,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 393: FID=62
        drive_and_check(
            8'b00111110,          // feature_id
            8'b11100110, 8'b10000000,  // opa, opb
            4'b0001,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 394: FID=63
        drive_and_check(
            8'b00111111,          // feature_id
            8'b11101010, 8'b10101101,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 395: FID=63
        drive_and_check(
            8'b00111111,          // feature_id
            8'b01011100, 8'b00100111,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 396: FID=63
        drive_and_check(
            8'b00111111,          // feature_id
            8'b11010001, 8'b00000110,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 397: FID=63
        drive_and_check(
            8'b00111111,          // feature_id
            8'b01100010, 8'b11011011,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 398: FID=63
        drive_and_check(
            8'b00111111,          // feature_id
            8'b01000110, 8'b10001010,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 399: FID=64
        drive_and_check(
            8'b01000000,          // feature_id
            8'b10001001, 8'b10000010,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 400: FID=64
        drive_and_check(
            8'b01000000,          // feature_id
            8'b01011010, 8'b00010111,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 401: FID=64
        drive_and_check(
            8'b01000000,          // feature_id
            8'b00010110, 8'b01000111,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 402: FID=64
        drive_and_check(
            8'b01000000,          // feature_id
            8'b00101100, 8'b11001000,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 403: FID=64
        drive_and_check(
            8'b01000000,          // feature_id
            8'b00110110, 8'b01000010,  // opa, opb
            4'b0011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 404: FID=65
        drive_and_check(
            8'b01000001,          // feature_id
            8'b11010111, 8'b11010010,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 405: FID=65
        drive_and_check(
            8'b01000001,          // feature_id
            8'b11111100, 8'b11111100,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 406: FID=65
        drive_and_check(
            8'b01000001,          // feature_id
            8'b00001101, 8'b10001111,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 407: FID=65
        drive_and_check(
            8'b01000001,          // feature_id
            8'b11101111, 8'b10001111,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 408: FID=65
        drive_and_check(
            8'b01000001,          // feature_id
            8'b10001111, 8'b01010000,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 409: FID=66
        drive_and_check(
            8'b01000010,          // feature_id
            8'b01101110, 8'b11010000,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 410: FID=66
        drive_and_check(
            8'b01000010,          // feature_id
            8'b11011110, 8'b01001011,  // opa, opb
            4'b0101,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 411: FID=66
        drive_and_check(
            8'b01000010,          // feature_id
            8'b01111100, 8'b10110001,  // opa, opb
            4'b0101,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 412: FID=66
        drive_and_check(
            8'b01000010,          // feature_id
            8'b10010111, 8'b10111011,  // opa, opb
            4'b0101,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 413: FID=66
        drive_and_check(
            8'b01000010,          // feature_id
            8'b10000111, 8'b11101001,  // opa, opb
            4'b0101,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 414: FID=67
        drive_and_check(
            8'b01000011,          // feature_id
            8'b10110010, 8'b11110110,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 415: FID=67
        drive_and_check(
            8'b01000011,          // feature_id
            8'b11001110, 8'b01110011,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 416: FID=67
        drive_and_check(
            8'b01000011,          // feature_id
            8'b11110010, 8'b10111001,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 417: FID=67
        drive_and_check(
            8'b01000011,          // feature_id
            8'b00101110, 8'b01111100,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 418: FID=67
        drive_and_check(
            8'b01000011,          // feature_id
            8'b01000011, 8'b10110011,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 419: FID=68
        drive_and_check(
            8'b01000100,          // feature_id
            8'b10001011, 8'b01101011,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 420: FID=68
        drive_and_check(
            8'b01000100,          // feature_id
            8'b00011110, 8'b01100101,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 421: FID=68
        drive_and_check(
            8'b01000100,          // feature_id
            8'b11011000, 8'b10101110,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 422: FID=68
        drive_and_check(
            8'b01000100,          // feature_id
            8'b11101101, 8'b00110011,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 423: FID=68
        drive_and_check(
            8'b01000100,          // feature_id
            8'b10010111, 8'b01100011,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 424: FID=69
        drive_and_check(
            8'b01000101,          // feature_id
            8'b11100101, 8'b10001001,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 425: FID=69
        drive_and_check(
            8'b01000101,          // feature_id
            8'b11000100, 8'b00010000,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 426: FID=69
        drive_and_check(
            8'b01000101,          // feature_id
            8'b00110001, 8'b11110111,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 427: FID=69
        drive_and_check(
            8'b01000101,          // feature_id
            8'b01000010, 8'b11010010,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 428: FID=69
        drive_and_check(
            8'b01000101,          // feature_id
            8'b01000000, 8'b00110001,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 429: FID=70
        drive_and_check(
            8'b01000110,          // feature_id
            8'b10011110, 8'b00100110,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 430: FID=70
        drive_and_check(
            8'b01000110,          // feature_id
            8'b11101000, 8'b00100001,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 431: FID=70
        drive_and_check(
            8'b01000110,          // feature_id
            8'b10000011, 8'b10010010,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 432: FID=70
        drive_and_check(
            8'b01000110,          // feature_id
            8'b01011010, 8'b01011010,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 433: FID=70
        drive_and_check(
            8'b01000110,          // feature_id
            8'b00010011, 8'b10110101,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 434: FID=71
        drive_and_check(
            8'b01000111,          // feature_id
            8'b11110011, 8'b00100111,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 435: FID=71
        drive_and_check(
            8'b01000111,          // feature_id
            8'b01011010, 8'b01010010,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 436: FID=71
        drive_and_check(
            8'b01000111,          // feature_id
            8'b00010011, 8'b10110101,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 437: FID=71
        drive_and_check(
            8'b01000111,          // feature_id
            8'b11100111, 8'b00111100,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 438: FID=71
        drive_and_check(
            8'b01000111,          // feature_id
            8'b01111100, 8'b10100011,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b1, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 439: FID=72
        drive_and_check(
            8'b01001000,          // feature_id
            8'b11100101, 8'b00011111,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 440: FID=72
        drive_and_check(
            8'b01001000,          // feature_id
            8'b00011010, 8'b00010100,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 441: FID=72
        drive_and_check(
            8'b01001000,          // feature_id
            8'b00100001, 8'b10100101,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 442: FID=72
        drive_and_check(
            8'b01001000,          // feature_id
            8'b11000101, 8'b11001010,  // opa, opb
            4'b0000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 443: FID=72
        drive_and_check(
            8'b01001000,          // feature_id
            8'b00101100, 8'b00110011,  // opa, opb
            4'b0000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 444: FID=73
        drive_and_check(
            8'b01001001,          // feature_id
            8'b11001111, 8'b00100001,  // opa, opb
            4'b0010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 445: FID=73
        drive_and_check(
            8'b01001001,          // feature_id
            8'b01010011, 8'b10010001,  // opa, opb
            4'b0010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 446: FID=73
        drive_and_check(
            8'b01001001,          // feature_id
            8'b01100101, 8'b10101010,  // opa, opb
            4'b0010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 447: FID=73
        drive_and_check(
            8'b01001001,          // feature_id
            8'b10111000, 8'b00101110,  // opa, opb
            4'b0010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 448: FID=73
        drive_and_check(
            8'b01001001,          // feature_id
            8'b00001011, 8'b11101101,  // opa, opb
            4'b0010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 449: FID=74
        drive_and_check(
            8'b01001010,          // feature_id
            8'b10010011, 8'b10100011,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 450: FID=74
        drive_and_check(
            8'b01001010,          // feature_id
            8'b10001100, 8'b11001001,  // opa, opb
            4'b0100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 451: FID=74
        drive_and_check(
            8'b01001010,          // feature_id
            8'b01000000, 8'b00011001,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 452: FID=74
        drive_and_check(
            8'b01001010,          // feature_id
            8'b10100011, 8'b11110111,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 453: FID=74
        drive_and_check(
            8'b01001010,          // feature_id
            8'b11010110, 8'b11000100,  // opa, opb
            4'b0100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 454: FID=75
        drive_and_check(
            8'b01001011,          // feature_id
            8'b11101011, 8'b01100001,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 455: FID=75
        drive_and_check(
            8'b01001011,          // feature_id
            8'b00110100, 8'b01001100,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 456: FID=75
        drive_and_check(
            8'b01001011,          // feature_id
            8'b01011001, 8'b00110011,  // opa, opb
            4'b0110,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 457: FID=75
        drive_and_check(
            8'b01001011,          // feature_id
            8'b00011110, 8'b01010001,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 458: FID=75
        drive_and_check(
            8'b01001011,          // feature_id
            8'b11000110, 8'b00011011,  // opa, opb
            4'b0110,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 459: FID=76
        drive_and_check(
            8'b01001100,          // feature_id
            8'b01111010, 8'b00000010,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 460: FID=76
        drive_and_check(
            8'b01001100,          // feature_id
            8'b01101110, 8'b00010001,  // opa, opb
            4'b0111,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 461: FID=76
        drive_and_check(
            8'b01001100,          // feature_id
            8'b00100110, 8'b00011010,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 462: FID=76
        drive_and_check(
            8'b01001100,          // feature_id
            8'b11011001, 8'b11110011,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 463: FID=76
        drive_and_check(
            8'b01001100,          // feature_id
            8'b10100010, 8'b01111000,  // opa, opb
            4'b0111,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 464: FID=77
        drive_and_check(
            8'b01001101,          // feature_id
            8'b11001011, 8'b11000000,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 465: FID=77
        drive_and_check(
            8'b01001101,          // feature_id
            8'b00000100, 8'b00000000,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 466: FID=77
        drive_and_check(
            8'b01001101,          // feature_id
            8'b00001100, 8'b01010011,  // opa, opb
            4'b1000,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 467: FID=77
        drive_and_check(
            8'b01001101,          // feature_id
            8'b00001000, 8'b11111010,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 468: FID=77
        drive_and_check(
            8'b01001101,          // feature_id
            8'b01011011, 8'b01001111,  // opa, opb
            4'b1000,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 469: FID=78
        drive_and_check(
            8'b01001110,          // feature_id
            8'b10101011, 8'b00010110,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 470: FID=78
        drive_and_check(
            8'b01001110,          // feature_id
            8'b11010110, 8'b11110011,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 471: FID=78
        drive_and_check(
            8'b01001110,          // feature_id
            8'b01100011, 8'b00001010,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 472: FID=78
        drive_and_check(
            8'b01001110,          // feature_id
            8'b11111110, 8'b00101110,  // opa, opb
            4'b1001,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 473: FID=78
        drive_and_check(
            8'b01001110,          // feature_id
            8'b11100110, 8'b10110011,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b10,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 474: FID=79
        drive_and_check(
            8'b01001111,          // feature_id
            8'b01000001, 8'b11110011,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 475: FID=79
        drive_and_check(
            8'b01001111,          // feature_id
            8'b00011101, 8'b00101110,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 476: FID=79
        drive_and_check(
            8'b01001111,          // feature_id
            8'b01111100, 8'b10011111,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 477: FID=79
        drive_and_check(
            8'b01001111,          // feature_id
            8'b00010111, 8'b11001011,  // opa, opb
            4'b1010,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 478: FID=79
        drive_and_check(
            8'b01001111,          // feature_id
            8'b00000100, 8'b11001111,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 479: FID=80
        drive_and_check(
            8'b01010000,          // feature_id
            8'b11101101, 8'b01100010,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 480: FID=80
        drive_and_check(
            8'b01010000,          // feature_id
            8'b10011101, 8'b01000101,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 481: FID=80
        drive_and_check(
            8'b01010000,          // feature_id
            8'b10110100, 8'b10110110,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 482: FID=80
        drive_and_check(
            8'b01010000,          // feature_id
            8'b00011111, 8'b01111000,  // opa, opb
            4'b1011,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 483: FID=80
        drive_and_check(
            8'b01010000,          // feature_id
            8'b01110101, 8'b01011010,  // opa, opb
            4'b1011,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b01,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 484: FID=81
        drive_and_check(
            8'b01010001,          // feature_id
            8'b10110010, 8'b10010110,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 485: FID=81
        drive_and_check(
            8'b01010001,          // feature_id
            8'b10100110, 8'b01000100,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 486: FID=81
        drive_and_check(
            8'b01010001,          // feature_id
            8'b00000101, 8'b10011101,  // opa, opb
            4'b1100,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 487: FID=81
        drive_and_check(
            8'b01010001,          // feature_id
            8'b00010011, 8'b11101100,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 488: FID=81
        drive_and_check(
            8'b01010001,          // feature_id
            8'b00111011, 8'b00111010,  // opa, opb
            4'b1100,              // cmd
            1'b0, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 489: FID=82
        drive_and_check(
            8'b01010010,          // feature_id
            8'b10011010, 8'b11000001,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 490: FID=82
        drive_and_check(
            8'b01010010,          // feature_id
            8'b11100000, 8'b00110111,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 491: FID=82
        drive_and_check(
            8'b01010010,          // feature_id
            8'b10001101, 8'b11010111,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 492: FID=82
        drive_and_check(
            8'b01010010,          // feature_id
            8'b00111100, 8'b01100110,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );
        // Stimulus 493: FID=82
        drive_and_check(
            8'b01010010,          // feature_id
            8'b01011000, 8'b11111100,  // opa, opb
            4'b1101,              // cmd
            1'b1, 1'b1, 1'b0, // cin, ce, mode
            2'b00,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'b1  // cout,e,g,l,oflow,err
        );

        // Stimulus 494: FID=90
        drive_and_check(
            8'b00011011,          // feature_id
            8'b11111111, 8'b01100100,  // opa, opb
            4'b1001,              // cmd
            1'bx, 1'bx, 1'bx, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );

        // Stimulus 495: FID=90
        drive_and_check(
            8'b00011011,          // feature_id
            8'bxxxxxxxx, 8'bxxxxxxxx,  // opa, opb
            4'b1001,              // cmd
            1'bx, 1'bx, 1'bx, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );

        // Stimulus 496: FID=91
        drive_and_check(
            8'b00011011,          // feature_id
            8'b01100100, 8'b11111111,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );

        // Stimulus 497: FID=91
        drive_and_check(
            8'b00011011,          // feature_id
            8'bxxxxxxxx, 8'bxxxxxxxx,  // opa, opb
            4'b1001,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );

        // Stimulus 498: FID=92
        drive_and_check(
            8'b00011011,          // feature_id
            8'b10010011, 8'b01100100,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );

        // Stimulus 499: FID=92
        drive_and_check(
            8'b00011011,          // feature_id
            8'b10010011, 8'b01100100,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );

        // Stimulus 500: FID=92
        drive_and_check(
            8'b00011011,          // feature_id
            8'b10010011, 8'b01100100,  // opa, opb
            4'b1010,              // cmd
            1'b1, 1'b1, 1'b1, // cin, ce, mode
            2'b11,              // inp_valid
            16'bxxxxxxxxxxxxxxxx,  // exp_res
            1'bx, 1'bx, 1'bx, 1'bx, 1'bx, 1'bx  // cout,e,g,l,oflow,err
        );

        // --------------------------------------------------------
        // Summary
        // --------------------------------------------------------
        $display("\n=== TEST SUMMARY ===");
        $display("PASS: %0d / %0d", pass_count, `NUM_TESTS);
        $display("FAIL: %0d / %0d", fail_count, `NUM_TESTS);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        #100 $finish();
    end

endmodule
