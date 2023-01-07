module HD(
	code_word1,
	code_word2,
	out_n
);
input  [6:0] code_word1, code_word2;
output reg signed [5:0] out_n;


// declaraton
wire 	cw1_even1, cw1_even2, cw1_even3,
		cw2_even1, cw2_even2, cw2_even3;
wire [2:0] cw1_even, cw2_even;

reg [3:0] correct_code_word1, correct_code_word2;

reg [1:0] opt;
wire signed  [4:0] sel1, sel2;
reg signed [4:0] final_sel2;
reg signed cin;


// design

// parity check
assign cw1_even1 = code_word1[6] ^ code_word1[3] ^ code_word1[2] ^ code_word1[1];
assign cw1_even2 = code_word1[5] ^ code_word1[3] ^ code_word1[2] ^ code_word1[0];
assign cw1_even3 = code_word1[4] ^ code_word1[3] ^ code_word1[1] ^ code_word1[0];

assign cw2_even1 = code_word2[6] ^ code_word2[3] ^ code_word2[2] ^ code_word2[1];
assign cw2_even2 = code_word2[5] ^ code_word2[3] ^ code_word2[2] ^ code_word2[0];
assign cw2_even3 = code_word2[4] ^ code_word2[3] ^ code_word2[1] ^ code_word2[0];

assign cw1_even = {cw1_even1, cw1_even2, cw1_even3};
assign cw2_even = {cw2_even1, cw2_even2, cw2_even3};

// correct code word
always @(*) begin
	case (cw1_even)
		3'b011 : correct_code_word1 = {code_word1[6], code_word1[5], code_word1[4], code_word1[3], code_word1[2], code_word1[1], !code_word1[0]}; // x4 is wrong
		3'b101 : correct_code_word1 = {code_word1[6], code_word1[5], code_word1[4], code_word1[3], code_word1[2], !code_word1[1], code_word1[0]}; // x3 is wrong
		3'b110 : correct_code_word1 = {code_word1[6], code_word1[5], code_word1[4], code_word1[3], !code_word1[2], code_word1[1], code_word1[0]}; // x2 is wrong
		3'b111 : correct_code_word1 = {code_word1[6], code_word1[5], code_word1[4], !code_word1[3], code_word1[2], code_word1[1], code_word1[0]}; // x1 is wrong
		default: correct_code_word1 = code_word1;
	endcase
end

// error bit: opt
always @(*) begin
	case (cw1_even)
		3'b001 : opt[1] = code_word1[4];// p3 is wrong
		3'b010 : opt[1] = code_word1[5];// p2 is wrong
		3'b011 : opt[1] = code_word1[0];// x4 is wrong
		3'b100 : opt[1] = code_word1[6];// p1 is wrong
		3'b101 : opt[1] = code_word1[1];// x3 is wrong
		3'b110 : opt[1] = code_word1[2];// x2 is wrong
		3'b111 : opt[1] = code_word1[3];// x1 is wrong
		default: opt[1] = 0;
	endcase
end

always @(*) begin
	case (cw2_even)
		3'b011 : correct_code_word2 = {code_word2[6], code_word2[5], code_word2[4], code_word2[3], code_word2[2], code_word2[1], !code_word2[0]}; // x4 is wrong
		3'b101 : correct_code_word2 = {code_word2[6], code_word2[5], code_word2[4], code_word2[3], code_word2[2], !code_word2[1], code_word2[0]}; // x3 is wrong
		3'b110 : correct_code_word2 = {code_word2[6], code_word2[5], code_word2[4], code_word2[3], !code_word2[2], code_word2[1], code_word2[0]}; // x2 is wrong
		3'b111 : correct_code_word2 = {code_word2[6], code_word2[5], code_word2[4], !code_word2[3], code_word2[2], code_word2[1], code_word2[0]}; // x1 is wrong
		default: correct_code_word2 = code_word2;
	endcase
end

always @(*) begin
	case (cw2_even)
		3'b001 : opt[0] = code_word2[4];// p3 is wrong
		3'b010 : opt[0] = code_word2[5];// p2 is wrong
		3'b011 : opt[0] = code_word2[0];// x4 is wrong
		3'b100 : opt[0] = code_word2[6];// p1 is wrong
		3'b101 : opt[0] = code_word2[1];// x3 is wrong
		3'b110 : opt[0] = code_word2[2];// x2 is wrong
		3'b111 : opt[0] = code_word2[3];// x1 is wrong
		default: opt[0] = 0;
	endcase
end

// final calculations
assign sel1 = (opt[1] == 0) ? {correct_code_word1[3], correct_code_word1[2], correct_code_word1[1], correct_code_word1[0], 1'b0} : {correct_code_word1[3], correct_code_word1};
assign sel2 = (opt[1] == 0) ? {correct_code_word2[3], correct_code_word2} : {correct_code_word2[3], correct_code_word2[2], correct_code_word2[1], correct_code_word2[0], 1'b0};

always @(*) begin
	cin = (^opt == 0) ? 1'b0 : 1'b1;
	final_sel2 = (^opt == 0) ? sel2 : ~sel2;
	out_n = sel1 + final_sel2 + $signed({1'b0, cin});
end

endmodule
