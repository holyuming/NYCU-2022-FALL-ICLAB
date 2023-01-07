// synopsys translate_off 
`ifdef RTL
`include "GATED_OR.v"
`else
`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on

module SP(
	// Input signals
	clk,
	rst_n,
	cg_en,
	in_valid,
	in_data,
	in_mode,
	// Output signals
	out_valid,
	out_data
);

// INPUT AND OUTPUT DECLARATION  
input		clk;
input		rst_n;
input		in_valid;
input		cg_en;
input [8:0] in_data;
input [2:0] in_mode;

output reg 		  out_valid;
output reg signed[9:0] out_data;

// params
genvar m, n, l;
integer i, j, k;

localparam 	S_IDLE = 0,
			S_READ = 1,
			S_GRAY = 2,
			S_CAL = 3,
			S_ADDSUB = 4,
			S_MA = 5,
			S_GIVE = 6,
			S_SORT = 7,
			S_OUT = 8;

// declarations

// sleep controler
wire clk_counter, clk_mode, clk_compare, clk_addsub, clk_newseries, clk_out;
reg counter_sleep_ctrl, mode_sleep_ctrl, compare_sleep_ctrl, addsub_sleep_ctrl, newseries_sleep_ctrl, out_sleep_ctrl;

// gated clock
GATED_OR GATED_counter (.CLOCK(clk), .SLEEP_CTRL(counter_sleep_ctrl), .RST_N(rst_n), .CLOCK_GATED(clk_counter));
GATED_OR GATED_mode (.CLOCK(clk), .SLEEP_CTRL(mode_sleep_ctrl), .RST_N(rst_n), .CLOCK_GATED(clk_mode));
GATED_OR GATED_compare (.CLOCK(clk), .SLEEP_CTRL(compare_sleep_ctrl), .RST_N(rst_n), .CLOCK_GATED(clk_compare));
GATED_OR GATED_addsub (.CLOCK(clk), .SLEEP_CTRL(addsub_sleep_ctrl), .RST_N(rst_n), .CLOCK_GATED(clk_addsub));
GATED_OR GATED_newseries (.CLOCK(clk), .SLEEP_CTRL(newseries_sleep_ctrl), .RST_N(rst_n), .CLOCK_GATED(clk_newseries));
GATED_OR GATED_out (.CLOCK(clk), .SLEEP_CTRL(out_sleep_ctrl), .RST_N(rst_n), .CLOCK_GATED(clk_out));

// fsm
reg [3:0] c_state, n_state;

// counter
reg [3:0] counter, n_counter;

// data array
reg signed [8:0] data [0:8], n_data [0:8];

// input
reg [2:0] mode, n_mode;

// add & sub 's maximum, minimum, half of diff, midpoint
reg signed [8:0] maximum, minimum, half_diff, midpoint;
reg signed [8:0] n_maximum, n_minimum, n_half_diff, n_midpoint;
reg signed [8:0] Max0 [0:3], Max1 [0:1], Max2;
reg signed [8:0] Min0 [0:3], Min1 [0:1], Min2;

// moving average
reg signed [8:0] new_series [0:8], n_new_series [0:8];
reg signed [8:0] value;

// MMM
reg signed [9:0] max, median, min;

// output
reg [9:0] n_out_data;
reg n_out_valid;


// design
// sleep controller
always @(*) begin
	if (cg_en == 0) begin
		counter_sleep_ctrl = 0;
		mode_sleep_ctrl = 0;
		compare_sleep_ctrl = 0;
		addsub_sleep_ctrl = 0;
		newseries_sleep_ctrl = 0;
		out_sleep_ctrl = 0;
	end else begin
		counter_sleep_ctrl = (	c_state == S_IDLE || 
								c_state == S_READ ||
								c_state == S_GRAY ||
								c_state == S_ADDSUB ||
								c_state == S_GIVE) ? 1 : 0;
		mode_sleep_ctrl = (c_state != S_IDLE) ? 1 : 0;
		compare_sleep_ctrl = (c_state != S_CAL) ? 1 : 0;
		addsub_sleep_ctrl = (n_state != S_ADDSUB) ? 1 : 0;
		newseries_sleep_ctrl = (c_state != S_MA) ? 1 : 0;
		out_sleep_ctrl = (c_state != S_OUT && c_state != S_IDLE) ? 1 : 0;
	end
end


// fsm
always@(*) begin
	case(c_state)
		S_IDLE	: n_state = (in_valid == 1) ? S_READ : S_IDLE;
		S_READ	: n_state = (in_valid == 1) ? S_READ : S_GRAY;

		S_GRAY	: n_state = S_CAL;

		S_CAL	: n_state = (counter == 4) ? S_ADDSUB : S_CAL;
		S_ADDSUB: n_state = (mode[2] == 1) ? S_MA : S_SORT;

		S_MA	: n_state = (counter == 8) ? S_GIVE : S_MA;
		S_GIVE	: n_state = S_SORT;
		
		S_SORT	: n_state = (counter == 8) ? S_OUT : S_SORT;
		S_OUT	: n_state = (counter == 3) ? S_IDLE : S_OUT;

		default	: n_state = S_IDLE;
	endcase
end
always@(posedge clk or negedge rst_n) begin
	if (!rst_n) 	c_state <= S_IDLE;
	else			c_state	<= n_state;
end

// counter
always @(*) begin
	case (c_state)
		S_CAL,
		S_SORT,
		S_MA,
		S_OUT	: n_counter = (n_state != c_state) ? 0 : counter + 1;
		default	: n_counter = 0;
	endcase
end
always @(posedge clk_counter or negedge rst_n) begin
	if (!rst_n)	counter <= 0;
	else		counter <= n_counter;
end


// read input

// data
always@(*) begin	
	// defalt
	for (i=0 ; i<8 ; i=i+1) begin
		n_data[i] = (in_valid == 1) ? data[i+1] : data[i];
	end
	n_data[8] = (in_valid == 1) ? in_data : data[8];
	
	case(c_state)
		S_GRAY	: begin
			n_data[0] = (mode[0] == 1) ? GRAY_CODE[0].result : data[0];
			n_data[1] = (mode[0] == 1) ? GRAY_CODE[1].result : data[1];
			n_data[2] = (mode[0] == 1) ? GRAY_CODE[2].result : data[2];
			n_data[3] = (mode[0] == 1) ? GRAY_CODE[3].result : data[3];
			n_data[4] = (mode[0] == 1) ? GRAY_CODE[4].result : data[4];
			n_data[5] = (mode[0] == 1) ? GRAY_CODE[5].result : data[5];
			n_data[6] = (mode[0] == 1) ? GRAY_CODE[6].result : data[6];
			n_data[7] = (mode[0] == 1) ? GRAY_CODE[7].result : data[7];
			n_data[8] = (mode[0] == 1) ? GRAY_CODE[8].result : data[8];
		end
		S_SORT	: begin
			if (counter[0] == 0) begin
				n_data[0] = (data[0] < data[1]) ? data[0] : data[1];
				n_data[1] = (data[0] < data[1]) ? data[1] : data[0];
				n_data[2] = (data[2] < data[3]) ? data[2] : data[3];
				n_data[3] = (data[2] < data[3]) ? data[3] : data[2];
				n_data[4] = (data[4] < data[5]) ? data[4] : data[5];
				n_data[5] = (data[4] < data[5]) ? data[5] : data[4];
				n_data[6] = (data[6] < data[7]) ? data[6] : data[7];
				n_data[7] = (data[6] < data[7]) ? data[7] : data[6];
				n_data[8] = data[8];
			end else begin
				n_data[0] = data[0];
				n_data[1] = (data[1] < data[2]) ? data[1] : data[2];
				n_data[2] = (data[1] < data[2]) ? data[2] : data[1];
				n_data[3] = (data[3] < data[4]) ? data[3] : data[4];
				n_data[4] = (data[3] < data[4]) ? data[4] : data[3];
				n_data[5] = (data[5] < data[6]) ? data[5] : data[6];
				n_data[6] = (data[5] < data[6]) ? data[6] : data[5];
				n_data[7] = (data[7] < data[8]) ? data[7] : data[8];
				n_data[8] = (data[7] < data[8]) ? data[8] : data[7];
			end
		end
		S_ADDSUB: begin
			for (i=0 ; i<9 ; i=i+1) begin
				if 		(data[i] < midpoint) n_data[i] = (mode[1] == 1) ? data[i] + half_diff : data[i];
				else if (data[i] > midpoint) n_data[i] = (mode[1] == 1) ? data[i] - half_diff : data[i];
				else						 n_data[i] = data[i];
			end
		end
		S_MA	: begin
			for (i=0 ; i<8 ; i=i+1) begin
				n_data[i] = data[i+1];
			end
			n_data[8] = data[0];
		end
		S_GIVE	: begin
			for (i=0 ; i<9 ; i=i+1) begin
				n_data[i] = new_series[i];	
			end
		end
	endcase
end
generate 
for (m=0 ; m<9 ; m=m+1) begin : DATA
	always@(posedge clk or negedge rst_n) begin
		if (!rst_n) data[m] <= 0;
		else		data[m] <= n_data[m];
	end
end
endgenerate


// mode
always@(*) begin
	n_mode = (c_state == S_IDLE && in_valid == 1) ? in_mode : mode;
end
always@(posedge clk_mode or negedge rst_n) begin
	if (!rst_n)		mode <= 0;
	else			mode <= n_mode;
end


// calculations 
// gray code
generate
for (m=0 ; m<9 ; m=m+1) begin : GRAY_CODE
	reg out [8:0];
	reg [7:0] num;
	reg [8:0] result;

	always@(*) begin
		out[8] = data[m][8];
		out[7] = data[m][7];
		out[6] = out[7] ^ data[m][6];
		out[5] = out[6] ^ data[m][5];
		out[4] = out[5] ^ data[m][4];
		out[3] = out[4] ^ data[m][3];
		out[2] = out[3] ^ data[m][2];
		out[1] = out[2] ^ data[m][1];
		out[0] = out[1] ^ data[m][0];

		num = {out[7], out[6], out[5], out[4], out[3], out[2], out[1], out[0]};

		result = (out[8] == 1) ? {out[8], ~num + 1} : {out[8], num};
	end	
end
endgenerate


// add & sub 's maximum, minimum, half of diff, midpoint
always @(posedge clk_compare or negedge rst_n) begin
	if (!rst_n) begin
		Max0[0] <= 0;
		Max0[1] <= 0;
		Max0[2] <= 0;
		Max0[3] <= 0;

		Max1[0] <= 0;
		Max1[1] <= 0;

		Max2 <= 0;
	end else begin
		Max0[0] <= (data[0] > data[1]) ? data[0] : data[1];
		Max0[1] <= (data[2] > data[3]) ? data[2] : data[3];
		Max0[2] <= (data[4] > data[5]) ? data[4] : data[5];
		Max0[3] <= (data[6] > data[7]) ? data[6] : data[7];

		Max1[0] <= (Max0[0] > Max0[1]) ? Max0[0] : Max0[1];
		Max1[1] <= (Max0[2] > Max0[3]) ? Max0[2] : Max0[3];

		Max2 <= (Max1[0] > Max1[1]) ? Max1[0] : Max1[1];
	end
end
always @(posedge clk_compare or negedge rst_n) begin
	if (!rst_n) begin
		Min0[0] <= 0;
		Min0[1] <= 0;
		Min0[2] <= 0;
		Min0[3] <= 0;

		Min1[0] <= 0;
		Min1[1] <= 0;

		Min2 <= 0;
	end else begin
		Min0[0] <= (data[0] < data[1]) ? data[0] : data[1];
		Min0[1] <= (data[2] < data[3]) ? data[2] : data[3];
		Min0[2] <= (data[4] < data[5]) ? data[4] : data[5];
		Min0[3] <= (data[6] < data[7]) ? data[6] : data[7];

		Min1[0] <= (Min0[0] < Min0[1]) ? Min0[0] : Min0[1];
		Min1[1] <= (Min0[2] < Min0[3]) ? Min0[2] : Min0[3];

		Min2 <= (Min1[0] < Min1[1]) ? Min1[0] : Min1[1];
	end
end
always @(*) begin
	if (n_state == S_ADDSUB && c_state != S_ADDSUB) begin
		n_maximum = (Max2 > data[8]) ? Max2 : data[8]; 
		n_minimum = (Min2 < data[8]) ? Min2 : data[8];
		n_midpoint 	= (n_maximum + n_minimum) / 2;
		n_half_diff = (n_maximum - n_minimum) / 2;
	end else begin
		n_maximum 	= maximum;
		n_minimum 	= minimum;
		n_midpoint 	= midpoint;
		n_half_diff	= half_diff;
	end
end
always @(posedge clk_addsub or negedge rst_n) begin
	if (!rst_n) begin
		maximum 	<= 0;
		minimum 	<= 0;
		midpoint 	<= 0;
		half_diff 	<= 0;
	end else begin
		maximum 	<= n_maximum;
		midpoint 	<= n_midpoint;
		half_diff 	<= n_half_diff;
		minimum 	<= n_minimum;
	end
end


// moving average
always @(*) begin
	value = (data[8] + data[0] + data[1]) / 3;
end

always @(*) begin
	if (c_state == S_MA) begin
		for (i=0 ; i<8 ; i=i+1) begin
			n_new_series[i] = new_series[i+1];
		end
		n_new_series[8] = value;
	end else begin
		for (i=0 ; i<9 ; i=i+1) begin
			n_new_series[i] = new_series[i];
		end
	end
end

always @(posedge clk_newseries or negedge rst_n) begin
	if (!rst_n) begin
		for (i=0 ; i<9 ; i=i+1) begin
			new_series[i] <= 0;
		end
	end
	else begin
		for (i=0 ; i<9 ; i=i+1) begin
			new_series[i] <= n_new_series[i];
		end
	end
end


// MMM
always @(*) begin
	max 	= data[8];
	median 	= data[4];
	min 	= data[0];
end

// output 
always@(*) begin
	n_out_valid = (counter == 1 || counter == 2 || counter == 3) && c_state == S_OUT ? 1 : 0;

	if (n_out_valid == 1) begin
		case (counter)
			1 : n_out_data = max;
			2 : n_out_data = median;
			3 : n_out_data = min;
			default: n_out_data = 0; 
		endcase	
	end
	else	n_out_data = 0;
end
always@(posedge clk_out or negedge rst_n) begin
	if (!rst_n) begin
		out_valid 	<= 0;
		out_data 	<= 0;
	end else begin
		out_valid 	<= n_out_valid;
		out_data	<= n_out_data;
	end
end


endmodule