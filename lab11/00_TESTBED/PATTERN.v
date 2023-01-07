`ifdef RTL
	`define CYCLE_TIME 18.0
	`define RESET_DELAY 20.0
`endif
`ifdef GATE
	`define CYCLE_TIME 18.0
	`define RESET_DELAY 20.0
`endif
`ifdef APR
	`define CYCLE_TIME 18.0
	`define RESET_DELAY 20.0
`endif
`ifdef POST
	`define CYCLE_TIME 18.0
	`define RESET_DELAY 20.0
`endif

module PATTERN(
// output signals
    clk,
    rst_n,
    in_valid,
		in_valid2,
    matrix,
    matrix_size,
    i_mat_idx, 
    w_mat_idx,
// input signals
    out_valid,
    out_value
);
//================================================================
//   parameters & integers
//================================================================

//================================================================
//   INPUT AND OUTPUT DECLARATION                         
//================================================================
output reg 		  	clk, rst_n, in_valid, in_valid2;
output reg 				matrix;
output reg [1:0]  matrix_size;
output reg 				i_mat_idx, w_mat_idx;

input 						out_valid;
input signed 			out_value;
//================================================================
//    wires % registers
//================================================================
integer PAT_NUM;
integer a, i, j, k, b, i_pat, j_pat;
integer f_input, f_idx, f_ans;
reg signed [15:0] matrix_temp;
reg signed [3:0] i_mat_idx_temp, w_mat_idx_temp;
reg [5:0] out_num_bit, gold_num_bit;
integer out_cnt;
integer mat_size;
reg signed [39:0] out_ans, gold_ans;
integer latency, total_latency = 0, total_total_latency = 0;

//================================================================
//    clock
//================================================================
real CYCLE;
initial clk = 0;
always #(CYCLE/2.0) clk = ~clk;
//================================================================
//    initial
//================================================================
initial begin
    $system("python3 ../00_TESTBED/main.py");
	f_input = $fopen("../00_TESTBED/input.txt", "r");
	f_idx = $fopen("../00_TESTBED/idx.txt", "r");
	f_ans = $fopen("../00_TESTBED/ans.txt", "r");
	a = $fscanf(f_input, "%d", PAT_NUM);
	a = $fscanf(f_input, "%f", CYCLE);
    CYCLE = `CYCLE_TIME;
    reset_task;
    for (i_pat = 0; i_pat < PAT_NUM; i_pat = i_pat+1) begin
        input_task;
		total_latency = 0;
		for (j_pat = 0; j_pat < 16; j_pat = j_pat+1) begin
			input2_task;
			wait_out_valid_task;
			check_ans_task;
			$display("\033[0;34mPASS PATTERN NO.%3d-%2d,\033[m \033[0;32mexecution cycle : %3d\033[m",i_pat, j_pat ,latency);
		end
		$display("===================================================");
        $display("\033[0;34mPASS PATTERN NO.%6d,\033[m \033[0;32mexecution cycle : %3d\033[m",i_pat ,total_latency);
		$display("===================================================");
    end
    YOU_PASS_task;
	$finish;
end

task reset_task; begin 
    rst_n = 'b1;
    in_valid = 'b0;
	in_valid2 = 'b0;
    matrix = 'bx;
    matrix_size = 'bx;
    i_mat_idx = 'bx;
    w_mat_idx = 'bx;

    force clk = 0;
    
    #CYCLE; rst_n = 0; 
    #CYCLE; rst_n = 1;
    
    if(out_valid !== 1'b0 || out_value !=='b0) begin
        $display("************************************************************");    
        $display("*  Output signal should be 0 after initial RESET  at %8t   *",$time);
        $display("************************************************************");
        $finish;
    end
    #CYCLE; release clk;
end endtask

task input_task; begin
	a = $fscanf(f_input, "%d", i);
	a = $fscanf(f_idx, "%d", i);
	a = $fscanf(f_ans, "%d", i);
	repeat($urandom_range(1, 1)) @(negedge clk);
	in_valid = 'b1;

	a = $fscanf(f_input, "%d", mat_size);
	case (mat_size)
	2:  matrix_size = 0;
	4:  matrix_size = 1;
	8:  matrix_size = 2;
	endcase

	for (k = 0; k < 16; k = k+1) begin
		for (i = 0; i < mat_size; i = i+1)
			for (j = 0; j < mat_size; j = j+1) begin
                a = $fscanf(f_input, "%d", matrix_temp); // x
                for (b = 15; b >= 0; b = b-1) begin
                    matrix = matrix_temp[b];
                    @(negedge clk);
                    matrix_size = 'dx;
	            end
            end
	end
	for (k = 0; k < 16; k = k+1) begin
		for (i = 0; i < mat_size; i = i+1)
			for (j = 0; j < mat_size; j = j+1) begin
                a = $fscanf(f_input, "%d", matrix_temp); // x
                for (b = 15; b >= 0; b = b-1) begin
                    matrix = matrix_temp[b];
                    @(negedge clk);
                    matrix_size = 'dx;
	            end
            end
	end

	in_valid = 'b0;
	matrix = 'bx;
	@(negedge clk);
end endtask

task input2_task; begin
	in_valid2 = 'b1;
	a = $fscanf(f_idx, "%d", i_mat_idx_temp);
	a = $fscanf(f_idx, "%d", w_mat_idx_temp);
    for (b = 3; b >= 0; b = b-1) begin
        i_mat_idx = i_mat_idx_temp[b];
        w_mat_idx = w_mat_idx_temp[b];
        @(negedge clk);
    end
	in_valid2 = 'b0;
	i_mat_idx = 'dx;
	w_mat_idx = 'dx;
end endtask

task wait_out_valid_task; begin
    latency = 0;
    while(out_valid !== 1'b1) begin
        if(latency == 2000) begin
            $display("********************************************************");
            $display("*  The execution latency are over 2000 cycles  at %8t   *",$time);//over max
            $display("********************************************************");
            $finish;
        end
        latency = latency + 1;
        @(negedge clk);
    end
	total_latency = total_latency + latency;
	total_total_latency = total_total_latency + latency;
end endtask

task check_ans_task; begin
	out_cnt = 0;
	while (out_valid === 'b1) begin
        a = $fscanf(f_ans, "%d", gold_ans);
        gold_num_bit = 1;
        for (i = 1; i < 40; i=i+1)
            if (gold_ans[i]) gold_num_bit = i+1;
        out_length_task;
        out_number_task;
		out_cnt = out_cnt + 1;

		if (out_cnt > 2*mat_size-1) begin
			$display("********************************************************");    
            $display("*     out_valid and out must be %3d numbers  at %8t   *",2*mat_size-1, $time);//over max
            $display("*          Your out_valid numbers count: %3d          *",out_cnt);//over max
            $display("********************************************************");
            $finish;
		end
	end
	if (out_cnt < 2*mat_size-1) begin
		$display("********************************************************");    
		$display("*     out_valid and out must be %3d numbers  at %8t   *",2*mat_size-1, $time);//over max
		$display("*          Your out_valid numbers count: %3d          *",out_cnt);//over max
		$display("********************************************************");
		$finish;
	end

end endtask

task out_length_task; begin
    b = 6;
    while (out_valid === 'b1 && b > 0) begin
        out_num_bit[b-1] = out_value;
        b = b-1;
        @(negedge clk);
    end
    if (b !== 0) begin
        $display("********************************************************");    
        $display("*               Output not finish  at %8t   *",$time);//over max
        $display("*            Message from out_length_task          *");//over max
        $display("********************************************************");
        $finish;
    end
    if (out_num_bit !== gold_num_bit) begin
        $display("********************************************************");    
        $display("*               Wrong answer                at %8t    *",$time);//over max
        $display("*      Your length: %d,  Golden length: %d    *",out_num_bit, gold_num_bit);//over max
        $display("********************************************************");
        $finish;
    end
end endtask

task out_number_task; begin
    b = gold_num_bit;
    out_ans = 0;
    while (out_valid === 'b1 && b > 0) begin
        out_ans[b-1] = out_value;
        b = b-1;
        @(negedge clk);
    end
    if (b !== 0) begin
        $display("********************************************************");    
        $display("*               Output not finish  at %8t   *",$time);//over max
        $display("*            Message from out_number_task          *");//over max
        $display("********************************************************");
        $finish;
    end
    if (out_ans !== gold_ans) begin
        $display("********************************************************");    
        $display("*               Wrong answer                at %8t    *",$time);//over max
        $display("*      Your out: %d,  Golden out: %d    *",out_ans, gold_ans);//over max
        $display("********************************************************");
        $finish;
    end
end endtask

task YOU_PASS_task; begin
    $display ("--------------------------------------------------------------------");
    $display ("                         Congratulations!                           ");
    $display ("                  You have passed all patterns!                     ");
    $display ("                  Your execution cycles = %8d cycles              ", total_total_latency);
	$display ("                  Your clock period = %.1f ns                     ", CYCLE);
	$display ("                  Your total latency = %.1f ns                    ", total_total_latency * CYCLE);
    $display ("--------------------------------------------------------------------");        
    $finish;
end endtask

always @(negedge clk) begin
    if (out_valid === 0 && out_value !== 0) begin
        $display("********************************************************");   
        $display("*    out should be reset when out_valid is low   at %8t   *",$time);//over max
        $display("********************************************************");
        $finish;
    end
end

always @(negedge clk) begin
    if (out_valid === 1 && (in_valid === 1 || in_valid2 === 1)) begin
        $display("********************************************************");   
        $display("* out_valid cannot overlap with in_valid and in_valid2 at %8t   *",$time);//over max
        $display("********************************************************");
        $finish;
    end
end


endmodule