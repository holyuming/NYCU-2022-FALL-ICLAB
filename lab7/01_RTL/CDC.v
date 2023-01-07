`include "synchronizer.v"
`include "syn_XOR.v"
module CDC(
	//Input Port
	clk1,
    clk2,
    clk3,
	rst_n,
	in_valid1,
	in_valid2,
	user1,
	user2,

    //Output Port
    out_valid1,
    out_valid2,
	equal,
	exceed,
	winner
); 
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input 		clk1, clk2, clk3, rst_n;
input 		in_valid1, in_valid2;
input [3:0]	user1, user2;

output reg	out_valid1, out_valid2;
output reg	equal, exceed, winner;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
//----clk1----
reg [5:0] cdf_table [0:10], n_cdf_table [0:10];		// no.0 will be removed since it's not used
reg [3:0] card;
reg [3:0] card_value;
reg signed [5:0] u1_remain, u2_remain, n_u1_remain, n_u2_remain;
reg [3:0] counter, n_counter;
reg [7:0] u1_prob21, u1_prob_exceed, n_u1_prob21, n_u1_prob_exceed;
reg [7:0] u2_prob21, u2_prob_exceed, n_u2_prob21, n_u2_prob_exceed;
reg IN3, IN4, IN5;
reg [2:0] epoch;
reg clk1_c_state, clk1_n_state;
reg [1:0] cal_winner, n_cal_winner;

// operand selection
// prob exceed
reg [5:0] u1_minus_sel;
reg [5:0] u1_multiply_sel;
reg [13:0] u1_numerator;
reg [7:0] u1_div_ans;
reg [5:0] u2_minus_sel;
reg [5:0] u2_multiply_sel;
reg [13:0] u2_numerator;
reg [7:0] u2_div_ans;
// prob 21
reg [5:0] u1_prob21_minus_sel0, u1_prob21_minus_sel1;
reg [5:0] u2_prob21_minus_sel0, u2_prob21_minus_sel1;
reg [13:0] u1_prob21_numerator, u2_prob21_numerator;
reg [7:0] u1_prob21_div_ans, u2_prob21_div_ans;

//----clk2----

//----clk3----
wire OUT3, OUT4, OUT5;
reg n_out_valid1, n_out_valid2;
reg n_equal, n_exceed, n_winner;
reg [7:0] clk3_u1_prob21, clk3_u1_prob_exceed, n_clk3_u1_prob21, n_clk3_u1_prob_exceed;
reg [7:0] clk3_u2_prob21, clk3_u2_prob_exceed, n_clk3_u2_prob21, n_clk3_u2_prob_exceed;
reg [2:0] out_valid1_cnt, n_out_valid1_cnt;
reg [1:0] out_valid2_cnt, n_out_valid2_cnt;
reg [2:0] clk3_c_state, clk3_n_state;
reg [1:0] clk3_winner, n_clk3_winner;

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
integer i, j, k;
genvar m, n, l;
//----clk1----
localparam 	S1_IDLE = 0,
			S1_CAL = 1;

//----clk2----

//----clk3----
localparam 	S3_U1 = 0,
			S3_U2 = 1,
			S3_WINNER = 2,
			S3_IDLE = 3;

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
//============================================
//   clk1 domain
//============================================
// fsm
always @(*) begin
	case (clk1_c_state)
		S1_IDLE	: clk1_n_state = (in_valid1 == 1 || in_valid2 == 1) ? S1_CAL : S1_IDLE;
		S1_CAL	: clk1_n_state = (in_valid1 == 0 && in_valid2 == 0) ? S1_IDLE : S1_CAL; 
		default	: clk1_n_state = S1_IDLE;
	endcase
end
always @(posedge clk1 or negedge rst_n) begin
	if (!rst_n)	clk1_c_state <= S1_IDLE;
	else		clk1_c_state <= clk1_n_state;
end

// epoch
always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n) begin
		epoch <= 0;
	end else begin
		epoch <= (epoch == 5) ? 0 : (counter == 9) ? epoch + 1 : epoch;
	end
end

// counter
always @(*) begin
	n_counter = (counter == 9) ? 0 : (in_valid1 == 1 || in_valid2 == 1) ? counter + 1 : counter;
end
always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n) begin
		counter <= 0;
	end else begin
		counter <= n_counter;
	end
end

// remain
always @(*) begin
	if (counter == 0) 	n_u1_remain = 21 - card_value;
	else				n_u1_remain = (in_valid1 == 1) ? u1_remain - card_value : u1_remain;
end
always @(*) begin
	if (counter == 5) 	n_u2_remain = 21 - card_value;
	else				n_u2_remain = (in_valid2 == 1) ? u2_remain - card_value : u2_remain;
end
always @(posedge clk1 or negedge rst_n) begin
	if (!rst_n) begin
		u1_remain <= 21;
		u2_remain <= 21;
	end else begin
		u1_remain <= n_u1_remain;
		u2_remain <= n_u2_remain;
	end
end

// card
always@(*) begin
	if 		(in_valid1 == 1) card = user1;
	else if (in_valid2 == 1) card = user2;
	else					 card = 0;
end

// card value
always @(*) begin
	case (card)
		1, 11, 12, 13: card_value = 1;
		2	: card_value = 2;
		3	: card_value = 3;  
		4	: card_value = 4;  
		5	: card_value = 5;  
		6	: card_value = 6;  
		7	: card_value = 7;  
		8	: card_value = 8;  
		9	: card_value = 9;  
		10	: card_value = 10;  
		default: card_value = 0;
	endcase
end

// cdf table
always @(*) begin

	// default
	for (i=1 ; i<=10 ; i=i+1) begin
		n_cdf_table[i] = cdf_table[i];
	end


	// reset
	if (counter == 9 && epoch == 4) begin
		n_cdf_table[1]  = 16;
		n_cdf_table[2]  = 20;
		n_cdf_table[3]  = 24;
		n_cdf_table[4]  = 28;
		n_cdf_table[5]  = 32;
		n_cdf_table[6]  = 36;
		n_cdf_table[7]  = 40;
		n_cdf_table[8]  = 44;
		n_cdf_table[9]  = 48;
		n_cdf_table[10] = 52;
	end 

	// subtract
	else if (in_valid1 == 1 || in_valid2 == 1) begin
		case (card)
			1, 11, 12, 13: begin
				for (i=1 ; i<=10 ; i=i+1) begin
					n_cdf_table[i] = cdf_table[i] - 1;
				end
			end 
			2: begin
				for (i=2 ; i<=10 ; i=i+1) begin
					n_cdf_table[i] = cdf_table[i] - 1;
				end
			end
			3: begin
				for (i=3 ; i<=10 ; i=i+1) begin
					n_cdf_table[i] = cdf_table[i] - 1;
				end
			end
			4: begin
				for (i=4 ; i<=10 ; i=i+1) begin
					n_cdf_table[i] = cdf_table[i] - 1;
				end
			end
			5: begin
				for (i=5 ; i<=10 ; i=i+1) begin
					n_cdf_table[i] = cdf_table[i] - 1;
				end
			end
			6: begin
				for (i=6 ; i<=10 ; i=i+1) begin
					n_cdf_table[i] = cdf_table[i] - 1;
				end
			end
			7: begin
				for (i=7 ; i<=10 ; i=i+1) begin
					n_cdf_table[i] = cdf_table[i] - 1;
				end
			end
			8: begin
				for (i=8 ; i<=10 ; i=i+1) begin
					n_cdf_table[i] = cdf_table[i] - 1;
				end
			end
			9: begin
				for (i=9 ; i<=10 ; i=i+1) begin
					n_cdf_table[i] = cdf_table[i] - 1;
				end
			end
			10 : n_cdf_table[10] = cdf_table[10] - 1;
		endcase
	end
end
always @(posedge clk1 or negedge rst_n) begin
	if (!rst_n) begin
		cdf_table[0]  <= 0;
		cdf_table[1]  <= 16;
		cdf_table[2]  <= 20;
		cdf_table[3]  <= 24;
		cdf_table[4]  <= 28;
		cdf_table[5]  <= 32;
		cdf_table[6]  <= 36;
		cdf_table[7]  <= 40;
		cdf_table[8]  <= 44;
		cdf_table[9]  <= 48;
		cdf_table[10] <= 52;
	end else begin
		cdf_table[0]  <= 0;
		for (i=1 ; i<=10 ; i=i+1) begin
			cdf_table[i] <= n_cdf_table[i];
		end
	end
end


// u1 prob exceed
always @(*) begin
	case (u1_remain)
		1		: u1_minus_sel = cdf_table[1];
		2		: u1_minus_sel = cdf_table[2];
		3		: u1_minus_sel = cdf_table[3];
		4		: u1_minus_sel = cdf_table[4];
		5		: u1_minus_sel = cdf_table[5];
		6		: u1_minus_sel = cdf_table[6];
		7		: u1_minus_sel = cdf_table[7];
		8		: u1_minus_sel = cdf_table[8];
		9		: u1_minus_sel = cdf_table[9];
		default	: u1_minus_sel = cdf_table[10];
	endcase
end
always @(*) begin
	u1_multiply_sel = cdf_table[10] - u1_minus_sel;
	u1_numerator 	= u1_multiply_sel * 100;
	u1_div_ans		= u1_numerator / cdf_table[10];
end
always @(*) begin
	if 		(u1_remain >= 10) 	n_u1_prob_exceed = 0;
	else if (u1_remain <= 0)	n_u1_prob_exceed = 100;
	else 						n_u1_prob_exceed = u1_div_ans;
end
always @(posedge clk1 or negedge rst_n) begin
	if (!rst_n)	u1_prob_exceed <= 0;
	else		u1_prob_exceed <= n_u1_prob_exceed;
end


// u1 prob 21
always @(*) begin
	case (u1_remain)
		1	: u1_prob21_minus_sel0 = cdf_table[1];
		2	: u1_prob21_minus_sel0 = cdf_table[2];
		3	: u1_prob21_minus_sel0 = cdf_table[3];
		4	: u1_prob21_minus_sel0 = cdf_table[4];
		5	: u1_prob21_minus_sel0 = cdf_table[5];
		6	: u1_prob21_minus_sel0 = cdf_table[6];
		7	: u1_prob21_minus_sel0 = cdf_table[7];
		8	: u1_prob21_minus_sel0 = cdf_table[8];
		9	: u1_prob21_minus_sel0 = cdf_table[9];
		10	: u1_prob21_minus_sel0 = cdf_table[10];
		default: u1_prob21_minus_sel0 = 0;
	endcase
end
always @(*) begin
	case (u1_remain)
		1	: u1_prob21_minus_sel1 = 0;
		2	: u1_prob21_minus_sel1 = cdf_table[1];
		3	: u1_prob21_minus_sel1 = cdf_table[2];
		4	: u1_prob21_minus_sel1 = cdf_table[3];
		5	: u1_prob21_minus_sel1 = cdf_table[4];
		6	: u1_prob21_minus_sel1 = cdf_table[5];
		7	: u1_prob21_minus_sel1 = cdf_table[6];
		8	: u1_prob21_minus_sel1 = cdf_table[7];
		9	: u1_prob21_minus_sel1 = cdf_table[8];
		10	: u1_prob21_minus_sel1 = cdf_table[9];
		default: u1_prob21_minus_sel1 = 0;
	endcase
end
always @(*) begin
	u1_prob21_numerator = (u1_prob21_minus_sel0 - u1_prob21_minus_sel1) * 100;
	u1_prob21_div_ans 	= u1_prob21_numerator / cdf_table[10];
end

always @(*) begin
	if 		(u1_remain <= 0 || u1_remain > 10) 	n_u1_prob21 = 0;
	else										n_u1_prob21 = u1_prob21_div_ans;
end
always @(posedge clk1 or negedge rst_n) begin
	if (!rst_n)	u1_prob21 <= 0;
	else		u1_prob21 <= n_u1_prob21;
end


// u2 prob exceed
always @(*) begin
	case (u2_remain)
		1		: u2_minus_sel = cdf_table[1];
		2		: u2_minus_sel = cdf_table[2];
		3		: u2_minus_sel = cdf_table[3];
		4		: u2_minus_sel = cdf_table[4];
		5		: u2_minus_sel = cdf_table[5];
		6		: u2_minus_sel = cdf_table[6];
		7		: u2_minus_sel = cdf_table[7];
		8		: u2_minus_sel = cdf_table[8];
		9		: u2_minus_sel = cdf_table[9];
		default	: u2_minus_sel = cdf_table[10];
	endcase
end
always @(*) begin
	u2_multiply_sel = cdf_table[10] - u2_minus_sel;
	u2_numerator 	= u2_multiply_sel * 100;
	u2_div_ans		= u2_numerator / cdf_table[10];
end
always @(*) begin
	if 		(u2_remain >= 10) 	n_u2_prob_exceed = 0;
	else if (u2_remain <= 0)	n_u2_prob_exceed = 100;
	else 						n_u2_prob_exceed = u2_div_ans;
end
always @(posedge clk1 or negedge rst_n) begin
	if (!rst_n)	u2_prob_exceed <= 0;
	else		u2_prob_exceed <= n_u2_prob_exceed;
end


// u2 prob 21
always @(*) begin
	case (u2_remain)
		1	: u2_prob21_minus_sel0 = cdf_table[1];
		2	: u2_prob21_minus_sel0 = cdf_table[2];
		3	: u2_prob21_minus_sel0 = cdf_table[3];
		4	: u2_prob21_minus_sel0 = cdf_table[4];
		5	: u2_prob21_minus_sel0 = cdf_table[5];
		6	: u2_prob21_minus_sel0 = cdf_table[6];
		7	: u2_prob21_minus_sel0 = cdf_table[7];
		8	: u2_prob21_minus_sel0 = cdf_table[8];
		9	: u2_prob21_minus_sel0 = cdf_table[9];
		10	: u2_prob21_minus_sel0 = cdf_table[10];
		default: u2_prob21_minus_sel0 = 0;
	endcase
end
always @(*) begin
	case (u2_remain)
		1	: u2_prob21_minus_sel1 = 0;
		2	: u2_prob21_minus_sel1 = cdf_table[1];
		3	: u2_prob21_minus_sel1 = cdf_table[2];
		4	: u2_prob21_minus_sel1 = cdf_table[3];
		5	: u2_prob21_minus_sel1 = cdf_table[4];
		6	: u2_prob21_minus_sel1 = cdf_table[5];
		7	: u2_prob21_minus_sel1 = cdf_table[6];
		8	: u2_prob21_minus_sel1 = cdf_table[7];
		9	: u2_prob21_minus_sel1 = cdf_table[8];
		10	: u2_prob21_minus_sel1 = cdf_table[9];
		default: u2_prob21_minus_sel1 = 0;
	endcase
end
always @(*) begin
	u2_prob21_numerator = (u2_prob21_minus_sel0 - u2_prob21_minus_sel1) * 100;
	u2_prob21_div_ans 	= u2_prob21_numerator / cdf_table[10];
end
always @(*) begin
	if 		(u2_remain <= 0 || u2_remain > 10) 	n_u2_prob21 = 0;
	else										n_u2_prob21 = u2_prob21_div_ans;
end
always @(posedge clk1 or negedge rst_n) begin
	if (!rst_n)	u2_prob21 <= 0;
	else		u2_prob21 <= n_u2_prob21;
end


// cal winner
always @(*) begin
	// no winner
	if ((u1_remain <0 && u2_remain <0) || u1_remain == u2_remain)			n_cal_winner = 0;
	else if (u1_remain >= 0 && u2_remain < 0)								n_cal_winner = 1;
	else if (u1_remain < 0 && u2_remain >= 0)								n_cal_winner = 2;
	else begin
		if (u1_remain < u2_remain )	n_cal_winner = 1;
		else						n_cal_winner = 2;
	end
end
always @(posedge clk1 or negedge rst_n) begin
	if (!rst_n)	cal_winner <= 0;
	else		cal_winner <= n_cal_winner;
end


// IN
always @(*) begin
	IN3 = (counter == 3 || counter == 8) ? 1 : 0;
	IN4 = (counter == 4 || counter == 9) ? 1 : 0;
	IN5 = (counter == 0 && clk1_c_state == S1_CAL) ? 1 : 0;
end

//============================================
//   clk2 domain
//============================================
// NONE
//============================================
//   clk3 domain
//============================================
// fsm
always @(*) begin
	case (clk3_c_state)
		S3_IDLE : clk3_n_state = (OUT3 == 1) ? S3_U1 : S3_IDLE;
		S3_U1	: clk3_n_state = (OUT3 == 1) ? S3_U2 : S3_U1;
		S3_U2	: clk3_n_state = (OUT3 == 1) ? S3_U1 : S3_U2;
		default	: clk3_n_state = clk3_c_state; 
	endcase
end
always @(posedge clk3 or negedge rst_n) begin
	if (!rst_n)	clk3_c_state <= S3_IDLE;
	else		clk3_c_state <= clk3_n_state;
end


// out valid1 counter
always @(*) begin
	if (OUT3 == 1 || OUT4 == 1) begin
		n_out_valid1_cnt = 1;
	end
	else if (out_valid1_cnt == 0)
		n_out_valid1_cnt = 0;
	else	
		n_out_valid1_cnt = out_valid1_cnt + 1;
end
always @(posedge clk3 or negedge rst_n) begin
	if (!rst_n)	out_valid1_cnt <= 0;
	else		out_valid1_cnt <= n_out_valid1_cnt;
end


// out valid2 counter
always @(*) begin
	if (OUT5 == 1) begin
		n_out_valid2_cnt = 1;
	end 
	else if (out_valid2_cnt == 2 || out_valid2_cnt == 0)
		n_out_valid2_cnt = 0;
	else 
		n_out_valid2_cnt = out_valid2_cnt + 1;
end
always @(posedge clk3 or negedge rst_n) begin
	if (!rst_n)	out_valid2_cnt <= 0;
	else		out_valid2_cnt <= n_out_valid2_cnt;
end


// clk3 prob 21 & prob exceed
always @(*) begin

	if (out_valid1_cnt != 0) begin
		n_clk3_u1_prob21 = clk3_u1_prob21 << 1;
		n_clk3_u2_prob21 = clk3_u2_prob21 << 1;

		n_clk3_u1_prob_exceed = clk3_u1_prob_exceed << 1;
		n_clk3_u2_prob_exceed = clk3_u2_prob_exceed << 1;
	end
	else begin
		n_clk3_u1_prob21 = (OUT3 == 1 || OUT4 == 1) ? u1_prob21 : clk3_u1_prob21;
		n_clk3_u2_prob21 = (OUT3 == 1 || OUT4 == 1) ? u2_prob21 : clk3_u2_prob21;

		n_clk3_u1_prob_exceed = (OUT3 == 1 || OUT4 == 1) ? u1_prob_exceed : clk3_u1_prob_exceed;
		n_clk3_u2_prob_exceed = (OUT3 == 1 || OUT4 == 1) ? u2_prob_exceed : clk3_u2_prob_exceed;
	end
end


// clk3 winner 
always @(*) begin
	n_clk3_winner = (OUT5 == 1) ? cal_winner : clk3_winner; 
end


// clk3 domain ans FF
always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
		clk3_u1_prob21 <= 0;
		clk3_u2_prob21 <= 0;

		clk3_u1_prob_exceed <= 0;
		clk3_u2_prob_exceed <= 0;

		clk3_winner <= 0;
	end else begin
		clk3_u1_prob21 <= n_clk3_u1_prob21;
		clk3_u2_prob21 <= n_clk3_u2_prob21;

		clk3_u1_prob_exceed <= n_clk3_u1_prob_exceed;
		clk3_u2_prob_exceed <= n_clk3_u2_prob_exceed;

		clk3_winner <= n_clk3_winner;
	end
end


// output comb
always @(*) begin
	n_out_valid1 = (n_out_valid1_cnt != 0) ? 1 : 0;
end
always @(*) begin
	if (clk3_winner == 0)
		n_out_valid2 = (n_out_valid2_cnt == 1) ? 1 : 0;
	else
		n_out_valid2 = (n_out_valid2_cnt != 0) ? 1 : 0;
end
always @(*) begin
	case (n_clk3_winner)
		0		: n_winner = 0;
		1		: n_winner = (n_out_valid2_cnt == 1) ? 1 : 0;
		2		: n_winner = (n_out_valid2_cnt == 1 || n_out_valid2_cnt == 2) ? 1 : 0;
		default	: n_winner = 0; 
	endcase
end


// n_equal
always @(*) begin
	if (n_out_valid1_cnt != 0) begin
		case (clk3_n_state)
			S3_U1	: n_equal = n_clk3_u1_prob21[6]; 
			S3_U2	: n_equal = n_clk3_u2_prob21[6]; 
			default	: n_equal = 0;
		endcase
	end
	else 
		n_equal = 0;
end

// n_exceed
always @(*) begin
	if (n_out_valid1_cnt != 0) begin
		case (clk3_n_state)
			S3_U1	: n_exceed = n_clk3_u1_prob_exceed[6]; 
			S3_U2	: n_exceed = n_clk3_u2_prob_exceed[6]; 
			default	: n_exceed = 0;
		endcase
	end
	else 
		n_exceed = 0;
end

// output FF
always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
		out_valid1 	<= 0;
		out_valid2 	<= 0;
		equal		<= 0;
		exceed		<= 0;
		winner		<= 0;
	end else begin
		out_valid1 	<= n_out_valid1;
		out_valid2 	<= n_out_valid2;
		equal 		<= n_equal;
		exceed		<= n_exceed;
		winner		<= n_winner;
	end
end

//---------------------------------------------------------------------
//   syn_XOR
//---------------------------------------------------------------------
syn_XOR u_syn_XOR0 (.IN(IN3),.OUT(OUT3),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));
syn_XOR u_syn_XOR1 (.IN(IN4),.OUT(OUT4),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));
syn_XOR u_syn_XOR2 (.IN(IN5),.OUT(OUT5),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));


endmodule