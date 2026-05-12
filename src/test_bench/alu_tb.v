`define NUM_TESTS 524

module alu_tb;

    // DUT pins
    reg CLK, RST, CE, MODE, CIN;
    reg [1:0] INP_VALID;
    reg [3:0] CMD;
    reg [7:0] OPA, OPB;
    wire [15:0] RES;
    wire ERR, OFLOW, COUT, G, E, L;

    // Reference model pins
    reg mode_ref, cin_ref, ce_ref;
    reg [1:0] iv_ref;
    reg [3:0] cmd_ref;
    reg [7:0] a_ref, b_ref;
    wire [15:0] res_ref;
    wire err_ref, oflow_ref, cout_ref, g_ref, e_ref, l_ref;

    alu_ref REF (
       .mode (mode_ref),
       .inp_valid (iv_ref),
	   .ce(ce_ref),
       .cmd (cmd_ref),
       .a (a_ref),
       .b (b_ref),
       .cin (cin_ref),
       .err (err_ref),
       .oflow (oflow_ref),
       .cout (cout_ref),
       .g (g_ref),
       .e (e_ref),
       .l (l_ref),
       .res (res_ref)
    );

    alu DUT (
        .clk       (CLK),
        .rst       (RST),
        .ce        (CE),
        .mode_in     (MODE),
        .in_iv (INP_VALID),
        .cmd_in       (CMD),
        .in_a       (OPA),
        .in_b       (OPB),
        .in_cin       (CIN),
        .res       (RES),
        .err       (ERR),
        .oflow     (OFLOW),
        .cout      (COUT),
        .g         (G),
        .e         (E),
        .l         (L)
    );
    
    // Eight_bit_ALU_rtl_design DUT (
    //     .CLK      (CLK),
    //     .RST       (RST),
    //     .CE        (CE),
    //     .MODE      (MODE),
    //     .INP_VALID (INP_VALID),
    //     .CMD      (CMD),
    //     .OPA       (OPA),
    //     .OPB       (OPB),
    //     .CIN       (CIN),
    //     .RES       (RES),
    //     .ERR       (ERR),
    //     .OFLOW     (OFLOW),
    //     .COUT      (COUT),
    //     .G         (G),
    //     .E         (E),
    //     .L         (L)
    // );

    integer pass_count = 0;
    integer fail_count = 0;

    initial CLK = 0;
    always #60 CLK = ~CLK;
    
	reg is_first;
	initial is_first = 1;

	reg [32:0] stim_mem [0:`NUM_TESTS-1];
	
    task do_reset;
        begin
			@(negedge CLK);
            RST = 1; CE = 1; ce_ref=1;
            @(posedge CLK); #1;
            RST = 0;
        end
    endtask

	task drive_and_check;
		input integer tc;
		reg [7:0] fid;
		integer back, i;

		begin
			back=0; 
			@(negedge CLK);
			{OPA, OPB, CIN, MODE, CMD, INP_VALID, CE} = stim_mem[tc][24:0];

			@(posedge CLK);
	
			if((!is_first)) begin

				for(i=0; i<tc; i++) begin
					if(stim_mem[i][0])
						back=0;
					else
						back=back+1;	
				end

				if(stim_mem[tc-1][7:3] == 5'b11001 || stim_mem[tc-1][7:3] == 5'b11010) begin
					back = back+2;
				end else begin
					back=back+1;
				end
				
				fid = stim_mem[tc-back][32:25];
				if(CE)
					{a_ref, b_ref, cin_ref, mode_ref, cmd_ref, iv_ref} = stim_mem[tc-back][24:1];
				#10;

				begin : scoreboard
					reg [21:0] ref_bnd, dut_bnd;
					reg pass;
					integer i;
					ref_bnd = {res_ref, err_ref, oflow_ref, cout_ref, g_ref, e_ref, l_ref};
					dut_bnd = {RES,ERR, OFLOW, COUT, G, E, L};
					pass = 1'b1;
					for (i=0; i<22; i=i+1) begin
						if (ref_bnd[i] !== 1'bx)
							if (ref_bnd[i] !== dut_bnd[i])
								pass = 1'b0;
					end
					if (pass) begin
						$display("PASS | FID=%d | OPA=%d OPB=%d CMD=%d MODE=%b INP_VALID=%2b | RES=%d COUT=%b EGL=%b%b%b OFLOW=%b ERR=%b",
							fid, a_ref, b_ref, cmd_ref, mode_ref, iv_ref,
							RES, COUT, E, G, L, OFLOW, ERR);
						pass_count = pass_count + 1;
					end else begin
						$write("FAIL | FID=%d | OPA=%d OPB=%d CMD=%d MODE=%b INP_VALID=%2b | ",
							fid, a_ref, b_ref, cmd_ref, mode_ref, iv_ref);
						$display("[EXP/GOT: RES=%d/%d COUT=%b/%b EGL=%b%b%b/%b%b%b OFLOW=%b/%b ERR=%b/%b]",
							res_ref, RES,
							cout_ref, COUT,
							e_ref, g_ref, l_ref, E, G, L,
							oflow_ref, OFLOW,
							err_ref, ERR);
						fail_count = fail_count + 1;
					end
				end
			end else begin
				is_first = 0;
			end
		end
	endtask

    initial begin
        $dumpfile("wave.vcd"); 
        $dumpvars(0, alu_tb);
        RST = 0; MODE = 0; CMD = 0;
        OPA = 0; OPB = 0; CIN = 0; INP_VALID = 2'b11;
        do_reset();

        $readmemb("stimulus.txt", stim_mem);

        begin : stim_loop
            integer tc;
            reg [7:0]  fid;
            reg [7:0]  a_s, b_s;
            reg        cin_s, mode_s, ce_s;
            reg [1:0]  iv_s;
            reg [3:0]  cmd_s;
            for (tc = 0; tc <= `NUM_TESTS; tc = tc + 1) 
                drive_and_check(tc);
		end

        $display("\n=== TEST SUMMARY ===");
        $display("PASS: %d / %d", pass_count, `NUM_TESTS);
        $display("FAIL: %d / %d", fail_count, `NUM_TESTS);
        #100 $finish();
    end
endmodule


module alu_ref #(parameter INPUT_WIDTH=8, CMD_WIDTH=4)(  
	input mode,
	input [1:0] inp_valid,
	input [CMD_WIDTH-1:0] cmd,
	input [INPUT_WIDTH-1:0] a, b,
	input cin, ce,

	output reg err, oflow, cout, g, e, l,
	output reg [2*INPUT_WIDTH-1:0] res
);
	localparam  ADD=5'b10000,  // 0
		    	SUB=5'b10001,  // 1
				ADD_CIN=5'b10010, // 2
				SUB_CIN=5'b10011, // 3 
				INC_A=5'b10100, // 4
				DEC_A=5'b10101, // 5
				INC_B=5'b10110, // 6
				DEC_B=5'b10111, // 7	
				CMP=5'b11000, // 8
				MUL1=5'b11001, // 9
				MUL2=5'b11010, // 10
				SIGNED_ADD=5'b11011, // 11
				SIGNED_SUB=5'b11100, // 12

				AND=5'b00000, // 0 
				NAND=5'b00001, // 1
				OR=5'b00010, // 2
				NOR=5'b00011, // 3 
				XOR=5'b00100, // 4
				XNOR=5'b00101, // 5
				NOT_A=5'b00110, // 6
				NOT_B=5'b00111, // 7 
				SHR1_A=5'b01000, // 8
				SHL1_A=5'b01001, // 9
				SHR1_B=5'b01010, // 10 
				SHL1_B=5'b01011, // 11
				ROL_A_B=5'b01100, // 12 
				ROR_A_B=5'b01101; // 13

	always @(*) begin
		{res, err, oflow, cout, g, e, l} = {(2*INPUT_WIDTH+6){1'bx}};
		case({mode, cmd})
			ADD: begin
				if(inp_valid != 2'b11) begin
					err = 1;
				end else begin
					res = a+b;
					cout = res[INPUT_WIDTH];
				end
			end
			SUB: begin
				if(inp_valid != 2'b11) begin
					err = 1;
				end else begin
					{oflow, res} = a-b;
				end
			end
			ADD_CIN: begin
				if(inp_valid != 2'b11) begin
					err = 1;
				end else begin
					res = a+b+cin;
					cout = res[INPUT_WIDTH];
				end	
			end
			SUB_CIN: begin
				if(inp_valid != 2'b11) begin
					err = 1;
				end else begin
					{oflow, res} = a-b-cin;
				end
			end
			INC_A: begin
				if(~inp_valid[0])
					err = 1;
				else 
					res = (a+1)&{INPUT_WIDTH{1'b1}};
			end
			DEC_A: begin
				if(~inp_valid[0])
					err = 1;
				else 
					res = (a-1)&{INPUT_WIDTH{1'b1}};
			end
			INC_B: begin
				if(~inp_valid[1])
					err = 1;
				else 
					res = (b+1)&{INPUT_WIDTH{1'b1}};
			end
			DEC_B: begin
				if(~inp_valid[1])
					err = 1;
				else 
					res = (b-1)&{INPUT_WIDTH{1'b1}};
			end
			CMP: begin
				if(inp_valid != 2'b11) begin
					err = 1;
				end else begin
					e = (a==b);
					g = (a>b);
					l = (a<b);
				end				
			end
			MUL1: begin
				if(inp_valid != 2'b11) 
					err = 1;
				else 
					res = ((a+1)&{INPUT_WIDTH{1'b1}}) * ((b+1)&{INPUT_WIDTH{1'b1}}); 
						
			end
			MUL2: begin
				if(inp_valid != 2'b11) 
					err = 1;
				else
					res = ((a<<1)&{INPUT_WIDTH{1'b1}}) * b;
			end
			SIGNED_ADD: begin
				if(inp_valid != 2'b11) 
					err = 1;
				else begin
					res = $signed(a) + $signed(b);
					oflow = (a[INPUT_WIDTH-1] == b[INPUT_WIDTH-1]) && (res[INPUT_WIDTH-1] != a[INPUT_WIDTH-1]);
					e = (a==b);
					g = $signed(a) > $signed(b);
					l = $signed(a) < $signed(b);
				end
			end
			SIGNED_SUB: begin
				if(inp_valid != 2'b11) 
					err = 1;
				else begin
					res = $signed(a) - $signed(b);
					oflow = (a[INPUT_WIDTH-1] != b[INPUT_WIDTH-1]) && (res[INPUT_WIDTH-1] != a[INPUT_WIDTH-1]);
					e = (a==b);
					g = $signed(a) > $signed(b);
					l = $signed(a) < $signed(b);
				end
			end

			AND: begin
				if(inp_valid != 2'b11) 
					err = 1;
				else 
					res = a&b&{INPUT_WIDTH{1'b1}};
			end
			NAND: begin
				if(inp_valid != 2'b11) 
					err = 1;
				else 
					res = ~(a&b)&{INPUT_WIDTH{1'b1}};
			end
			OR: begin
				if(inp_valid != 2'b11) 
					err = 1;
				else 
					res = (a|b)&{INPUT_WIDTH{1'b1}};
			end
			NOR: begin
				if(inp_valid != 2'b11) 
					err = 1;
				else 
					res = ~(a|b)&{INPUT_WIDTH{1'b1}};
			end
			XOR: begin
				if(inp_valid != 2'b11) 
					err = 1;
				else 
					res = (a^b)&{INPUT_WIDTH{1'b1}};
			end
			XNOR: begin
				if(inp_valid != 2'b11) 
					err = 1;
				else 
					res = ~(a^b)&{INPUT_WIDTH{1'b1}};
			end
			NOT_A: begin
				if(~inp_valid[0]) 
					err = 1;
				else 
					res = (~a)&{INPUT_WIDTH{1'b1}};
			end
			NOT_B: begin
				if(~inp_valid[1]) 
					err = 1;
				else 
					res = (~b)&{INPUT_WIDTH{1'b1}};
			end
			SHR1_A: begin
				if(~inp_valid[0]) 
					err = 1;
				else 
					res = (a>>1) & {(INPUT_WIDTH){1'b1}};
			end
			SHL1_A: begin
				if(~inp_valid[0]) 
					err = 1;
				else 
					res = (a<<1) & {(INPUT_WIDTH){1'b1}};
			end
			SHR1_B: begin
				if(~inp_valid[1]) 
					err = 1;
				else 
					res = (b>>1) & {(INPUT_WIDTH){1'b1}};
			end
			SHL1_B: begin
				if(~inp_valid[1]) 
					err = 1;
				else 
					res = (b<<1) & {(INPUT_WIDTH){1'b1}};
			end
			ROL_A_B: begin
				if(inp_valid != 2'b11) begin
					err = 1;
				end else begin
					err = (b>=15);
					res = a<<b[$clog2(INPUT_WIDTH)-1:0];
					res = {{INPUT_WIDTH{1'b0}}, res[INPUT_WIDTH-1:0]|res[2*INPUT_WIDTH-1:INPUT_WIDTH]};
				end
			end
			ROR_A_B: begin
				if(inp_valid != 2'b11) begin
					err = 1;
				end else begin
					err = (b>=15);
					res = a<<(INPUT_WIDTH-b[$clog2(INPUT_WIDTH)-1:0]);
					res = {{INPUT_WIDTH{1'b0}}, res[INPUT_WIDTH-1:0]|res[2*INPUT_WIDTH-1:INPUT_WIDTH]};
				end
			end
		endcase
	end
endmodule