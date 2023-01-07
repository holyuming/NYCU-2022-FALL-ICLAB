`ifdef RTL
`define CYCLE_TIME 15
`endif
`ifdef GATE
`define CYCLE_TIME 15
`endif
`ifdef APR
`define CYCLE_TIME 15
`endif
`ifdef POST
`define CYCLE_TIME 20
`endif

module PATTERN #(parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32)(
    // output signal
	clk            ,	
	clk2		   ,
	rst_n          ,	
	in_valid       ,
    op_valid       ,	
	op             ,	
	pic_data       ,	  
	se_data        ,	  
	// input signal
	out_valid      ,
	out_data
);

output reg clk, clk2, rst_n, in_valid, op_valid;
output reg [2:0] op;
output reg [31:0] pic_data;
output reg [7:0] se_data;

input wire out_valid;
input wire [31:0] out_data;

real CYCLE = `CYCLE_TIME;
//================================================================
// clock
//================================================================
initial begin
	clk = 0;
	clk2 = 0;
end
always #(CYCLE/2.0) begin
	clk = ~clk; 
	clk2 = ~clk2;
end

//================================================================
// initial
//================================================================
integer i, j, k, kk, latency, temp1, temp2, patnum, total_latency, op_valid_delay;
integer SEED = 123;
integer PATNUM = 100;

reg [7:0] IMAGE [0:34][0:34];
reg [7:0] SE [0:3][0:3];
reg [7:0] SE_inv [0:3][0:3];
reg [7:0] temp [0:3][0:3];
reg [7:0] minn, maxx;
reg [12:0] accumulation [0:255];
integer cdf_min, son, mom;
reg [2:0] op_reg;

always@(*) begin
	if(in_valid === 1'b1 && out_valid == 1'b1) begin
		$display("**************************************************************");
		$display("*   Out_valid should not be raised when In_valid is high     *");
		$display("**************************************************************");
		$finish;
	end
end

always@(negedge clk) begin
	if(out_data !== 32'b0 && out_valid === 1'b0) begin
		$display("**************************************************************");
		$display("*  Out_data is not zero when Out_valid has not been raised   *");
		$display("**************************************************************");
		$finish;
	end
end

initial begin	
	cdf_min = 255;
	in_valid = 1'b0;
	op_valid = 1'b0;
	op = 3'bx;
	pic_data = 32'bx;
	se_data = 8'bx;
	
	reset_signal_task;

	repeat(20) @(negedge clk);

	initial_image;
	total_latency = 0;
	for(patnum=0; patnum<PATNUM; patnum=patnum+1) begin
		initial_image;
		INPUT_TASK;
		
		case(op_reg)
			3'b010:	compute_erosion;
			3'b011:	compute_dilation;
			3'b000:	compute_histogram;
			3'b110:	begin 
				compute_erosion; 
				compute_dilation; 
			end
			3'b111:	begin 
				compute_dilation; 
				compute_erosion; 
			end
			default: begin
				$display("Undefined Operation!");
				$finish;
			end
		endcase

		latency = 0;
		while(out_valid !== 1'b1) begin
			@(negedge clk);
			latency = latency + 1;
			if(latency>10000) begin
			    $display("--------------------------------------------------\n");
				$display("          PATNUM %d FAIL!\n                         ", patnum);
				case(op_reg)
					3'b010:$display("     op:%b => EROSION  operation!\n    ", op_reg);
					3'b011:$display("     op:%b => DILATION operation!\n    ", op_reg);
					3'b000:$display("     op:%b => HISTOGRAM  operation!\n  ", op_reg);
					3'b110:$display("     op:%b => OPENING  operation!\n    ", op_reg);
					3'b111:$display("     op:%b => CLOSING  operation!\n    ", op_reg);
			    endcase
				$display("      Latency longer than 10000 cycles !         \n");
				$display("--------------------------------------------------\n");
				$finish;
			end
		end
		total_latency = total_latency + latency;
		compare_answer;
	end
	YOU_PASS_task;
	$finish;
end

task INPUT_TASK; begin
	repeat(1) @(negedge clk);
	in_valid = 1'b1;
  
	op_valid_delay = $random(SEED) % 'd16; 
	op_valid = 1'b0;
  
	for(i=0; i<32; i=i+1) begin
		for(j=0; j<8; j=j+1) begin
			for(k=0; k<4; k=k+1) begin
				IMAGE[i][j*4+k] = $random(SEED) % 'd256;   
			end
			pic_data = {IMAGE[i][j*4+3],IMAGE[i][j*4+2],IMAGE[i][j*4+1],IMAGE[i][j*4]};
			if(i<2) begin
				if(patnum%5 == 0)
					se_data = 0;
				else if(patnum%19 == 0)
					se_data = 255;
				else
					se_data = $random(SEED) % 'd16;
					
				SE[(i*8+j)/4][(i*8+j)%4] = se_data;
			end 
			else begin
				se_data = 8'bx;
			end
				
			if(i*8+j == op_valid_delay) begin
				op_valid = 1'b1;
				// op = 7;
				op = $random(SEED) % 'd8;
				op_reg = op;
				while (op === 'd1 || op === 'd4 || op === 'd5) begin
					op = $random(SEED) % 'd8;
					op_reg = op;
				end
			end 
			else begin
				op_valid = 1'b0;
				op = 3'bx;
			end
		@(negedge clk);
		end
	end
	in_valid = 1'b0;
	pic_data = 8'bx;
end endtask

task initial_image; begin
	for(i=0; i<35; i=i+1) begin
		for(j=0; j<35; j=j+1) begin
			IMAGE[i][j] = 0;
		end
	end
end endtask

task compute_erosion; begin
	for(i=0; i<32; i=i+1) begin
		for(j=0; j<32; j=j+1) begin
			for(k=0; k<4; k=k+1) begin
				for(kk=0; kk<4; kk=kk+1) begin
					if(IMAGE[i+k][j+kk] < SE[k][kk])
						temp[k][kk] = 0;
					else
						temp[k][kk] = IMAGE[i+k][j+kk] - SE[k][kk];
				end
			end
			minn = 255;
			for(k=0; k<4; k=k+1) begin
				for(kk=0; kk<4; kk=kk+1) begin
					if(minn > temp[k][kk])
						minn = temp[k][kk];
				end
			end
			IMAGE[i][j]=minn;
		end
	end
end endtask

task compute_dilation; begin
	for(k=0; k<4; k=k+1) begin
		for(kk=0; kk<4; kk=kk+1) begin
			SE_inv[k][kk] = SE[3-k][3-kk];
		end
	end
			
	for(i=0; i<32; i=i+1) begin
		for(j=0; j<32; j=j+1) begin
			for(k=0; k<4; k=k+1) begin
				for(kk=0; kk<4; kk=kk+1) begin
					if(IMAGE[i+k][j+kk] + SE_inv[k][kk] > 255)
						temp[k][kk] = 255;
					else
						temp[k][kk] = IMAGE[i+k][j+kk] + SE_inv[k][kk];
				end
			end
			maxx = 0;
			for(k=0; k<4; k=k+1) begin
				for(kk=0; kk<4; kk=kk+1) begin
					if(maxx < temp[k][kk])
						maxx = temp[k][kk];
				end
			end
			IMAGE[i][j]=maxx;
		end
	end
end endtask


task compute_histogram; begin
	for(k=0; k<256; k=k+1) begin
		accumulation[k] = 0;
	end
	
	cdf_min = 255;
	
	for(i=0; i<32; i=i+1) begin
		for(j=0; j<32; j=j+1) begin
			for(k=0; k<256; k=k+1) begin
				if(IMAGE[i][j] <= k)
					accumulation[k] = accumulation[k] + 1;
			end
			if(IMAGE[i][j] < cdf_min)
				cdf_min = IMAGE[i][j];
		end
	end
	
	for(i=0; i<32; i=i+1) begin
		for(j=0; j<32; j=j+1) begin
			son = (accumulation[IMAGE[i][j]] - accumulation[cdf_min]) * 255;
			mom = 1024 - accumulation[cdf_min];
			if(mom == 0)
				IMAGE[i][j] = 255;
			else
				IMAGE[i][j] = son / mom;
		end
	end
end endtask

task compare_answer; begin
    for(i=0; i<32; i=i+1) begin
		for(j=0; j<8; j=j+1) begin
			if(out_valid !== 1'b1) begin
				$display("-----------------------------------------------\n");
				$display("          PATNUM %d FAIL!\n               ", patnum);
				case(op_reg)
					3'b010:$display("     op:%b => EROSION  operation!\n    ", op_reg);
					3'b011:$display("     op:%b => DILATION operation!\n    ", op_reg);
					3'b000:$display("     op:%b => HISTOGRAM  operation!\n  ", op_reg);
					3'b110:$display("     op:%b => OPENING  operation!\n    ", op_reg);
					3'b111:$display("     op:%b => CLOSING  operation!\n    ", op_reg);
				endcase
				$display("     out_valid less than 256 cycles ! \n        ");
				$display("-----------------------------------------------\n");
				$finish;
			end 
			else if({IMAGE[i][j*4+3], IMAGE[i][j*4+2], IMAGE[i][j*4+1], IMAGE[i][j*4]} !== out_data) begin
				$display("-----------------------------------------------\n");
				$display("          PATNUM %d FAIL!\n               ", patnum);
				case(op_reg)
					3'b010:$display("     op:%b => EROSION  operation!\n    ", op_reg);
					3'b011:$display("     op:%b => DILATION operation!\n    ", op_reg);
					3'b000:$display("     op:%b => HISTOGRAM  operation!\n  ", op_reg);
					3'b110:$display("     op:%b => OPENING  operation!\n    ", op_reg);
					3'b111:$display("     op:%b => CLOSING  operation!\n    ", op_reg);
				endcase
				$display("          Position: Picture[%3d][%2d~%2d]          \n", i, j*4+3, j*4);
				$display("Correct Answer: %h, Your Answer: %h \n", {IMAGE[i][j*4+3], IMAGE[i][j*4+2], IMAGE[i][j*4+1], IMAGE[i][j*4]}, out_data);
				$display("-----------------------------------------------\n");
				$finish;
			end 
			@(negedge clk);
		end
	end
	if(out_valid !== 0) begin
		$display("-----------------------------------------------\n");
		$display("          PATNUM %d FAIL!\n               ", patnum);
		case(op_reg)
			3'b010:$display("     op:%b => EROSION  operation!\n    ", op_reg);
			3'b011:$display("     op:%b => DILATION operation!\n    ", op_reg);
			3'b000:$display("     op:%b => HISTOGRAM  operation!\n  ", op_reg);
			3'b110:$display("     op:%b => OPENING  operation!\n    ", op_reg);
			3'b111:$display("     op:%b => CLOSING  operation!\n    ", op_reg);
		endcase
		$display("     out_valid More than 256 cycles ! \n        ");  
		$display("-----------------------------------------------\n");
		$finish;
	end
	case(op_reg)
	  3'b010:$display("\033[0;34mPASS num_iteration:%4d,\033[m \033[0;38;5;219m EROSION   operation, \033[m \033[0;38;5;150m execution cycle : %3d \033[m ",patnum, latency);
	  3'b011:$display("\033[0;34mPASS num_iteration:%4d,\033[m \033[0;38;5;219m DILATION  operation, \033[m \033[0;38;5;150m execution cycle : %3d \033[m ",patnum, latency);
	  3'b000:$display("\033[0;34mPASS num_iteration:%4d,\033[m \033[0;38;5;219m HISTOGRAM operation, \033[m \033[0;38;5;150m execution cycle : %3d \033[m ",patnum, latency);
	  3'b110:$display("\033[0;34mPASS num_iteration:%4d,\033[m \033[0;38;5;219m OPENING   operation, \033[m \033[0;38;5;150m execution cycle : %3d \033[m ",patnum, latency);
	  3'b111:$display("\033[0;34mPASS num_iteration:%4d,\033[m \033[0;38;5;219m CLOSING   operation, \033[m \033[0;38;5;150m execution cycle : %3d \033[m ",patnum, latency);
    endcase
end endtask

task reset_signal_task; begin

	force clk = 0;
	force clk2 = 0;
	
	rst_n = 1;
	
	repeat(100) #(CYCLE) rst_n = 0;
	#(CYCLE/2.0) rst_n = 1;
	
	if(out_valid !== 0 || out_data !== 0) begin
		$display("**************************************************************");
		$display("*   Output should be 0 after initial RESET at %4t     *", $time);
		$display("**************************************************************");
		repeat(5) #(CYCLE);
		$finish;
	end
	
	#(CYCLE/2.0);  release clk;
	#(CYCLE/2.0);  release clk2;
	
end endtask

task YOU_PASS_task; begin
	$display ("--------------------------------------------------------------------");
	$display ("                         Congratulations!                           ");
	$display ("                  You have passed all patterns!                     ");
	$display ("                    Total Latency: %d                           ", total_latency); 
	$display ("--------------------------------------------------------------------");        
	#(500);
	$finish;
end endtask

endmodule

