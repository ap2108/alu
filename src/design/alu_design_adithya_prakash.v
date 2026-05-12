module Eight_bit_ALU_rtl_design#(parameter N=8, parameter M=16)
(OPA,OPB,CIN,CLK,RST,CMD,inp_valid,CE,MODE,COUT,OFLOW,RES,G,E,L,ERR);

input signed [N-1:0] OPA, OPB;
input CLK, RST, CE, MODE, CIN;
input [3:0] CMD;
input [1:0] inp_valid;

output reg [M-1:0] RES = 0;
output reg COUT = 0;
output reg OFLOW = 0;
output reg G = 0, E = 0, L = 0;
output reg ERR = 0;

reg [N-1:0] OPA_1, OPB_1;
reg [1:0] cnt9, cnt10;
reg [M-1:0] temp9, temp10;
reg signed [N-1:0] res_n;

always @(posedge CLK or posedge RST)
begin
    if(RST) begin
        OPA_1 <= 0;
        OPB_1 <= 0;
    end

    else if(CE) begin
        case(inp_valid)

            2'b01: begin
                OPA_1 <= OPA;
            end

            2'b10: begin
                OPB_1 <= OPB;
            end

            2'b11: begin
                OPA_1 <= OPA;
                OPB_1 <= OPB;
            end

            default: begin
                OPA_1 <= OPA_1;
                OPB_1 <= OPB_1;
            end

        endcase
    end
end

always @(posedge CLK or posedge RST)
begin
    if (RST) begin
        RES<=0; COUT<=0; OFLOW<=0;
        G<=0; E<=0; L<=0; ERR<=0;
    end

    else if (CE) begin
       // RES<=0; 
       COUT<=0; OFLOW<=0;
        G<=0; E<=0; L<=0; ERR<=0;

        if (MODE) begin
            case (CMD)

            4'b0000:
                if(inp_valid==2'b11)
                begin
                    RES <= OPA_1 + OPB_1;
                     COUT<=RES[N]?1:0;
                     end      
                else ERR <= 1;

            4'b0001:
                if(inp_valid==2'b11) begin
                    res_n <= OPA_1 - OPB_1;
                    RES   <= res_n;
                    OFLOW <= (OPA_1[N-1] != OPB_1[N-1]) &&
                             (res_n[N-1] != OPA_1[N-1]);
                end
                else ERR <= 1;

            4'b0010:
                if(inp_valid==2'b11)
                begin
                   RES <= OPA_1 + OPB_1 + CIN;
                   COUT<=RES[N]?1:0;
                   end
                else begin
                RES<= 0;
                ERR <= 1;
                end

            4'b0011:
                if(inp_valid==2'b11) begin
                    res_n <= OPA_1 - OPB_1 - CIN;
                    RES   <= res_n;
                    OFLOW <= (OPA_1[N-1] != OPB_1[N-1]) &&
                             (res_n[N-1] != OPA_1[N-1]);
                end
                else ERR <= 1;

            4'b0100:
                if(inp_valid==2'b01 || inp_valid==2'b11)
                begin
                RES <= OPA_1 + 1;
                end
                else ERR <= 1;

            4'b0101:
                if(inp_valid==2'b01 || inp_valid==2'b11) 
                begin
                RES <= OPA_1 - 1;
                end
                else ERR <= 1;

            4'b0110:
                if(inp_valid==2'b10 || inp_valid==2'b11) 
                begin
                RES <= OPB_1 + 1;
                end
                else ERR <= 1;

            4'b0111:
                if(inp_valid==2'b10 || inp_valid==2'b11) 
                begin
                RES <= OPB_1 - 1;
                end
                else ERR <= 1;

            4'b1000:
                if(inp_valid==2'b11) begin
                    if (OPA_1 > OPB_1) begin G<=1; end
                    else if (OPA_1 < OPB_1) begin L<=1; end
                    else begin E<=1; end
                end
                else ERR <= 1;

    
   4'b1001:
begin
    if(cnt9 == 2'd1)
    begin
        RES  <= temp9;
        cnt9 <= 2'd0;
    end

    else if(inp_valid == 2'b11)
    begin
        temp9 <= (OPA_1 + 1) * (OPB_1 + 1);
        RES   <= {M{1'bx}};
        cnt9  <= 2'd1;
    end

    else
        ERR <= 1;
end


4'b1010:
begin
    if(cnt10 == 2'd1)
    begin
        RES   <= temp10;
        cnt10 <= 2'd0;
    end

    else if(inp_valid == 2'b11)
    begin
        temp10 <= (OPA_1 << 1) * OPB_1;
        RES    <= {M{1'bx}};
        cnt10  <= 2'd1;
    end

    else
        ERR <= 1;
end

            4'b1011:
                if(inp_valid==2'b11) begin
                    res_n <= $signed(OPA_1) + $signed(OPB_1);
                    RES   <= res_n;
                    OFLOW <= (OPA_1[N-1] == OPB_1[N-1]) &&
                             (res_n[N-1] != OPA_1[N-1]);
                end
                else ERR <= 1;

            4'b1100:
                if(inp_valid==2'b11) begin
                    res_n <= $signed(OPA_1) - $signed(OPB_1);
                    RES   <= res_n;
                    OFLOW <= (OPA_1[N-1] != OPB_1[N-1]) &&
                             (res_n[N-1] != OPA_1[N-1]);
                end
                else ERR <= 1;

            endcase
        end

        else begin
            case(CMD)

                4'b0000:
                    if(inp_valid==2'b11) RES <= {1'b0, OPA_1 & OPB_1};
                    else ERR <= 1;

                4'b0001:
                    if(inp_valid==2'b11) RES <= {1'b0, ~(OPA_1 & OPB_1)};
                    else ERR <= 1;

                4'b0010:
                    if(inp_valid==2'b11) RES <= {1'b0, OPA_1 | OPB_1};
                    else ERR <= 1;

                4'b0011:
                    if(inp_valid==2'b11) RES <= {1'b0, ~(OPA_1 | OPB_1)};
                    else ERR <= 1;

                4'b0100:
                    if(inp_valid==2'b11) RES <= {1'b0, OPA_1 ^ OPB_1};
                    else ERR <= 1;

                4'b0101:
                    if(inp_valid==2'b11) RES <= {1'b0, ~(OPA_1 ^ OPB_1)};
                    else ERR <= 1;

                4'b0110:
                    if(inp_valid==2'b01) RES <= {1'b0, ~OPA_1};
                    else ERR <= 1;

                4'b0111:
                    if(inp_valid==2'b10) RES <= {1'b0, ~OPB_1};
                    else ERR <= 1;
                    
                    4'b1000: // SHR A
    if(inp_valid==2'b01)
        RES <= {1'b0, (OPA_1 >> 1)};
    else ERR <= 1;

4'b1001: // SHL A
    if(inp_valid==2'b01)
        RES <= {1'b0, (OPA_1 << 1)};
    else ERR <= 1;

4'b1010: // SHR B
    if(inp_valid==2'b10)
        RES <= {1'b0, (OPB_1 >> 1)};
    else ERR <= 1;

4'b1011: // SHL B
    if(inp_valid==2'b10)
        RES <= {1'b0, (OPB_1 << 1)};
    else ERR <= 1;
    4'b1100:
    if(inp_valid==2'b11) begin
        if (OPB_1[N-1:3] != 0) begin
            ERR <= 1;
            RES <= {1'b0, OPA_1};
        end
        else begin
            if (OPB_1[2:0] == 0)
                RES <= {1'b0, OPA_1};
            else
                RES <= {1'b0, (({OPA_1,OPA_1} << OPB_1[2:0]) >> N)};
        end
    end
    else ERR <= 1;
    4'b1101:
    if(inp_valid==2'b11) begin
        if (OPB_1[N-1:3] != 0) begin
            ERR <= 1;
            RES <= {1'b0, OPA_1};
        end
        else begin
            if (OPB_1[2:0] == 0)
                RES <= {1'b0, OPA_1};
            else
                RES <= {1'b0, (({OPA_1,OPA_1} >> OPB_1[2:0]) >> N)};
        end
    end
    else ERR <= 1;
    default: begin
    ERR <= 1;
    RES <= 0;
end

            endcase
        end
    end
end

endmodule
