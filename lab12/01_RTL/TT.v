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

//==============================================//
//               Input and Output               //
//==============================================//
input               clk, rst_n, in_valid;
input       [3:0]   source;
input       [3:0]   destination;

output reg          out_valid;
output reg  [3:0]   cost;

//==============================================//
//             Parameter and Integer            //
//==============================================//
parameter RESET  = 3'd0;
parameter INPUT  = 3'd1;
parameter VERTEX = 3'd2;
parameter FIND   = 3'd3;
parameter OUTPUT = 3'd4;

parameter WHITE = 2'd0;
parameter GRAY  = 2'd1;
parameter BLACK = 2'd2;

integer i, j, k;
integer a, b, c, d, e;

//==============================================//
//           Reg and Wire declaration           //
//==============================================//
// Input
reg [1:0] state, nextstate;
reg [3:0] src_station, tar_station;
reg [3:0] src_reg, tar_reg;
reg input_connection;
reg connect [0:15][0:15];

// Array
reg [4:0] queue [0:15];
reg [3:0] q_index;
reg [1:0] color [0:15];
reg [3:0] distance [0:15];

// Operation
reg [4:0] vertex_now;
reg [3:0] find_count;
wire [3:0] color_pos;
wire connect_cont, color_cont, q_enable;
reg find_finish;
wire op_finish, op_finish_1;

//==============================================//
//             Current State Block              //
//==============================================//
always@(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= RESET;
    else        state <= nextstate;
end

//==============================================//
//              Next State Block                //
//==============================================//
always@(*) begin
    case(state)
        RESET: begin
            if (in_valid) nextstate = INPUT;
            else          nextstate = state;
        end
        INPUT: begin
            if (!in_valid) nextstate = VERTEX;
            else           nextstate = state;
        end
        VERTEX: begin
            if (op_finish || op_finish_1) nextstate = OUTPUT;
            else                          nextstate = FIND;
        end
        FIND: begin
            if (find_finish) nextstate = VERTEX;
            else             nextstate = state;
        end
        OUTPUT: begin
            if (out_valid) nextstate = RESET;
            else           nextstate = state;
        end
        default: nextstate = state;
    endcase
end

//==============================================//
//                  Input Block                 //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        src_station <= 0;
        tar_station <= 0;
    end
    else if (state==RESET && in_valid) begin
        src_station <= source;
        tar_station <= destination;
    end
    else begin
        src_station <= src_station;
        tar_station <= tar_station;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        src_reg <= 0;
        tar_reg <= 0;
    end
    else if (state==INPUT && in_valid) begin
        src_reg <= source;
        tar_reg <= destination;
    end
    else begin
        src_reg <= 0;
        tar_reg <= 0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) input_connection <= 0;
    else if (state == INPUT) begin
        if (in_valid) input_connection <= 1;
        else          input_connection <= 0;
    end
    else input_connection <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i=0; i<16; i=i+1) begin
            for (j=0; j<16; j=j+1) begin
                connect[i][j] <= 0;
            end
        end
    end
    else if (state == RESET) begin
        for (i=0; i<16; i=i+1) begin
            for (j=0; j<16; j=j+1) begin
                connect[i][j] <= 0;
            end
        end
    end
    else if (input_connection) begin
        connect[src_reg][tar_reg] <= 1;
        connect[tar_reg][src_reg] <= 1;
    end
    else begin
        for (i=0; i<16; i=i+1) begin
            for (j=0; j<16; j=j+1) begin
                connect[i][j] <= connect[i][j];
            end
        end
    end
end

//==============================================//
//               Operation Block                //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (a=0; a<16; a=a+1) begin
            queue[a] <= 5'd16;
        end
    end
    else if (state == RESET) begin
        for (a=0; a<16; a=a+1) begin
            queue[a] <= 5'd16;
        end
    end
    else if (state == INPUT) begin
        if (!in_valid) queue[0] <= src_station;
        else           queue[0] <= queue[0];
    end
    else if (state == VERTEX) begin
        for (a=0; a<15; a=a+1) begin
            queue[a] <= queue[a+1];
        end
        queue[15] <= 5'd16;
    end
    else if (state == FIND) begin
        if (q_enable) queue[q_index] <= find_count;
        else          queue[q_index] <= queue[q_index];
    end
    else begin
        for (a=0; a<16; a=a+1) begin
            queue[a] <= queue[a];
        end
    end
end

assign color_pos = queue[0];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (b=0; b<16; b=b+1) begin
            color[b] <= WHITE;
        end
    end
    else if (state == RESET) begin
        for (b=0; b<16; b=b+1) begin
            color[b] <= WHITE;
        end
    end
    else if (state == VERTEX) color[color_pos] <= BLACK;
    else if (state == FIND) begin
        if (q_enable) color[find_count] <= GRAY;
        else          color[find_count] <= color[find_count];
    end
    else begin
        for (b=0; b<16; b=b+1) begin
            color[b] <= color[b];
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (c=0; c<16; c=c+1) begin
            distance[c] <= 4'd15;
        end
    end
    else if (state == RESET) begin
        for (c=0; c<16; c=c+1) begin
           distance[c] <= 4'd15;
        end
    end
    else if (state == INPUT) begin
        if (!in_valid) distance[src_station] <= 0;
        else           distance[src_station] <= distance[src_station];
    end
    else if (state == FIND) begin
        if (q_enable) distance[find_count] <= distance[vertex_now] + 1;
        else          distance[find_count] <= distance[find_count];
    end
    else begin
        for (c=0; c<16; c=c+1) begin
            distance[c] <= distance[c];
        end
    end
end

//==============================================//
//                Control Block                 //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) q_index <= 0;
    else if (state == INPUT) q_index <= 1;
    else if (state == VERTEX) q_index <= q_index - 1;
    else if (state == FIND) begin
        if (q_enable) q_index <= q_index + 1;
        else          q_index <= q_index;
    end
    else q_index <= q_index;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) vertex_now <= 5'd16;
    else if (state == RESET) vertex_now <= 5'd16;
    else if (state == VERTEX) vertex_now <= queue[0];
    else vertex_now <= vertex_now;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) find_count <= 0;
    else if (state == FIND) begin
        if (find_finish) find_count <= 0;
        else             find_count <= find_count + 1;
    end
    else find_count <= 0;
end

assign connect_cont = connect[vertex_now][find_count];
assign color_cont = (color[find_count] == WHITE)? 1:0;
assign q_enable = connect_cont & color_cont;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) find_finish <= 0;
    else if (state == FIND) begin
        if (find_count == 4'd14) find_finish <= 1;
        else                     find_finish <= 0;
    end
    else find_finish <= 0;
end

assign op_finish   = (queue[0] == tar_station)? 1:0;
assign op_finish_1 = (queue[0] == 5'd16)? 1:0;

//==============================================//
//                Output Block                  //
//==============================================//
always@(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 0;
    else if (state == VERTEX) begin
        if (op_finish || op_finish_1) out_valid <= 1;
        else out_valid <= 0;
    end
    else out_valid <= 0;
end

always@(posedge clk or negedge rst_n) begin
    if (!rst_n) cost <= 0;
    else if (state == VERTEX) begin
        if (op_finish) cost <= distance[tar_station];
        else if (op_finish_1) cost <= 0;
        else cost <= cost;
    end
    else cost <= 0;
end 

endmodule 