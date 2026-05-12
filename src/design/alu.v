module alu #(parameter INPUT_WIDTH=8, CMD_WIDTH=4)(  
	input clk, rst, mode_in, ce,
	input [1:0] in_iv,
	input [CMD_WIDTH-1:0] cmd_in,
	input [INPUT_WIDTH-1:0] in_a, in_b,
	input in_cin,

	output reg err, oflow, cout, g, e, l,
	output reg [2*INPUT_WIDTH-1:0] res
);

	reg [1:0] inp_valid, iv_hold;
	reg [INPUT_WIDTH-1:0] a, a_hold, b, b_hold;
	reg cin;
	reg mode, mode_hold;
	reg [CMD_WIDTH-1:0] cmd, cmd_hold;

	reg next_err, next_oflow, next_cout, next_g, next_e, next_l;
	reg [2*INPUT_WIDTH-1:0] next_res;

	reg [4:0] prev_mode_cmd;

	localparam  ADD=5'b10000,  // 0
		    	SUB=5'b10001,  // 1
				ADD_CIN=5'b10010, // 2
				SUB_CIN=5'b10011, // 3 
				INC_A=5'b10100, // 4
				DEC_A=5'b10101, // 5
				INC_B=5'b10110, // 6
				DEC_B=5'b10111, // 7	b <= b_hold0;
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

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			res <= 0;
			oflow <= 0;
			cout <= 0;
			g <= 0;
			e <= 0;
			l <= 0;
			err <= 0;
			prev_mode_cmd <= 0;
		end else if(ce) begin
			if({mode_in, cmd_in} == MUL1 || {mode_in,cmd_in} == MUL2) begin
				if(prev_mode_cmd != {mode_in, cmd_in}) begin
					a_hold <= in_a;
					b_hold <= in_b;
					iv_hold <= in_iv;
					prev_mode_cmd <= {mode_in, cmd_in};

					mode_hold <= mode_in;
					cmd_hold <= cmd_in;
				end else begin
					a <= a_hold;
					b <= b_hold;
					inp_valid <= iv_hold;
					prev_mode_cmd <= 0;
					
					mode <= mode_hold;
					cmd <= cmd_hold;
				end
			end else begin
				a <= in_a;
				b <= in_b;
				inp_valid <= in_iv;
				cin <= in_cin;

				mode <= mode_in;
				cmd <= cmd_in;
			end
		
			res <= next_res;
			err <= next_err;
			oflow <= next_oflow;
			cout <= next_cout;
			g <= next_g;
			e <= next_e;
			l <= next_l;
		end
	end

	always @(*) begin
		{next_err, next_oflow, next_cout, next_g, next_e, next_l} = 0;

		case({mode, cmd})
			ADD: begin
				if(inp_valid != 2'b11) begin
					next_err = 1;
				end else begin
					next_res = a+b;
					next_cout = next_res[INPUT_WIDTH];
				end
			end
			SUB: begin
				if(inp_valid != 2'b11) begin
					next_err = 1;
				end else begin
					{next_oflow, next_res} = a-b;
				end
			end
			ADD_CIN: begin
				if(inp_valid != 2'b11) begin
					next_err = 1;
				end else begin
					next_res = a+b+cin;
					next_cout = next_res[INPUT_WIDTH];
				end	
			end
			SUB_CIN: begin
				if(inp_valid != 2'b11) begin
					next_err = 1;
				end else begin
					{next_oflow, next_res} = a-b-cin;
				end
			end
			INC_A: begin
				if(~inp_valid[0])
					next_err = 1;
				else 
					next_res = (a+1)&{INPUT_WIDTH{1'b1}};
			end
			DEC_A: begin
				if(~inp_valid[0])
					next_err = 1;
				else 
					next_res = (a-1)&{INPUT_WIDTH{1'b1}};
			end
			INC_B: begin
				if(~inp_valid[1])
					next_err = 1;
				else 
					next_res = (b+1)&{INPUT_WIDTH{1'b1}};
			end
			DEC_B: begin
				if(~inp_valid[1])
					next_err = 1;
				else 
					next_res = (b-1)&{INPUT_WIDTH{1'b1}};
			end
			CMP: begin
				if(inp_valid != 2'b11) begin
					next_err = 1;
				end else begin
					next_e = (a==b);
					next_g = (a>b);
					next_l = (a<b);
				end				
				next_res = 0;
			end
			MUL1: begin
				if(inp_valid != 2'b11) 
					next_err = 1;
				else 
					next_res = ((a+1)&{INPUT_WIDTH{1'b1}}) * ((b+1)&{INPUT_WIDTH{1'b1}}); 
			end
			MUL2: begin
				if(inp_valid != 2'b11) 
					next_err = 1;
				else
					next_res = ((a<<1)&{INPUT_WIDTH{1'b1}}) * b;
			end
			SIGNED_ADD: begin
				if(inp_valid != 2'b11) 
					next_err = 1;
				else begin
					next_res = $signed(a) + $signed(b);
					next_oflow = (a[INPUT_WIDTH-1] == b[INPUT_WIDTH-1]) && (next_res[INPUT_WIDTH-1] != a[INPUT_WIDTH-1]);
					next_e = (a==b);
					next_g = $signed(a) > $signed(b);
					next_l = $signed(a) < $signed(b);
				end
			end
			SIGNED_SUB: begin
				if(inp_valid != 2'b11) 
					next_err = 1;
				else begin
					next_res = $signed(a) - $signed(b);
					next_oflow = (a[INPUT_WIDTH-1] != b[INPUT_WIDTH-1]) && (next_res[INPUT_WIDTH-1] != a[INPUT_WIDTH-1]);
					next_e = (a==b);
					next_g = $signed(a) > $signed(b);
					next_l = $signed(a) < $signed(b);
				end
			end

			AND: begin
				if(inp_valid != 2'b11) 
					next_err = 1;
				else 
					next_res = a&b&{INPUT_WIDTH{1'b1}};
			end
			NAND: begin
				if(inp_valid != 2'b11) 
					next_err = 1;
				else 
					next_res = ~(a&b)&{INPUT_WIDTH{1'b1}};
			end
			OR: begin
				if(inp_valid != 2'b11) 
					next_err = 1;
				else 
					next_res = (a|b)&{INPUT_WIDTH{1'b1}};
			end
			NOR: begin
				if(inp_valid != 2'b11) 
					next_err = 1;
				else 
					next_res = ~(a|b)&{INPUT_WIDTH{1'b1}};
			end
			XOR: begin
				if(inp_valid != 2'b11) 
					next_err = 1;
				else 
					next_res = (a^b)&{INPUT_WIDTH{1'b1}};
			end
			XNOR: begin
				if(inp_valid != 2'b11) 
					next_err = 1;
				else 
					next_res = ~(a^b)&{INPUT_WIDTH{1'b1}};
			end
			NOT_A: begin
				if(~inp_valid[0]) 
					next_err = 1;
				else 
					next_res = (~a)&{INPUT_WIDTH{1'b1}};
			end
			NOT_B: begin
				if(~inp_valid[1]) 
					next_err = 1;
				else 
					next_res = (~b)&{INPUT_WIDTH{1'b1}};
			end
			SHR1_A: begin
				if(~inp_valid[0]) 
					next_err = 1;
				else 
					next_res = (a>>1) & {(INPUT_WIDTH){1'b1}};
			end
			SHL1_A: begin
				if(~inp_valid[0]) 
					next_err = 1;
				else 
					next_res = (a<<1) & {(INPUT_WIDTH){1'b1}};
			end
			SHR1_B: begin
				if(~inp_valid[1]) 
					next_err = 1;
				else 
					next_res = (b>>1) & {(INPUT_WIDTH){1'b1}};
			end
			SHL1_B: begin
				if(~inp_valid[1]) 
					next_err = 1;
				else 
					next_res = (b<<1) & {(INPUT_WIDTH){1'b1}};
			end
			ROL_A_B: begin
				if(inp_valid != 2'b11) begin
					next_err = 1;
				end else begin
					next_err = (b>=15);
					next_res = a<<b[$clog2(INPUT_WIDTH)-1:0];
					next_res = {{INPUT_WIDTH{1'b0}}, next_res[INPUT_WIDTH-1:0]|next_res[2*INPUT_WIDTH-1:INPUT_WIDTH]};
				end
			end
			ROR_A_B: begin
				if(inp_valid != 2'b11) begin
					next_err = 1;
				end else begin
					next_err = (b>=15);
					next_res = a<<(INPUT_WIDTH-b[$clog2(INPUT_WIDTH)-1:0]);
					next_res = {{INPUT_WIDTH{1'b0}}, next_res[INPUT_WIDTH-1:0]|next_res[2*INPUT_WIDTH-1:INPUT_WIDTH]};
				end
			end
		endcase
	end
endmodule


