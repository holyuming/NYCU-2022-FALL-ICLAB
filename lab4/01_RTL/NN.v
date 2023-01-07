module NN(
	// Input signals
	clk,
	rst_n,
	in_valid_u,
	in_valid_w,
	in_valid_v,
	in_valid_x,
	weight_u,
	weight_w,
	weight_v,
	data_x,
	// Output signals
	out_valid,
	out
);

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 2;

//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input  clk, rst_n, in_valid_u, in_valid_w, in_valid_v, in_valid_x;
input [inst_sig_width+inst_exp_width:0] weight_u, weight_w, weight_v;
input [inst_sig_width+inst_exp_width:0] data_x;
output reg	out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;

//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
genvar i;
localparam 	S_IDLE = 0,
			S_READ = 1,
			S_CAL = 2,
			S_OUT = 3;

reg [1:0] c_state, n_state;

reg [inst_sig_width+inst_exp_width:0] U [0:8], n_U [0:8], W [0:8], n_W [0:8], V [0:8], n_V [0:8];				// U, V, W
reg [inst_sig_width+inst_exp_width:0] dX [0:8], n_dX [0:8];														// data_x

reg [inst_sig_width+inst_exp_width:0] h1 [0:2], h2 [0:2], h3 [0:2], n_h1 [0:2], n_h2 [0:2], n_h3 [0:2];			// h
reg [inst_sig_width+inst_exp_width:0] Ux1 [0:2], Ux2 [0:2], Ux3 [0:2], n_Ux1 [0:2], n_Ux2 [0:2], n_Ux3 [0:2]; 	// ux
reg [inst_sig_width+inst_exp_width:0] Vh1 [0:2], Vh2 [0:2], Vh3 [0:2], n_Vh1 [0:2], n_Vh2 [0:2], n_Vh3 [0:2]; 	// vh
reg [inst_sig_width+inst_exp_width:0] Wh1 [0:2], Wh2 [0:2], n_Wh1 [0:2], n_Wh2 [0:2]; 							// hw

// DW MATMUL input
// used for matmul
reg [inst_sig_width+inst_exp_width:0] dx0, dx1, dx2, ary00, ary01, ary02, ary03, ary10, ary11, ary12, ary20, ary21, ary22; 
wire [inst_sig_width+inst_exp_width:0] out0, out1, out2; 		

// used for add_sigmoid
reg [inst_sig_width+inst_exp_width:0] sel00, sel01, sel02, sel10, sel11, sel12; 
wire [inst_sig_width+inst_exp_width:0] hout0, hout1, hout2;	
wire [inst_sig_width+inst_exp_width:0] IEEE_0;	

// used for relu
reg [inst_sig_width+inst_exp_width:0] rin; 
wire [inst_sig_width+inst_exp_width:0] rout;		

// output
reg n_out_valid;
reg [inst_sig_width+inst_exp_width:0] n_out;

// counter
reg [3:0] cnt, cnt1; // max at 15


// IP-------------
MATMUL M0 (
	.dx0(dx0), .dx1(dx1), .dx2(dx2), 
	
	.ary00(ary00), .ary01(ary01), .ary02(ary02), 
	.ary10(ary10), .ary11(ary11), .ary12(ary12),
	.ary20(ary20), .ary21(ary21), .ary22(ary22),

	.out0(out0), .out1(out1), .out2(out2)
);

ADD_SIGMOID AS0 (
	.ux0(sel00), .ux1(sel01), .ux2(sel02),
	.wh0(sel10), .wh1(sel11), .wh2(sel12),
	.out0(hout0), .out1(hout1), .out2(hout2)
);

ReLU R0 (.in(rin), .out(rout));
//----------------


// fsm
always @(*) begin
	case (c_state)
		S_IDLE:	n_state = (in_valid_u == 1) ? S_READ : S_IDLE;
		S_READ:	n_state = (in_valid_u == 0) ? S_CAL  : S_READ;
		S_CAL:	n_state = (cnt == 10) ? S_IDLE : S_CAL;	
		default: n_state = S_IDLE; 
	endcase
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n)	c_state <= S_IDLE;
	else		c_state <= n_state;
end


// counter
always @(*) begin
	cnt1 = (n_state == S_CAL) ? cnt + 1 : 0;
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n)	cnt <= 0;
	else		cnt <= cnt1;
end

// read input
generate
for (i=0 ; i<=7 ; i=i+1) begin
	always @(*) begin	
		n_dX[i] = (in_valid_x == 1) ? dX[i+1] : dX[i];
		n_U[i] = (in_valid_u == 1) ? U[i+1] : U[i];
		n_W[i] = (in_valid_w == 1) ? W[i+1] : W[i];
		n_V[i] = (in_valid_v == 1) ? V[i+1] : V[i];
	end
end
endgenerate

always @(*) begin
	n_dX[8] = (in_valid_x == 1) ? data_x : dX[8];
	n_U[8] = (in_valid_u == 1) ? weight_u : U[8];
	n_W[8] = (in_valid_w == 1) ? weight_w : W[8];
	n_V[8] = (in_valid_v == 1) ? weight_v : V[8];
end


generate
for (i=0 ; i<=8 ; i=i+1) begin
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n)	begin
			U[i] <= 0;
			W[i] <= 0;
			V[i] <= 0;

			dX[i] <= 0;
		end
		else begin
			U[i] <= n_U[i];
			W[i] <= n_W[i];
			V[i] <= n_V[i];

			dX[i] <= n_dX[i];
		end		
	end
end
endgenerate


// matmul multiplications selection
always @(*) begin
	case (cnt)
		0: begin
			// x1
			dx0 = dX[0];
			dx1 = dX[1];
			dx2 = dX[2];
			// U
			ary00 = U[0]; ary01 = U[1]; ary02 = U[2];
			ary10 = U[3]; ary11 = U[4]; ary12 = U[5];
			ary20 = U[6]; ary21 = U[7]; ary22 = U[8];
		end 
		1: begin
			// x2
			dx0 = dX[3];
			dx1 = dX[4];
			dx2 = dX[5];
			// U
			ary00 = U[0]; ary01 = U[1]; ary02 = U[2];
			ary10 = U[3]; ary11 = U[4]; ary12 = U[5];
			ary20 = U[6]; ary21 = U[7]; ary22 = U[8];
		end
		2: begin
			// h1
			dx0 = h1[0];
			dx1 = h1[1];
			dx2 = h1[2];
			// V
			ary00 = V[0]; ary01 = V[1]; ary02 = V[2];
			ary10 = V[3]; ary11 = V[4]; ary12 = V[5];
			ary20 = V[6]; ary21 = V[7]; ary22 = V[8];
		end
		3: begin
			// h1
			dx0 = h1[0];
			dx1 = h1[1];
			dx2 = h1[2];
			// W
			ary00 = W[0]; ary01 = W[1]; ary02 = W[2];
			ary10 = W[3]; ary11 = W[4]; ary12 = W[5];
			ary20 = W[6]; ary21 = W[7]; ary22 = W[8];
		end
		4: begin
			// x3
			dx0 = dX[6];
			dx1 = dX[7];
			dx2 = dX[8];
			// U
			ary00 = U[0]; ary01 = U[1]; ary02 = U[2];
			ary10 = U[3]; ary11 = U[4]; ary12 = U[5];
			ary20 = U[6]; ary21 = U[7]; ary22 = U[8];
		end
		5: begin
			// h2
			dx0 = h2[0];
			dx1 = h2[1];
			dx2 = h2[2];
			// V
			ary00 = V[0]; ary01 = V[1]; ary02 = V[2];
			ary10 = V[3]; ary11 = V[4]; ary12 = V[5];
			ary20 = V[6]; ary21 = V[7]; ary22 = V[8];
		end
		6: begin
			// h2
			dx0 = h2[0];
			dx1 = h2[1];
			dx2 = h2[2];
			// W
			ary00 = W[0]; ary01 = W[1]; ary02 = W[2];
			ary10 = W[3]; ary11 = W[4]; ary12 = W[5];
			ary20 = W[6]; ary21 = W[7]; ary22 = W[8];
		end
		8: begin
			// h3
			dx0 = h3[0];
			dx1 = h3[1];
			dx2 = h3[2];
			// V
			ary00 = V[0]; ary01 = V[1]; ary02 = V[2];
			ary10 = V[3]; ary11 = V[4]; ary12 = V[5];
			ary20 = V[6]; ary21 = V[7]; ary22 = V[8];
		end
		default: begin
			dx0 = 0;
			dx1 = 0;
			dx2 = 0;
			ary00 = 0; ary01 = 0; ary02 = 0;
			ary10 = 0; ary11 = 0; ary12 = 0;
			ary20 = 0; ary21 = 0; ary22 = 0;
		end
	endcase
end

always @(*) begin
	// default---------
	n_Ux1[0] = Ux1[0];
	n_Ux1[1] = Ux1[1];
	n_Ux1[2] = Ux1[2];

	n_Ux2[0] = Ux2[0];
	n_Ux2[1] = Ux2[1];
	n_Ux2[2] = Ux2[2];

	n_Ux3[0] = Ux3[0];
	n_Ux3[1] = Ux3[1];
	n_Ux3[2] = Ux3[2];

	n_Wh1[0] = Wh1[0];
	n_Wh1[1] = Wh1[1];
	n_Wh1[2] = Wh1[2];

	n_Wh2[0] = Wh2[0];
	n_Wh2[1] = Wh2[1];
	n_Wh2[2] = Wh2[2];

	n_Vh1[0] = Vh1[0];
	n_Vh1[1] = Vh1[1];
	n_Vh1[2] = Vh1[2];

	n_Vh2[0] = Vh2[0];
	n_Vh2[1] = Vh2[1];
	n_Vh2[2] = Vh2[2];

	n_Vh3[0] = Vh3[0];
	n_Vh3[1] = Vh3[1];
	n_Vh3[2] = Vh3[2];
	// ----------------
	case (cnt)
		0: begin
			n_Ux1[0] = out0;
			n_Ux1[1] = out1;
			n_Ux1[2] = out2;
		end 
		1: begin
			n_Ux2[0] = out0;
			n_Ux2[1] = out1;
			n_Ux2[2] = out2;
		end
		2: begin
			// y1
			n_Vh1[0] = out0;
			n_Vh1[1] = out1;
			n_Vh1[2] = out2;
		end
		3: begin
			n_Wh1[0] = out0;
			n_Wh1[1] = out1;
			n_Wh1[2] = out2;
		end
		4: begin
			n_Ux3[0] = out0;
			n_Ux3[1] = out1;
			n_Ux3[2] = out2;
		end
		5: begin
			// y2
			n_Vh2[0] = out0;
			n_Vh2[1] = out1;
			n_Vh2[2] = out2;
		end
		6: begin
			n_Wh2[0] = out0;
			n_Wh2[1] = out1;
			n_Wh2[2] = out2;
		end
		8: begin
			// y3
			n_Vh3[0] = out0;
			n_Vh3[1] = out1;
			n_Vh3[2] = out2;
		end
	endcase
end


// calculation for h
assign IEEE_0 = {1'b0, 8'd0, 23'd0};

always @(*) begin
	n_h1[0] = (cnt == 1) ? hout0 : h1[0];
	n_h1[1] = (cnt == 1) ? hout1 : h1[1];
	n_h1[2] = (cnt == 1) ? hout2 : h1[2];

	n_h2[0] = (cnt == 4) ? hout0 : h2[0];
	n_h2[1] = (cnt == 4) ? hout1 : h2[1];
	n_h2[2] = (cnt == 4) ? hout2 : h2[2];

	n_h3[0] = (cnt == 7) ? hout0 : h3[0];
	n_h3[1] = (cnt == 7) ? hout1 : h3[1];
	n_h3[2] = (cnt == 7) ? hout2 : h3[2];
end

always @(*) begin
	if (cnt == 1) begin
		sel00 = IEEE_0;
		sel01 = IEEE_0;
		sel02 = IEEE_0;

		sel10 = Ux1[0];
		sel11 = Ux1[1];
		sel12 = Ux1[2];
	end
	else if (cnt == 4) begin
		sel00 = Wh1[0];
		sel01 = Wh1[1];
		sel02 = Wh1[2];

		sel10 = Ux2[0];
		sel11 = Ux2[1];
		sel12 = Ux2[2];
	end
	else if (cnt == 7) begin // need to check whether it can be removed
		sel00 = Wh2[0];
		sel01 = Wh2[1];
		sel02 = Wh2[2];

		sel10 = Ux3[0];
		sel11 = Ux3[1];
		sel12 = Ux3[2];
	end
	else begin
		sel00 = Wh2[0];
		sel01 = Wh2[1];
		sel02 = Wh2[2];

		sel10 = Ux3[0];
		sel11 = Ux3[1];
		sel12 = Ux3[2];
	end
end

// mutmul output FF h0, h1, h2, ux0, ux1, ux2, hw0, hw1, hw2
generate
for (i=0 ; i<=2 ; i=i+1) begin
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			Ux1[i] <= 0;
			Ux2[i] <= 0;
			Ux3[i] <= 0;

			h1[i] <= 0;
			h2[i] <= 0;
			h3[i] <= 0;

			Wh1[i] <= 0;
			Wh2[i] <= 0;

			Vh1[i] <= 0;
			Vh2[i] <= 0;
			Vh3[i] <= 0;
		end
		else begin
			Ux1[i] <= n_Ux1[i];
			Ux2[i] <= n_Ux2[i];
			Ux3[i] <= n_Ux3[i];

			h1[i] <= n_h1[i];
			h2[i] <= n_h2[i];
			h3[i] <= n_h3[i];

			Wh1[i] <= n_Wh1[i];
			Wh2[i] <= n_Wh2[i];

			Vh1[i] <= n_Vh1[i];
			Vh2[i] <= n_Vh2[i];
			Vh3[i] <= n_Vh3[i];
		end
	end
end
endgenerate


// select relu input
always @(*) begin
	case (cnt)
		2, 5, 8: rin = out0;

		3: rin = Vh1[1];
		4: rin = Vh1[2];

		6: rin = Vh2[1];
		7: rin = Vh2[2];

		9: rin = Vh3[1];
		10: rin = Vh3[2];

		default: rin = 32'd0; 
	endcase
end


// output
always @(*) begin
	n_out_valid = (cnt >= 2 && cnt <= 10) ? 1 : 0;
	n_out = (cnt >= 2 && cnt <= 10) ? rout : 0;
end

always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		out_valid 	<= 0;
		out 		<= 0;
	end
	else begin
		out_valid 	<= n_out_valid;
		out			<= n_out;
	end
end

endmodule


// self defined IP
module SIGMOID (
	in, out
);

// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

// input & output ports
input [inst_sig_width+inst_exp_width:0] in;
output wire [inst_sig_width+inst_exp_width:0] out;

wire [inst_sig_width+inst_exp_width:0] minus_in;
wire [inst_sig_width+inst_exp_width:0] exp_minus_x;
wire [7:0] status_exp_nc, status_add_nc, status_rec_nc;

wire [inst_sig_width+inst_exp_width:0] IEEE_one;
wire [inst_sig_width+inst_exp_width:0] denominator;

assign minus_in = {!in[31], in[30:0]};
assign IEEE_one = {1'b0, 8'd127, 23'd0};

// DW
DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) EXP0 (.a(minus_in), .z(exp_minus_x), .status(status_exp_nc));
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) DEN (.a(IEEE_one), .b(exp_minus_x), .z(denominator), .status(status_add_nc), .rnd(3'b000));
DW_fp_recip REC (.a(denominator), .rnd(3'b000), .z(out), .status(status_rec_nc));

endmodule


module MATMUL (
	dx0, dx1, dx2, ary00, ary01, ary02, ary03, ary10, ary11, ary12, ary20, ary21, ary22, out0, out1, out2
);

// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 0;
	
// input & output ports
input [inst_sig_width+inst_exp_width:0] dx0, dx1, dx2, ary00, ary01, ary02, ary03, ary10, ary11, ary12, ary20, ary21, ary22;
output wire [inst_sig_width+inst_exp_width:0] out0, out1, out2;

wire [7:0] status0_nc, status1_nc, status2_nc;

// DW
DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) DP0 (
	.a(ary00), .b(dx0), .c(ary01), .d(dx1), .e(ary02), .f(dx2), .rnd(3'b000), .z(out0), .status(status0_nc)
);
DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) DP1 (
	.a(ary10), .b(dx0), .c(ary11), .d(dx1), .e(ary12), .f(dx2), .rnd(3'b000), .z(out1), .status(status1_nc)
);
DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) DP2 (
	.a(ary20), .b(dx0), .c(ary21), .d(dx1), .e(ary22), .f(dx2), .rnd(3'b000), .z(out2), .status(status2_nc)
);

endmodule

module ADD_SIGMOID (
	ux0, ux1, ux2, 
	wh0, wh1, wh2,
	out0, out1, out2
);

// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 0;
	
// input & output ports
input [inst_sig_width+inst_exp_width:0] ux0, ux1, ux2, wh0, wh1, wh2;
output wire [inst_sig_width+inst_exp_width:0] out0, out1, out2;

wire [7:0] status0_nc, status1_nc, status2_nc;
wire [inst_sig_width+inst_exp_width:0] a0, a1, a2;

// DW add
DW_fp_add ADD0 (.a(ux0), .b(wh0), .rnd(3'b000), .z(a0), .status(status0_nc));
DW_fp_add ADD1 (.a(ux1), .b(wh1), .rnd(3'b000), .z(a1), .status(status1_nc));
DW_fp_add ADD2 (.a(ux2), .b(wh2), .rnd(3'b000), .z(a2), .status(status2_nc));

// SIGMOID
SIGMOID S0 (.in(a0), .out(out0));
SIGMOID S1 (.in(a1), .out(out1));
SIGMOID S2 (.in(a2), .out(out2));

	
endmodule


module ReLU (
	in, out
);

// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;

// input & output ports
input [inst_sig_width+inst_exp_width:0] in;
output wire [inst_sig_width+inst_exp_width:0] out;

assign out = (in[31] == 1'b0) ? in : 32'd0;
	
endmodule
	