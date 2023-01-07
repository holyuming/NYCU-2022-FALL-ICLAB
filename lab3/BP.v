module BP(
    clk,
    rst_n,
    in_valid,
    guy,
    in0,
    in1,
    in2,
    in3,
    in4,
    in5,
    in6,
    in7,
    
    out_valid,
    out
);

input             clk, rst_n;
input             in_valid;
input       [2:0] guy;
input       [1:0] in0, in1, in2, in3, in4, in5, in6, in7;
output reg        out_valid;
output reg  [1:0] out;

// answer should be delayed for 57 cycles
reg [1:0] shifted_out [54:0];

// params
genvar i, j;
reg n_out_valid;
reg [1:0] n_out;

reg [1:0] map [0:8][0:7], n_map [0:8][0:7];
reg [2:0] c_pos, n_pos;


// fsm
reg [1:0]   c_state, n_state; // max at 7
localparam  S_IDLE = 0,
            S_READ = 1,
            S_OUT  = 2;


// counter (used for calculating input cycle & calculating output cycle)
reg [5:0] cnt, n_cnt;

// map calculation
reg [2:0] exit_pos;
reg [8:0] isObs;
reg [3:0] firstObs_pos;
reg isCalculating, n_isCalculating;

// simulated output
reg [1:0] tmp_out;
reg [2:0] tmp_pos;


// fsm
always @(*) begin
    case (c_state)
        S_IDLE  :   n_state = (in_valid == 1) ? S_READ : S_IDLE;
        S_READ  :   n_state = (in_valid ==0 && cnt == 0) ? S_OUT : S_READ;
        S_OUT   :   n_state = (cnt == 62) ? S_IDLE : S_OUT;
        default :   n_state = S_IDLE; 
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     c_state <= S_IDLE;
    else            c_state <= n_state;
end


// map
generate
for (i=0 ; i<=7 ; i=i+1) begin
    for (j=0 ; j<=7 ; j=j+1) begin
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n)     map[i][j] <= 2'b00;
            else            map[i][j] <= map[i+1][j];
        end
    end
end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        map[8][0] <= 2'b00;    
        map[8][1] <= 2'b00;    
        map[8][2] <= 2'b00;    
        map[8][3] <= 2'b00;    
        map[8][4] <= 2'b00;    
        map[8][5] <= 2'b00;    
        map[8][6] <= 2'b00;    
        map[8][7] <= 2'b00;    
    end
    else begin 
        map[8][0] <= (in_valid == 1) ? in0 : 0;    
        map[8][1] <= (in_valid == 1) ? in1 : 0;    
        map[8][2] <= (in_valid == 1) ? in2 : 0;    
        map[8][3] <= (in_valid == 1) ? in3 : 0;    
        map[8][4] <= (in_valid == 1) ? in4 : 0;    
        map[8][5] <= (in_valid == 1) ? in5 : 0;    
        map[8][6] <= (in_valid == 1) ? in6 : 0;    
        map[8][7] <= (in_valid == 1) ? in7 : 0; 
    end
end


// counter
always @(*) begin
    n_cnt = (in_valid == 1 || out_valid == 1) ? cnt + 1 : 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     cnt <= 0;
    else            cnt <= n_cnt;
end


// map calculation
always @(*) begin
    isObs[0] = (map[0][0] != 2'b00) ? 1 : 0;
    isObs[1] = (map[1][0] != 2'b00) ? 1 : 0;
    isObs[2] = (map[2][0] != 2'b00) ? 1 : 0;
    isObs[3] = (map[3][0] != 2'b00) ? 1 : 0;
    isObs[4] = (map[4][0] != 2'b00) ? 1 : 0;
    isObs[5] = (map[5][0] != 2'b00) ? 1 : 0;
    isObs[6] = (map[6][0] != 2'b00) ? 1 : 0;
    isObs[7] = (map[7][0] != 2'b00) ? 1 : 0;
    isObs[8] = (map[8][0] != 2'b00) ? 1 : 0;
end

always @(*) begin   // priority decoding
    if      (isObs[1] == 1) firstObs_pos = 1;
    else if (isObs[2] == 1) firstObs_pos = 2;
    else if (isObs[3] == 1) firstObs_pos = 3;
    else if (isObs[4] == 1) firstObs_pos = 4;
    else if (isObs[5] == 1) firstObs_pos = 5;
    else if (isObs[6] == 1) firstObs_pos = 6;
    else if (isObs[7] == 1) firstObs_pos = 7;
    else                    firstObs_pos = 8;
end

// exit position & obs
always @(*) begin
    case (firstObs_pos)
        1: begin
            if      (map[1][0] != 2'b11) exit_pos = 0;
            else if (map[1][1] != 2'b11) exit_pos = 1;
            else if (map[1][2] != 2'b11) exit_pos = 2;
            else if (map[1][3] != 2'b11) exit_pos = 3;
            else if (map[1][4] != 2'b11) exit_pos = 4;
            else if (map[1][5] != 2'b11) exit_pos = 5;
            else if (map[1][6] != 2'b11) exit_pos = 6;
            else if (map[1][7] != 2'b11) exit_pos = 7;
            else                         exit_pos = c_pos;
        end 
        2: begin
            if      (map[2][0] != 2'b11) exit_pos = 0;
            else if (map[2][1] != 2'b11) exit_pos = 1;
            else if (map[2][2] != 2'b11) exit_pos = 2;
            else if (map[2][3] != 2'b11) exit_pos = 3;
            else if (map[2][4] != 2'b11) exit_pos = 4;
            else if (map[2][5] != 2'b11) exit_pos = 5;
            else if (map[2][6] != 2'b11) exit_pos = 6;
            else if (map[2][7] != 2'b11) exit_pos = 7;
            else                         exit_pos = c_pos;
        end 
        3: begin
            if      (map[3][0] != 2'b11) exit_pos = 0;
            else if (map[3][1] != 2'b11) exit_pos = 1;
            else if (map[3][2] != 2'b11) exit_pos = 2;
            else if (map[3][3] != 2'b11) exit_pos = 3;
            else if (map[3][4] != 2'b11) exit_pos = 4;
            else if (map[3][5] != 2'b11) exit_pos = 5;
            else if (map[3][6] != 2'b11) exit_pos = 6;
            else if (map[3][7] != 2'b11) exit_pos = 7;
            else                         exit_pos = c_pos;
        end 
        4: begin
            if      (map[4][0] != 2'b11) exit_pos = 0;
            else if (map[4][1] != 2'b11) exit_pos = 1;
            else if (map[4][2] != 2'b11) exit_pos = 2;
            else if (map[4][3] != 2'b11) exit_pos = 3;
            else if (map[4][4] != 2'b11) exit_pos = 4;
            else if (map[4][5] != 2'b11) exit_pos = 5;
            else if (map[4][6] != 2'b11) exit_pos = 6;
            else if (map[4][7] != 2'b11) exit_pos = 7;
            else                         exit_pos = c_pos;
        end 
        5: begin
            if      (map[5][0] != 2'b11) exit_pos = 0;
            else if (map[5][1] != 2'b11) exit_pos = 1;
            else if (map[5][2] != 2'b11) exit_pos = 2;
            else if (map[5][3] != 2'b11) exit_pos = 3;
            else if (map[5][4] != 2'b11) exit_pos = 4;
            else if (map[5][5] != 2'b11) exit_pos = 5;
            else if (map[5][6] != 2'b11) exit_pos = 6;
            else if (map[5][7] != 2'b11) exit_pos = 7;
            else                         exit_pos = c_pos;
        end 
        6: begin
            if      (map[6][0] != 2'b11) exit_pos = 0;
            else if (map[6][1] != 2'b11) exit_pos = 1;
            else if (map[6][2] != 2'b11) exit_pos = 2;
            else if (map[6][3] != 2'b11) exit_pos = 3;
            else if (map[6][4] != 2'b11) exit_pos = 4;
            else if (map[6][5] != 2'b11) exit_pos = 5;
            else if (map[6][6] != 2'b11) exit_pos = 6;
            else if (map[6][7] != 2'b11) exit_pos = 7;
            else                         exit_pos = c_pos;
        end 
        7: begin
            if      (map[7][0] != 2'b11) exit_pos = 0;
            else if (map[7][1] != 2'b11) exit_pos = 1;
            else if (map[7][2] != 2'b11) exit_pos = 2;
            else if (map[7][3] != 2'b11) exit_pos = 3;
            else if (map[7][4] != 2'b11) exit_pos = 4;
            else if (map[7][5] != 2'b11) exit_pos = 5;
            else if (map[7][6] != 2'b11) exit_pos = 6;
            else if (map[7][7] != 2'b11) exit_pos = 7;
            else                         exit_pos = c_pos;
        end 
        8: begin
            if      (map[8][0] != 2'b11) exit_pos = 0;
            else if (map[8][1] != 2'b11) exit_pos = 1;
            else if (map[8][2] != 2'b11) exit_pos = 2;
            else if (map[8][3] != 2'b11) exit_pos = 3;
            else if (map[8][4] != 2'b11) exit_pos = 4;
            else if (map[8][5] != 2'b11) exit_pos = 5;
            else if (map[8][6] != 2'b11) exit_pos = 6;
            else if (map[8][7] != 2'b11) exit_pos = 7;
            else                         exit_pos = c_pos;
        end 
        default: exit_pos = c_pos;
    endcase
end

// guy
always @(*) begin
    n_pos = (c_state == S_IDLE && in_valid == 1) ? guy : tmp_pos;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     c_pos <= 2'b0;
    else            c_pos <= n_pos;
end


// determing calculating period
always @(*) begin
    if (isCalculating == 0) begin
        if (cnt >= 8 && in_valid == 1)   n_isCalculating = 1;
        else                             n_isCalculating = isCalculating;
    end
    else begin
        if (cnt == 7 && c_state == S_OUT)   n_isCalculating = 0;
        else                                n_isCalculating = isCalculating;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     isCalculating <= 0;
    else            isCalculating <= n_isCalculating;
end

// simulate output
always @(*) begin
    // default value
    tmp_pos = c_pos;
    tmp_out = 0;
    if (isCalculating == 1) begin
        if (exit_pos > c_pos) begin // go right
            tmp_out = 2'd1;
            tmp_pos = c_pos + 1;
        end
        else if (exit_pos < c_pos) begin // go left
            tmp_out = 2'd2;
            tmp_pos = c_pos - 1;
        end
        else begin // stop or jump
            if (map[1][exit_pos] == 2'b01)  tmp_out = 2'd3;
            else                            tmp_out = 2'd0;
        end
    end
end

// delay output until in_valid turn low
generate
for (i=0 ; i<=53 ; i=i+1) begin
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shifted_out[i] <= 2'b00;
        end
        else begin
            shifted_out[i] <= shifted_out[i+1];
        end
    end
end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        shifted_out[54] <= 2'b00;
    end
    else begin
        shifted_out[54] <= tmp_out;
    end
end


// output
always @(*) begin
    n_out = (n_state == S_OUT) ? shifted_out[0] : 0;
    n_out_valid = (n_state == S_OUT) ? 1 : 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid   <= 0;
        out         <= 0;
    end
    else begin
        out_valid   <= n_out_valid;
        out         <= n_out;
    end
end

    
endmodule
