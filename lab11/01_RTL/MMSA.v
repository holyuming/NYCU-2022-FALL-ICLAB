module MMSA(
// input signals
    clk,
    rst_n,
    in_valid,
		in_valid2,
    matrix,
		matrix_size,
    i_mat_idx,
    w_mat_idx,
	
// output signals
    out_valid,
    out_value
);
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input           clk, rst_n, in_valid, in_valid2;
input           matrix;
input [1:0]     matrix_size;
input           i_mat_idx, w_mat_idx;

output reg  out_valid;//
output reg  out_value;//
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

localparam  S_IDLE = 0,
            S_SRAM = 1,
            S_CAL  = 2,
            S_CAL_OUT = 3,
            S_OUT  = 4,
            S_WAIT = 5
            ;

//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------

genvar i, j;
integer k, l;

// fsm
reg [2:0] c_state, n_state;

// matrix counter, indicating that how much matrix multiplications has done
reg [4:0] matrix_counter, n_matrix_counter;

// matrix size saved
reg [1:0] size, n_size; 


// counter
// counter 0 & counter 1 (used for address)
reg [3:0] bit_counter, n_bit_counter;
reg [6:0] base_counter, n_base_counter; // i have changed the bit from 7 -> 6
reg [3:0] counter0, n_counter0;
reg [2:0] counter1, n_counter1;

// calculation counter
reg [5:0] cal_cnt, n_cal_cnt;
wire [5:0] col;

// index array
reg [3:0] xi_ary ;
reg [3:0] wi_ary;



// systolic array
reg signed [15:0]   W [0:15][0:15], n_W [0:15][0:15];
reg signed [15:0]   A [0:15][0:15], n_A [0:15][0:15];
reg signed [39:0]   B [0:15][0:15], n_B [0:15][0:15];

// save x, w which matrix to be calculate
reg [3:0] xi, wi, n_xi, n_wi;


// store results
reg result_valid, n_result_valid;
reg [39:0] result, n_result;
reg [39:0] result_ary [0:14], n_result_ary [0:14];
reg [5:0] len;
reg [5:0] len_ary [0:14], n_len_ary [0:14];
reg [3:0] start_idx;
reg [3:0] idx, n_idx;
reg [5:0] ans_idx, n_ans_idx;

// output
reg [5:0] output_counter, n_output_counter;
reg signed [39:0] sum2, sum4, sum8, sum16;
reg n_out_valid, n_out_value;

// sram
reg [15:0] data;
reg single_bit [0:14];
wire signed [15:0]  xq [0:7];
wire signed [15:0]  wq [0:7];

reg x_w_r [0:7];       // x write or read
reg w_w_r [0:7];       // w write or read

reg x_finsish;

reg [7:0] waddr;
reg [7:0] xaddr [0:7], n_xaddr [0:7];

MEM256 X0 (.Q(xq[0]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(x_w_r[0]),  .A(xaddr[0]),  .D(data));
MEM256 X1 (.Q(xq[1]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(x_w_r[1]),  .A(xaddr[1]),  .D(data));
MEM256 X2 (.Q(xq[2]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(x_w_r[2]),  .A(xaddr[2]),  .D(data));
MEM256 X3 (.Q(xq[3]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(x_w_r[3]),  .A(xaddr[3]),  .D(data));
MEM256 X4 (.Q(xq[4]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(x_w_r[4]),  .A(xaddr[4]),  .D(data));
MEM256 X5 (.Q(xq[5]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(x_w_r[5]),  .A(xaddr[5]),  .D(data));
MEM256 X6 (.Q(xq[6]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(x_w_r[6]),  .A(xaddr[6]),  .D(data));
MEM256 X7 (.Q(xq[7]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(x_w_r[7]),  .A(xaddr[7]),  .D(data));


MEM256 W0 (.Q(wq[0]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(w_w_r[0]),  .A(waddr), .D(data));
MEM256 W1 (.Q(wq[1]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(w_w_r[1]),  .A(waddr), .D(data));
MEM256 W2 (.Q(wq[2]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(w_w_r[2]),  .A(waddr), .D(data));
MEM256 W3 (.Q(wq[3]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(w_w_r[3]),  .A(waddr), .D(data));
MEM256 W4 (.Q(wq[4]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(w_w_r[4]),  .A(waddr), .D(data));
MEM256 W5 (.Q(wq[5]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(w_w_r[5]),  .A(waddr), .D(data));
MEM256 W6 (.Q(wq[6]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(w_w_r[6]),  .A(waddr), .D(data));
MEM256 W7 (.Q(wq[7]),  .CLK(clk), .CEN(1'b0), .OEN(1'b0), .WEN(w_w_r[7]),  .A(waddr), .D(data));

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------

//fsm
always @(*) begin
    case (c_state)                      
        S_IDLE      : n_state = (in_valid == 1) ? S_SRAM : S_IDLE;
        S_SRAM      : n_state = (in_valid == 1) ? S_SRAM : S_WAIT;
        S_WAIT      : n_state = (n_matrix_counter == 16) ? S_IDLE : (in_valid2 == 1) ? S_CAL : S_WAIT;
        S_CAL       : n_state = (n_matrix_counter == 16) ? S_IDLE : (result_valid == 1 && n_result_valid == 0) ? S_OUT : S_CAL;
        S_OUT       : begin
            if  (n_matrix_counter == 16) 
                n_state = S_IDLE;
            else if (n_idx == 15)
                n_state = S_WAIT;
            else
                n_state = S_OUT;
        end
        default: n_state = S_IDLE; 
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     c_state <= S_IDLE;
    else            c_state <= n_state;
end


// matrix counter
always @(*) begin
    n_matrix_counter = (matrix_counter == 16) ? 0 : (out_valid == 1 && n_out_valid == 0) ? matrix_counter + 1 : matrix_counter;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     matrix_counter <= 0;
    else            matrix_counter <= n_matrix_counter;
end


// save matrix size
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     size <= 0;
    else            size <= (in_valid == 1 & c_state == S_IDLE) ? matrix_size : size;
end


// counter
always @(*) begin
    n_bit_counter   = (in_valid == 1) ? bit_counter + 1 : 0;

    if (in_valid == 1) begin
        n_base_counter = (bit_counter == 15) ? base_counter + 1 : base_counter;
    end else begin
        n_base_counter = 0;
    end

    // which matrix
    n_counter0 = (  c_state == S_SRAM && 
                   ((size == 2'b00 && n_base_counter[1:0] == 2'd0 && bit_counter == 15) ||
                    (size == 2'b01 && n_base_counter[3:0] == 4'd0 && bit_counter == 15) ||
                    (size == 2'b10 && n_base_counter[5:0] == 6'd0 && bit_counter == 15)) ) ? counter0 + 1 : (n_state != S_SRAM) ? 0 : counter0;
    // which position
    n_counter1 = (  c_state == S_SRAM && 
                   ((size == 2'b00 && n_base_counter[ 0 ] == 1'd0 && bit_counter == 15) ||
                    (size == 2'b01 && n_base_counter[1:0] == 2'd0 && bit_counter == 15) ||
                    (size == 2'b10 && n_base_counter[2:0] == 3'd0 && bit_counter == 15)) ) ? counter1 + 1 : (n_state != S_SRAM) ? 0 : counter1;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bit_counter     <= 0;
        base_counter    <= 0;
        counter0        <= 0;
        counter1        <= 0;
    end else begin
        bit_counter     <= n_bit_counter;
        base_counter    <= n_base_counter;
        counter0        <= n_counter0;
        counter1        <= n_counter1;
    end
end


// single bit
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (k=0 ; k<=14 ; k=k+1) begin
            single_bit[k] <= 0;
        end
    end else begin
        single_bit[14] <= (in_valid == 1) ? matrix : single_bit[14];
        for (k=0 ; k<=13 ; k=k+1) begin
            single_bit[k] <= single_bit[k+1];
        end
    end
end
always @(*) begin
    data = {
        single_bit[0], single_bit[1], single_bit[2], single_bit[3], 
        single_bit[4], single_bit[5], single_bit[6], single_bit[7], 
        single_bit[8], single_bit[9], single_bit[10], single_bit[11],
        single_bit[12], single_bit[13], single_bit[14], matrix
    };
end


// X sram WEN
always @(*) begin
    // default WEN == 1, read
    for (k=0 ; k<=7 ; k=k+1) begin
        x_w_r[k] = 1;
    end
    if (n_state == S_SRAM && x_finsish == 0) begin
        case (size)
            2'b00: begin
                case (base_counter[0])
                    0: x_w_r[0] = 0;
                    1: x_w_r[1] = 0; 
                endcase
            end
            2'b01: begin
                case (base_counter[1:0])
                    0: x_w_r[0] = 0;
                    1: x_w_r[1] = 0;
                    2: x_w_r[2] = 0;
                    3: x_w_r[3] = 0;
                endcase
            end
            2'b10: begin
                case (base_counter[2:0])
                    0: x_w_r[0] = 0;
                    1: x_w_r[1] = 0;
                    2: x_w_r[2] = 0;
                    3: x_w_r[3] = 0;
                    4: x_w_r[4] = 0;
                    5: x_w_r[5] = 0;
                    6: x_w_r[6] = 0;
                    7: x_w_r[7] = 0;
                endcase
            end
        endcase
    end
end


// X address
always @(*) begin
    for (k=0 ; k<=7 ; k=k+1) begin
        n_xaddr[k] = 0;
    end
    if (n_state == S_SRAM) begin
        case (size)
            2'b00: begin
                for (k=0 ; k<=8 ; k=k+1) begin
                    n_xaddr[k] = {n_counter0, 3'b000, n_counter1[0]};
                end
            end
            2'b01: begin
                for (k=0 ; k<=8 ; k=k+1) begin
                    n_xaddr[k] = {n_counter0, 2'b00, n_counter1[1:0]};
                end
            end
            2'b10: begin
                for (k=0 ; k<=8 ; k=k+1) begin
                    n_xaddr[k] = {n_counter0, 1'b0, n_counter1[2:0]};
                end
            end
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)         xaddr[0] <= 0;
    else begin
        if (n_state == S_SRAM)  xaddr[0] <= n_xaddr[0];
        else                    xaddr[0] <= (c_state == S_IDLE) ? 0 : {n_xi, n_cal_cnt[3:0]};
    end
end
// shift register
generate
for (i=1 ; i<=7 ; i=i+1) begin
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)     xaddr[i] <= 0;
        else begin          
            // else                    xaddr[i] <= (c_state == S_IDLE) ? 0 : xaddr[i-1];
            if (n_state == S_SRAM)      xaddr[i] <= n_xaddr[i];
            else if (c_state == S_IDLE) xaddr[i] <= 0;
            else                        xaddr[i] <= xaddr[i-1];
        end
    end
end
endgenerate

// x finish, used for indicating write X or write W
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     x_finsish <= 0;
    else begin
        if (in_valid == 0)      x_finsish <= 0;
        else                    x_finsish <= (counter0 == 15 && n_counter0 == 0) ? 1 : x_finsish;
    end
end


// w address 
always @(*) begin
    if (c_state == S_SRAM) begin
        case (size)
            2'b00: waddr = (x_finsish == 1) ? {counter0, 3'd0, base_counter[0]}      : 0;
            2'b01: waddr = (x_finsish == 1) ? {counter0, 2'd0, base_counter[1:0]}    : 0;
            2'b10: waddr = (x_finsish == 1) ? {counter0, 1'd0, base_counter[2:0]}    : 0;
            2'b11: waddr = (x_finsish == 1) ? {counter0, base_counter[3:0]}          : 0; // useless
        endcase
    end
    else begin
        waddr = {n_wi, n_cal_cnt[3:0]};
    end
end 


// W sram WEN
always @(*) begin
    // default
    for (k=0 ; k<=7 ; k=k+1) begin
        w_w_r[k] = 1;               // default WEN = 1, read
    end
    // wen follow counter1
    if (n_state == S_SRAM && x_finsish == 1) begin
        case (size)
            2'b00: begin
                case (counter1[0])
                    0: w_w_r[0] = 0;
                    1: w_w_r[1] = 0; 
                endcase
            end 
            2'b01: begin
                case (counter1[1:0])
                    0: w_w_r[0] = 0;
                    1: w_w_r[1] = 0; 
                    2: w_w_r[2] = 0;
                    3: w_w_r[3] = 0; 
                endcase
            end
            2'b10: begin
                case (counter1[2:0])
                    0: w_w_r[0] = 0;
                    1: w_w_r[1] = 0; 
                    2: w_w_r[2] = 0;
                    3: w_w_r[3] = 0; 
                    4: w_w_r[4] = 0;
                    5: w_w_r[5] = 0; 
                    6: w_w_r[6] = 0;
                    7: w_w_r[7] = 0; 
                endcase
            end
        endcase
    end
end


// save idx_x and idx_w --> which matrix to be calculated
always @(*) begin
    n_xi = (in_valid2 == 1) ? (xi << 1) | i_mat_idx : xi;
    n_wi = (in_valid2 == 1) ? (wi << 1) | w_mat_idx : wi;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        xi <= 0;
        wi <= 0;
    end
    else begin
        xi <= n_xi;
        wi <= n_wi;
    end
end


// calculation counter
always @(*) begin
    n_cal_cnt = (c_state != S_CAL || in_valid2 == 1) ? 0 : cal_cnt + 1;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     cal_cnt <= 0;
    else            cal_cnt <= n_cal_cnt;
end


// B (16 x 16)
generate                                
for (i=2 ; i<=8 ; i=i+1) begin         // i = 2 ~ 15, j = 0 ~ 15
    for (j=0 ; j<=8 ; j=j+1) begin
        always @(*) begin
            n_B[i][j] = A[i-1][j] * W[i-1][j] + B[i-1][j];
        end
    end
end
endgenerate
generate
for (j=0 ; j<=8 ; j=j+1) begin         // used for n_B[1][j], j = 0 ~ 15
    always @(*) begin
        n_B[1][j] = A[0][j] * W[0][j];
    end
end
endgenerate
generate
for (i=1 ; i<=8 ; i=i+1) begin
    for (j=0 ; j<=8 ; j=j+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)     B[i][j] <= 0;
            else            B[i][j] <= (c_state == S_SRAM) ? 0 : n_B[i][j];
        end
    end
end
endgenerate

// summing the final systolic array output
always @(*) begin
    sum2  = n_B[2][0] + n_B[2][1];
    sum4  = n_B[4][0] + n_B[4][1] + n_B[4][2] + n_B[4][3];
    sum8  = n_B[8][0] + n_B[8][1] + n_B[8][2] + n_B[8][3] + n_B[8][4] + n_B[8][5] + n_B[8][6] + n_B[8][7];
end

// A (16 x 16)
always @(*) begin
    // default
    for (k=0 ; k<=7 ; k=k+1) begin
        n_A[k][0] = 0;    
    end

    if (size == 2'b00) begin
        n_A[0][0]  = (c_state == S_CAL && n_cal_cnt >= 2 && n_cal_cnt <= 3) ? xq[0] : 0;
        n_A[1][0]  = (c_state == S_CAL && n_cal_cnt >= 3 && n_cal_cnt <= 4) ? xq[1] : 0;
    end
    else if (size == 2'b01) begin
        n_A[0][0] = (c_state == S_CAL && n_cal_cnt >= 2 && n_cal_cnt <= 5) ? xq[0] : 0;
        n_A[1][0] = (c_state == S_CAL && n_cal_cnt >= 3 && n_cal_cnt <= 6) ? xq[1] : 0;
        n_A[2][0] = (c_state == S_CAL && n_cal_cnt >= 4 && n_cal_cnt <= 7) ? xq[2] : 0;
        n_A[3][0] = (c_state == S_CAL && n_cal_cnt >= 5 && n_cal_cnt <= 8) ? xq[3] : 0;
    end
    else if (size == 2'b10) begin
        n_A[0][0] = (c_state == S_CAL && n_cal_cnt >= 2 && n_cal_cnt <= 9)  ? xq[0] : 0;
        n_A[1][0] = (c_state == S_CAL && n_cal_cnt >= 3 && n_cal_cnt <= 10) ? xq[1] : 0;
        n_A[2][0] = (c_state == S_CAL && n_cal_cnt >= 4 && n_cal_cnt <= 11) ? xq[2] : 0;
        n_A[3][0] = (c_state == S_CAL && n_cal_cnt >= 5 && n_cal_cnt <= 12) ? xq[3] : 0;
        n_A[4][0] = (c_state == S_CAL && n_cal_cnt >= 6 && n_cal_cnt <= 13) ? xq[4] : 0;
        n_A[5][0] = (c_state == S_CAL && n_cal_cnt >= 7 && n_cal_cnt <= 14) ? xq[5] : 0;
        n_A[6][0] = (c_state == S_CAL && n_cal_cnt >= 8 && n_cal_cnt <= 15) ? xq[6] : 0;
        n_A[7][0] = (c_state == S_CAL && n_cal_cnt >= 9 && n_cal_cnt <= 16) ? xq[7] : 0;
    end
end
// shift register
generate
for (i=0 ; i<=7 ; i=i+1) begin
    for (j=1 ; j<=7 ; j=j+1) begin
        always @(*) begin
            n_A[i][j] = A[i][j-1];
        end
    end
end
endgenerate
generate
for (i=0 ; i<=7 ; i=i+1) begin
    for (j=0 ; j<=7 ; j=j+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)     A[i][j] <= 0;
            else            A[i][j] <= (c_state == S_SRAM) ? 0 : n_A[i][j];
        end
    end
end
endgenerate

// W (16 x 16)
assign col = n_cal_cnt - 1;
always @(*) begin
    // default
    for (k=0 ; k<=7 ; k=k+1) begin
        for (l=0 ; l<=7 ; l=l+1) begin
            n_W[k][l] = W[k][l];
        end
    end
    // select w input according to cnt 
    n_W[0][col] = (c_state == S_CAL && n_cal_cnt >= 0) ? wq[0] : 1;
    n_W[1][col] = (c_state == S_CAL && n_cal_cnt >= 0) ? wq[1] : 1;

    n_W[2][col] = (c_state == S_CAL && n_cal_cnt >= 0 && size != 2'b00) ? wq[2] : 1;
    n_W[3][col] = (c_state == S_CAL && n_cal_cnt >= 0 && size != 2'b00) ? wq[3] : 1;

    n_W[4][col] = (c_state == S_CAL && n_cal_cnt >= 0 && size != 2'b00 && size != 2'b01) ? wq[4] : 1;
    n_W[5][col] = (c_state == S_CAL && n_cal_cnt >= 0 && size != 2'b00 && size != 2'b01) ? wq[5] : 1;
    n_W[6][col] = (c_state == S_CAL && n_cal_cnt >= 0 && size != 2'b00 && size != 2'b01) ? wq[6] : 1;
    n_W[7][col] = (c_state == S_CAL && n_cal_cnt >= 0 && size != 2'b00 && size != 2'b01) ? wq[7] : 1;
end
generate
for (i=0 ; i<=7 ; i=i+1) begin
    for (j=0 ; j<=7 ; j=j+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)     W[i][j] <= 1;          // default W weight == 1
            else            W[i][j] <= (c_state == S_SRAM) ? 1 : n_W[i][j];   
        end
    end
end
endgenerate


// store results
always @(*) begin
    case (size)
        2'b00: n_result_valid = (n_cal_cnt >= 4 && n_cal_cnt <= 6) ? 1 : 0; 
        2'b01: n_result_valid = (n_cal_cnt >= 6 && n_cal_cnt <= 12) ? 1 : 0;
        2'b10: n_result_valid = (n_cal_cnt >= 10 && n_cal_cnt <= 24) ? 1 : 0;
        default: n_result_valid = 0;
    endcase
end
always @(*) begin
    case (size)
        2'b00: n_result = (n_result_valid == 1) ? sum2 : 0;
        2'b01: n_result = (n_result_valid == 1) ? sum4 : 0;
        2'b10: n_result = (n_result_valid == 1) ? sum8 : 0;
        default: n_result = 0; 
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_valid    <= 0;
        result          <= 0;
    end else begin
        result_valid    <= n_result_valid;
        result          <= n_result;
    end
end


// result array
always @(*) begin
    n_result_ary[14] = (result_valid == 1) ? result : result_ary[14];
    for (k=0 ; k<=13 ; k=k+1) begin
        n_result_ary[k] = (result_valid == 1) ? result_ary[k+1] : result_ary[k];
    end 
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (k=0 ; k<=14 ; k=k+1) begin
            result_ary[k] <= 0;
        end
    end else begin
        for (k=0 ; k<=14 ; k=k+1) begin
            result_ary[k] <= n_result_ary[k];
        end
    end
end


// len array
always @(*) begin
    if      (result[39] == 1)   len = 40;
    else if (result[38] == 1)   len = 39;
    else if (result[37] == 1)   len = 38;
    else if (result[36] == 1)   len = 37;
    else if (result[35] == 1)   len = 36;
    else if (result[34] == 1)   len = 35;
    else if (result[33] == 1)   len = 34;
    else if (result[32] == 1)   len = 33;
    else if (result[31] == 1)   len = 32;
    else if (result[30] == 1)   len = 31;
    else if (result[29] == 1)   len = 30;
    else if (result[28] == 1)   len = 29;
    else if (result[27] == 1)   len = 28;
    else if (result[26] == 1)   len = 27;
    else if (result[25] == 1)   len = 26;
    else if (result[24] == 1)   len = 25;
    else if (result[23] == 1)   len = 24;
    else if (result[22] == 1)   len = 23;
    else if (result[21] == 1)   len = 22;
    else if (result[20] == 1)   len = 21;
    else if (result[19] == 1)   len = 20;
    else if (result[18] == 1)   len = 19;
    else if (result[17] == 1)   len = 18;
    else if (result[16] == 1)   len = 17;
    else if (result[15] == 1)   len = 16;
    else if (result[14] == 1)   len = 15;
    else if (result[13] == 1)   len = 14;
    else if (result[12] == 1)   len = 13;
    else if (result[11] == 1)   len = 12;
    else if (result[10] == 1)   len = 11;
    else if (result[9] == 1)    len = 10;
    else if (result[8] == 1)    len = 9;
    else if (result[7] == 1)    len = 8;
    else if (result[6] == 1)    len = 7;
    else if (result[5] == 1)    len = 6;
    else if (result[4] == 1)    len = 5;
    else if (result[3] == 1)    len = 4;
    else if (result[2] == 1)    len = 3;
    else if (result[1] == 1)    len = 2;
    else                        len = 1;

    n_len_ary[14] = (result_valid == 1) ? len : len_ary[14];
    for (k=0 ; k<=13 ; k=k+1) begin
        n_len_ary[k] = (result_valid == 1) ? len_ary[k+1] : len_ary[k];
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (k=0 ; k<=14 ; k=k+1) begin
            len_ary[k] <= 0;
        end
    end else begin
        for (k=0 ; k<=14 ; k=k+1) begin
            len_ary[k] <= n_len_ary[k];
        end
    end
end


// start index
always @(*) begin
    case (size)
        2'b00: start_idx = (result_valid == 1) ? 12 : 0; 
        2'b01: start_idx = (result_valid == 1) ? 8  : 0; 
        2'b10: start_idx = (result_valid == 1) ? 0  : 0; 
        default: start_idx = 0;
    endcase
end

// output counter
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     output_counter <= 0;
    else begin
        case (c_state)
            S_OUT   : output_counter <= (output_counter == (len_ary[idx] + 5)) ? 0 : output_counter + 1; 
            default : output_counter <= 0;
        endcase
    end
end

// output array index
always @(*) begin
    case (c_state)
        S_IDLE  : n_idx = 0;
        S_CAL   : n_idx = start_idx;
        S_OUT   : n_idx = (output_counter == (len_ary[idx] + 5)) ? idx + 1 : idx;
        default : n_idx = 0;
    endcase 
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     idx <= 0;
    else            idx <= n_idx;
end



// output
always @(*) begin
    // needed to be modified
    n_out_valid = (c_state == S_OUT) ? 1 : 0;
    n_out_value = 0;
    if (c_state == S_OUT) begin
        case (output_counter)
            0 : n_out_value = len_ary[idx][5]; 
            1 : n_out_value = len_ary[idx][4]; 
            2 : n_out_value = len_ary[idx][3]; 
            3 : n_out_value = len_ary[idx][2]; 
            4 : n_out_value = len_ary[idx][1]; 
            5 : n_out_value = len_ary[idx][0]; 
            6 : n_out_value = result_ary[idx][len_ary[idx] - 1];
            7 : n_out_value = result_ary[idx][len_ary[idx] - 2];
            8 : n_out_value = result_ary[idx][len_ary[idx] - 3];
            9 : n_out_value = result_ary[idx][len_ary[idx] - 4];
            10: n_out_value = result_ary[idx][len_ary[idx] - 5];
            11: n_out_value = result_ary[idx][len_ary[idx] - 6];
            12: n_out_value = result_ary[idx][len_ary[idx] - 7];
            13: n_out_value = result_ary[idx][len_ary[idx] - 8];
            14: n_out_value = result_ary[idx][len_ary[idx] - 9];
            15: n_out_value = result_ary[idx][len_ary[idx] - 10];
            16: n_out_value = result_ary[idx][len_ary[idx] - 11];
            17: n_out_value = result_ary[idx][len_ary[idx] - 12];
            18: n_out_value = result_ary[idx][len_ary[idx] - 13];
            19: n_out_value = result_ary[idx][len_ary[idx] - 14];
            20: n_out_value = result_ary[idx][len_ary[idx] - 15];
            21: n_out_value = result_ary[idx][len_ary[idx] - 16];
            22: n_out_value = result_ary[idx][len_ary[idx] - 17];
            23: n_out_value = result_ary[idx][len_ary[idx] - 18];
            24: n_out_value = result_ary[idx][len_ary[idx] - 19];
            25: n_out_value = result_ary[idx][len_ary[idx] - 20];
            26: n_out_value = result_ary[idx][len_ary[idx] - 21];
            27: n_out_value = result_ary[idx][len_ary[idx] - 22];
            28: n_out_value = result_ary[idx][len_ary[idx] - 23];
            29: n_out_value = result_ary[idx][len_ary[idx] - 24];
            30: n_out_value = result_ary[idx][len_ary[idx] - 25];
            31: n_out_value = result_ary[idx][len_ary[idx] - 26];
            32: n_out_value = result_ary[idx][len_ary[idx] - 27];
            33: n_out_value = result_ary[idx][len_ary[idx] - 28];
            34: n_out_value = result_ary[idx][len_ary[idx] - 29];
            35: n_out_value = result_ary[idx][len_ary[idx] - 30];
            36: n_out_value = result_ary[idx][len_ary[idx] - 31];
            37: n_out_value = result_ary[idx][len_ary[idx] - 32];
            38: n_out_value = result_ary[idx][len_ary[idx] - 33];
            39: n_out_value = result_ary[idx][len_ary[idx] - 34];
            40: n_out_value = result_ary[idx][len_ary[idx] - 35];
            41: n_out_value = result_ary[idx][len_ary[idx] - 36];
            42: n_out_value = result_ary[idx][len_ary[idx] - 37];
            43: n_out_value = result_ary[idx][len_ary[idx] - 38];
            44: n_out_value = result_ary[idx][len_ary[idx] - 39];
            45: n_out_value = result_ary[idx][len_ary[idx] - 40];
            default : n_out_value = 0; 
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 0;
        out_value <= 0;
    end
    else begin
        out_valid <= n_out_valid;
        out_value <= n_out_value;
    end
end


endmodule

