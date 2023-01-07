module TT(
    //Input Port
    clk,
    rst_n,
	in_valid,
    source,
    destination,

    //Output Port
    out_valid,
    cost
    );

input               clk, rst_n, in_valid;
input       [3:0]   source;
input       [3:0]   destination;

output reg          out_valid;
output reg  [3:0]   cost;

// fsm
reg [2:0] c_state, n_state;
parameter S_IDLE = 0;
parameter S_READ = 1;
parameter S_CAL = 2;
parameter S_OUT = 3;

// local params
reg [15:0] edges [15:0];
reg [15:0] n_edges [15:0];

reg [15:0] visited, n_visited;

wire n_out_valid;
reg [3:0] n_cost;
reg cal_finished;

reg [3:0]   from, n_from, 
            to, n_to;

reg [3:0] cnt, cnt1;

wire found_path;

integer  i, j;


// FSM
always@(*) begin
    case(c_state)
        S_IDLE: n_state = (in_valid == 1) ? S_READ : S_IDLE;
        S_READ: n_state = (in_valid == 1) ? S_READ : S_CAL;
        S_CAL:  n_state = (cal_finished == 1 || cnt == 15) ? S_OUT : S_CAL;
        S_OUT:  n_state = S_IDLE;
        default: n_state = S_IDLE;
    endcase
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= S_IDLE;
    else 
        c_state <= n_state;
end

// edges (graph)
always @(*) begin
    for (i=0 ; i<=15 ; i=i+1) begin
        for (j=0 ; j<=15 ; j=j+1) begin
            if (c_state == S_IDLE)
                n_edges[i][j] = 0;
            else if (in_valid == 0)
                n_edges[i][j] = edges[i][j];
            else 
                n_edges[i][j] = ((i == source && j == destination) || (i == destination && j == source)) ? 1 : edges[i][j];
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i=0 ; i<=15 ; i=i+1) begin
            edges[i] <= 16'b0;
        end
    end
    else begin
        for (i=0 ; i<=15 ; i=i+1) begin
            edges[i] <= n_edges[i];
        end
    end
end


// from & to
always @(*) begin
    n_from  = (in_valid == 1 && c_state == S_IDLE) ? source         : from;
    n_to    = (in_valid == 1 && c_state == S_IDLE) ? destination    : to;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        from    <= 3'b0;
        to      <= 3'b0;    
    end
    else begin
        from    <= n_from;
        to      <= n_to;
    end
end


// counter for calculating distance
always @(*) begin
    if (c_state == S_CAL)
        cnt1 = cnt + 1;  
    else
        cnt1 = 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cnt <= 4'b0;
    else
        cnt <= cnt1;
end


// visited
always @(*) begin
    // default
    n_visited = 0;
    if (c_state == S_CAL) begin
        if (cnt == 0) n_visited[from] = 1;
        else begin
            // if (visited[i] == 1 && edges[i][j] == 1) --> n_visited[j] = 1, for i = 0 ~ 15
            for (i=0 ; i<=15 ; i=i+1) begin
                n_visited[i] = (    (visited[0] == 1 && edges[0][i] == 1) ||
                                    (visited[1] == 1 && edges[1][i] == 1) ||
                                    (visited[2] == 1 && edges[2][i] == 1) ||
                                    (visited[3] == 1 && edges[3][i] == 1) ||
                                    (visited[4] == 1 && edges[4][i] == 1) ||    
                                    (visited[5] == 1 && edges[5][i] == 1) ||
                                    (visited[6] == 1 && edges[6][i] == 1) ||
                                    (visited[7] == 1 && edges[7][i] == 1) ||
                                    (visited[8] == 1 && edges[8][i] == 1) ||
                                    (visited[9] == 1 && edges[9][i] == 1) ||
                                    (visited[10] == 1 && edges[10][i] == 1) ||
                                    (visited[11] == 1 && edges[11][i] == 1) ||
                                    (visited[12] == 1 && edges[12][i] == 1) ||
                                    (visited[13] == 1 && edges[13][i] == 1) ||
                                    (visited[14] == 1 && edges[14][i] == 1) ||
                                    (visited[15] == 1 && edges[15][i] == 1) 
                ) ? 1 : visited[i];
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        visited <= 16'b0;
    else
        visited <= n_visited;
end


// output
assign found_path = (
    (to == 0 && n_visited[0] == 1) || 
    (to == 1 && n_visited[1] == 1) || 
    (to == 2 && n_visited[2] == 1) || 
    (to == 3 && n_visited[3] == 1) || 
    (to == 4 && n_visited[4] == 1) || 
    (to == 5 && n_visited[5] == 1) || 
    (to == 6 && n_visited[6] == 1) || 
    (to == 7 && n_visited[7] == 1) || 
    (to == 8 && n_visited[8] == 1) || 
    (to == 9 && n_visited[9] == 1) || 
    (to == 10 && n_visited[10] == 1) || 
    (to == 11 && n_visited[11] == 1) || 
    (to == 12 && n_visited[12] == 1) || 
    (to == 13 && n_visited[13] == 1) || 
    (to == 14 && n_visited[14] == 1)|| 
    (to == 15 && n_visited[15] == 1)
) ? 1 : 0;

always @(*) begin
    cal_finished = (found_path == 1 || n_visited == visited) ? 1 : 0;
end

assign n_out_valid = (n_state == S_OUT) ? 1 : 0;

always @(*) begin
    n_cost = (found_path == 1) ? cnt : 0;
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out_valid <= 0;
    else begin
        out_valid <= n_out_valid;
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cost <= 0;
    else begin
        cost <= n_cost;
    end
end 

endmodule 