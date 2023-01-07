
`ifdef RTL
    `define CYCLE_TIME 10.0
`endif
`ifdef GATE
    `define CYCLE_TIME 10.0
`endif

module PATTERN(
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

// input to design
output reg       clk, rst_n;
output reg       in_valid;
output reg [2:0] guy;
output reg [1:0] in0, in1, in2, in3, in4, in5, in6, in7;

// output to design
input            out_valid;
input      [1:0] out;

/* define clock cycle */
real CYCLE = `CYCLE_TIME;
always #(CYCLE/2.0) clk = ~clk;

// params
integer PATNUM, patnum;     // for patcount
integer SEED;
integer input_cycle;        // used for counting input cycles equals to 64 or not
integer t;                  // used for repeating cycles after out_valid turns down
integer output_latency;     // used for checking the latency from in_valid 1->0, out_valid 0->1
integer output_cycle;       // used for checking whether the output is asserted successively in 63 cycles
integer type_obstacles;     // combination i, ii, iii

reg [1:0] map [63:0][7:0];  // the whole map with obstacles

integer how_far;            // how far can one exit to another exit in different obstacles
reg [2:0] start_position;   // init position
integer exit_position;      // the obstacles's exit
integer tmp_position;
integer left, right;        // used for selectin bounds

integer i, j;               // used for iterating through the entire 2d array -> map

integer position;           // current position of the guy (used in output state)
integer height;             // used for checking the height of the guy


initial begin
    PATNUM = 299;
    SEED = 5678;
    $urandom(SEED);

    // check reset
    reset_task;

    reset_pattern;
    repeat(2) @(negedge clk);
    for (patnum = 0 ; patnum < PATNUM ; patnum = patnum + 1) begin
        generate_pattern;
        input_task;
        latency_check;
        check_ans_and_successive;
        // if (out !== 0 || out_valid !== 0) SPEC7;
        if (out_valid !== 1'b0) SPEC7;
        check_spec4;
        reset_pattern;

        t = $urandom_range(3, 5);
        repeat(t) @(negedge clk);
    end

    YOU_PASS_task;
    $finish;
end

// check reset
task reset_task; begin 
    rst_n = 'b1;
    in_valid = 'b0;

    // set input signal to unknown
    guy = 3'bx;

    in0 = 2'bx;
    in1 = 2'bx;
    in2 = 2'bx;
    in3 = 2'bx;
    in4 = 2'bx;
    in5 = 2'bx;
    in6 = 2'bx;
    in7 = 2'bx;

    force clk = 0;

    #CYCLE; rst_n = 0; 
    #CYCLE; rst_n = 1;
    
    if(out_valid !== 1'b0 || out !=='b0) begin 
        $display("************************************************************");   
        $display("                       SPEC 3 IS FAIL!                      ");   
        $display("*  Output signal should be 0 after initial RESET  at %8t   *",$time);
        $display("************************************************************");
        $finish;
    end
	#CYCLE; release clk;
end endtask

// reset pattern
task reset_pattern; begin
    for (i=0 ; i<=63 ; i=i+1) begin
        for (j=0 ; j<=7 ; j=j+1) begin
            map[i][j] = 2'b00;
        end
    end
end endtask

// generate pattern
task generate_pattern; begin
    // the first cycle of the input pattern should be all zeros
    for (i=0 ; i<=7 ; i=i+1) 
        map[0][i] = 2'b00;

    // the rest
    i = 1;
    j = 0;
    how_far = 1;
    start_position = $urandom_range(0, 7);
    exit_position = start_position;
    while(i <= 63) begin
        type_obstacles = $urandom_range(0, 2);

        // assign to the map
        if (type_obstacles == 0) begin                  // no obstacles
            for (j=0 ; j<=7 ; j=j+1) begin
                map[i][j] = 2'b00;
            end
            how_far = (how_far < 7) ? how_far + 1 : 7;
        end

        if (type_obstacles == 1) begin                  // obstacles in high places -> no jump required
            tmp_position = -1;
            while(tmp_position < 0 || tmp_position > 7) begin
                left =  (exit_position - how_far >= 0) ? exit_position - how_far : 0;
                right = (exit_position + how_far <= 7) ? exit_position + how_far : 7;
                tmp_position = $urandom_range(left, right);
            end
            exit_position = tmp_position;

            for (j=0 ; j<=7 ; j=j+1) begin
                map[i][j] = 2'b11;
            end
            map[i][exit_position] = 2'b10;
            i = i + 1;

            for (j=0 ; j<=7 ; j=j+1) begin
                map[i][j] = 2'b00;
            end
            how_far = 2;
        end

        if (type_obstacles == 2) begin                  // obstaccle in low places (how_far - 1) -> jump
            tmp_position = -1;
            while(tmp_position < 0 || tmp_position > 7) begin
                left =  (exit_position - (how_far - 1) >= 0) ? exit_position - (how_far - 1) : 0;
                right = (exit_position + (how_far - 1) <= 7) ? exit_position + (how_far - 1) : 7;
                tmp_position = $urandom_range(left, right);
            end
            exit_position = tmp_position;

            for (j=0 ; j<=7 ; j=j+1) begin
                map[i][j] = 2'b11;
            end
            map[i][exit_position] = 2'b01;
            i = i + 1;

            for (j=0 ; j<=7 ; j=j+1) begin
                map[i][j] = 2'b00;
            end
            how_far = 2;
        end
        i = i + 1;
    end

    if (patnum == 0) begin
        start_position = 0;
        for (i=0 ; i<=63 ; i=i+1) begin
            for (j=0 ; j<=7 ; j=j+1) begin
                map[i][j] = 0;
            end
        end

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[8][j] = 3;
        end
        map[8][7] = 1;
        // *****************************

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[10][j] = 3;
        end
        map[10][5] = 2;
        // *****************************

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[13][j] = 3;
        end
        map[13][7] = 1;
        // *****************************

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[21][j] = 3;
        end
        map[21][0] = 1;
        // *****************************

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[23][j] = 3;
        end
        map[23][2] = 2;
        // *****************************

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[25][j] = 3;
        end
        map[25][0] = 2;
        // *****************************

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[32][j] = 3;
        end
        map[32][7] = 2;
        // *****************************

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[34][j] = 3;
        end
        map[34][6] = 1;
        // *****************************

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[36][j] = 3;
        end
        map[36][6] = 1;
        // *****************************

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[61][j] = 3;
        end
        map[61][5] = 1;
        // *****************************

        // *****************************
        for (j=0 ; j<=7 ; j=j+1) begin
            map[63][j] = 3;
        end
        map[63][5] = 1;
        // *****************************
    end
        
end endtask


// input task
task input_task; begin

	in_valid = 1'b1;

    input_cycle = 0;
    while (input_cycle < 64) begin // input cycle from 1 ~ 64
        
        guy = (input_cycle == 0) ? start_position : 2'bx;

        in0 = map[input_cycle][0];
        in1 = map[input_cycle][1];
        in2 = map[input_cycle][2];
        in3 = map[input_cycle][3];
        in4 = map[input_cycle][4];
        in5 = map[input_cycle][5];
        in6 = map[input_cycle][6];
        in7 = map[input_cycle][7];

        input_cycle = input_cycle + 1;
        check_spec4;
        check_spec5;
        @(negedge clk);
    end

    in_valid = 1'b0;
    // set input signal (obstacles) to unknown
    in0 = 2'bx;
    in1 = 2'bx;
    in2 = 2'bx;
    in3 = 2'bx;
    in4 = 2'bx;
    in5 = 2'bx;
    in6 = 2'bx;
    in7 = 2'bx;
    
end endtask 

// out should always be reset when out_valid is low             -> spec 4
task check_spec4; begin
    if (out_valid === 1'b0 && out !== 2'b0) begin
        $display("*****************************************************************");   
        $display("                      Current time: %d                   ", $stime);  
        $display("                       SPEC 4 IS FAIL!                           ");   
        $display("      The out should be reset when your out_valid is low.        ");
        $display("*****************************************************************");
        $finish;
    end
end endtask

// check whether the out_valid is high when in_valid is high    -> spec 5
task check_spec5; begin
    if (in_valid === 1'b1 && out_valid !== 1'b0) begin
        $display("************************************************************");  
        $display("                      Current time: %d              ", $stime);   
        $display("                       SPEC 5 IS FAIL!                      ");   
        $display("      The out_valid should be low when in_valid is high.    ");
        $display("************************************************************");
        $finish;
    end
end endtask


// check whether the latency is greater than 3000
task latency_check; begin
    output_latency = 0;
    @(negedge clk);
    check_spec5;
    while (out_valid !== 1'b1) begin
        output_latency = output_latency + 1;
        if (output_latency > 3000) begin
            $display("************************************************************");   
            $display("                       SPEC 6 IS FAIL!                      ");   
            $display("      The execution latency is limited to 3000 cycles.      ");
            $display("************************************************************");
            $finish;
        end
        @(negedge clk);
        check_spec4;
    end
end endtask


// check output answer and successively in 63 cycles
task check_ans_and_successive; begin
    output_cycle = 0;
    position = start_position;
    height = 0;
    while (output_cycle < 63) begin
        if (out_valid === 1'b0) begin
            check_spec4;
            SPEC7;
        end

        // determine current height
        if      (map[output_cycle][position] == 2'b01)   height = 1;
        else                                             height = 0;

        if (out === 2'd3) begin     // jump
            if (height === 0) begin // jump from 0
                if (map[output_cycle + 1][position] === 2'd2 || map[output_cycle + 1][position] === 2'd3)
                    SPEC81;
                if (map[output_cycle + 1][position] === 2'd1)
                    height = 1;
                if (map[output_cycle + 1][position] === 2'd0) begin
                    output_cycle = output_cycle + 1;
                    @(negedge clk);
                    if (out !== 2'd0)
                        SPEC83;
                    if (map[output_cycle + 1][position] === 2'd1 || map[output_cycle + 1][position] === 2'd3)
                        SPEC81;
                end  
            end
            else begin              // jump from 1
                output_cycle = output_cycle + 1;
                @(negedge clk);
                if (out !== 2'd0 && map[output_cycle + 1][position] == 2'd1)    // jump to same height
                    SPEC83;
                if (out !== 2'd0 && map[output_cycle + 1][position] == 2'd0)    // jump from high to low
                    SPEC82;
                if (map[output_cycle + 1][position] === 2'd3 || map[output_cycle + 1][position] === 2'd2)
                    SPEC81;
                
                output_cycle = output_cycle + 1;
                @(negedge clk);
                if (out !== 2'd0)
                    SPEC82;
                if (map[output_cycle + 1][position] === 2'd3 || map[output_cycle + 1][position] === 2'd1)
                    SPEC81;
                
            end
        end 

        if (out === 2'd2) begin      // left
            if (position === 0 || map[output_cycle + 1][position - 1] === 2'd3 || map[output_cycle + 1][position - 1] === 2'd1)
                SPEC81; 
            position = position - 1;
        end

        if (out === 2'd1) begin      // right
            if (position === 7 || map[output_cycle + 1][position + 1] === 2'd3 || map[output_cycle + 1][position + 1] === 2'd1)
                SPEC81; 
            position = position + 1;
        end

        if (out === 2'd0) begin      // stop
            if (map[output_cycle + 1][position] === 2'd3 || map[output_cycle + 1][position] === 2'd1)
                SPEC81;  
        end

        if (out === 2'dx) begin
            SPEC81;
        end

        output_cycle = output_cycle + 1;
        @(negedge clk);
    end
end endtask


// pass all patterns
task YOU_PASS_task; begin
    $display ("--------------------------------------------------------------------");
    $display ("                         Congrats!                                  ");
    $display ("                  You have passed all %d patterns!          ", PATNUM);
    $display ("--------------------------------------------------------------------");        
    $finish;
end endtask

// spec 7
task SPEC7; begin
    $display("*****************************************************************");   
    $display("                       SPEC 7 IS FAIL!                           ");   
    $display("The out_valid and out must be asserted successively in 63 cycles.");
    $display("*****************************************************************");
    $finish;
end endtask

// spec 8-1
task SPEC81; begin
    $display("*****************************************************************");   
    $display("                       SPEC 8-1 IS FAIL!                         ");   
    $display("*****************************************************************");
    $finish;
end endtask


// spec 8-2
task SPEC82; begin
    $display("*****************************************************************");   
    $display("                       SPEC 8-2 IS FAIL!                         ");   
    $display("*****************************************************************");
    // repeat(2) @(negedge clk);
    $finish;
end endtask


// spec 8-3
task SPEC83; begin
    $display("*****************************************************************");   
    $display("                       SPEC 8-3 IS FAIL!                         ");   
    $display("*****************************************************************");
    $finish;
end endtask



endmodule