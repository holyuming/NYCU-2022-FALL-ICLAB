//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//      (C) Copyright NCTU OASIS Lab      
//            All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2022 ICLAB fall Course
//   Lab05			: SRAM, Matrix Multiplication with Systolic Array
//   Author         : Jia Fu-Tsao (jiafutsao.ee10g@nctu.edu.tw)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : TESTBED.v
//   Module Name : TESTBED
//   Release version : v1.0
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
`ifdef RTL
	`timescale 1ns/10ps
	`include "MMSA.v"
	`define CYCLE_TIME 6.7
`endif
`ifdef GATE
	`timescale 1ns/10ps
	`include "MMSA_SYN.v"
	`define CYCLE_TIME 6.7
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
    integer patnum;
    integer pat_i, pat_j, i, j, k, a, b, t;
    integer data_len, m_size;
    integer latency, total_latency;
    integer ans_len, output_cycle_cnt;
    integer f_in, f_ans;
    integer m_size_real;
    integer choose_x;
    integer choose_w;

    //================================================================
    //   INPUT AND OUTPUT DECLARATION                         
    //================================================================
    output reg 		  clk, rst_n, in_valid, in_valid2;
    output reg [15:0] matrix;
    output reg [1:0]  matrix_size;
    output reg [3:0]  i_mat_idx, w_mat_idx;

    input 				out_valid;
    input signed [39:0] out_value;
    //================================================================
    //    wires % registers
    //================================================================
    reg signed [15:0] x_matrix_reg [0:15][0:15][0:15];
    reg signed [15:0] w_matrix_reg [0:15][0:15][0:15];
    //================================================================
    //    clock
    //================================================================
    real CYCLE = `CYCLE_TIME;
    always #(CYCLE/2.0) clk = ~clk;

    //================================================================
    //    initial
    //================================================================
    initial begin
        clk = 0;
        rst_n = 1;
        in_valid = 0;
        in_valid2 = 0;
        total_latency = 0;

        f_in  = $fopen("../00_TESTBED/input.txt", "r");
        f_ans = $fopen("../00_TESTBED/ans.txt", "r");
        a = $fscanf(f_in, "%d", patnum);

        reset_task;
        for(pat_i=0; pat_i<patnum; pat_i=pat_i+1) begin
            input_task_1;
            for(pat_j=0; pat_j<16; pat_j=pat_j+1) begin
                input_task_2;
                weight_out_valid;
                check_ans_task;
                total_latency = total_latency + latency;
            end
            $display("--------------------------------------------------------------------------");
            repeat(2) @(negedge clk);
        end
        U_PASS_TASK;

    end

    always@(negedge clk) begin
        if(in_valid===1&&out_valid!==0) begin
            $display("=================================================");
            $display("          Out valid and in valid overlap         ");
            $display("=================================================");
            $finish;
        end

        if(in_valid2===1&&out_valid!==0) begin
            $display("=================================================");
            $display("          Out valid and in valid overlap         ");
            $display("=================================================");
            $finish;
        end

        if(out_valid===0&&out_valid!==0) begin
            $display("==============================================================");
            $display("          Out value should be 0 when out_valid is low         ");
            $display("==============================================================");
            $finish;
        end
    end

    task reset_task;
        begin
            force clk = 0;
			#CYCLE; rst_n = 0;
			#CYCLE; rst_n = 1;
			if(out_valid!==0 || out_value!==40'b0) begin
				$display("=====================");  
				$display("     RESET FAIL!     ");  
				$display("=====================");  
        		$finish;
			end
			#CYCLE; release clk;
		end
	endtask

    task input_task_1;
        integer matrix_cnt;
        integer row_cnt;
        integer col_cnt;

        begin
            @(negedge clk);
            in_valid   = 1;
            row_cnt    = 0;
            col_cnt    = 0;
            matrix_cnt = 0;

            a = $fscanf(f_in, "%d", m_size);
            a = $fscanf(f_in, "%d", data_len);
            a = $fscanf(f_ans, "%d", ans_len);

            case(m_size)
                0: m_size_real = 2;
                1: m_size_real = 4;
                2: m_size_real = 8;
                3: m_size_real = 16;
            endcase

            for(i=0;i<data_len;i=i+1) begin
                if(i==0)
                    matrix_size = m_size;
                else
                    matrix_size = 2'bx;
                a = $fscanf(f_in, "%d", matrix);
                if(matrix_cnt < 16) begin
                    x_matrix_reg[matrix_cnt][row_cnt][col_cnt] = matrix;
                end
                else begin
                    w_matrix_reg[matrix_cnt - 16][row_cnt][col_cnt] = matrix;
                end

                if((col_cnt == m_size_real-1) && (row_cnt == m_size_real-1))
                    matrix_cnt = matrix_cnt + 1;

                if(col_cnt == m_size_real-1) begin
                    col_cnt = 0;
                    if(row_cnt == m_size_real-1)
                        row_cnt = 0;
                    else
                        row_cnt = row_cnt + 1;
                end
                else begin
                    col_cnt =  col_cnt + 1;
                end

                @(negedge clk);
            end
            in_valid = 0;
            matrix = 16'bx;
            matrix_size = 2'bx;
        end
    endtask

    task input_task_2;
        begin
            @(negedge clk);
            in_valid2 = 1;
            a = $fscanf(f_in, "%d %d %d", b, i_mat_idx, w_mat_idx);
            choose_x = i_mat_idx;
            choose_w = w_mat_idx;
            @(negedge clk);
            in_valid2 = 0;
            i_mat_idx = 4'bx;
            w_mat_idx = 4'bx;
        end
    endtask

    task weight_out_valid;
		begin
			latency = 0;
			while(out_valid!==1) begin
				latency = latency + 1;
				if(latency > 2000) begin
					$display("==========================================");  
					$display("                   FAIL!                  ");  
					$display("         Latency OVER 2000 cycles         ");  
					$display("==========================================");  
					$finish;
				end
				@(negedge clk);
			end
		end
	endtask

    task check_ans_task;
        reg signed [39:0] golden_ans;
        begin
            a = $fscanf(f_ans, "%d", b);
            output_cycle_cnt = 0;
            while(out_valid === 1) begin
                output_cycle_cnt = output_cycle_cnt + 1;
                if(output_cycle_cnt > ans_len) begin
                    $display("\033[0;31m=============================================================================\033[m");
                    $display("\033[0;31m             out_valid shold be high in %2d cycles continuously              \033[m", ans_len);
                    $display("\033[0;31m=============================================================================\033[m");
                    $finish;
                end
                a = $fscanf(f_ans, "%d", golden_ans);
                if(golden_ans !== out_value) begin
                    $display("");
                    $display("\033[0;31m=========================================\033[m");
					$display("\033[0;31m             WRONG ANSWER !              \033[m");
					$display("\033[0;31m=========================================\033[m");
                    $display("");
					$display("\033[0;33m>>>> PATTERN %2d - %2d , at cycle %2d\033[m", pat_i, pat_j, output_cycle_cnt-1);
                    $display("");
					$display("     YOUR OUTPUT   : %d              ", out_value);
					$display("     GOLDEN ANSWER : %d              ", golden_ans);
                    $display("");
                    $display("--------------------------------------------------------------------------------------------------");
                    $display("\033[0;33m>>> X * W = \033[m");
                    $display("");
                    for(i=0;i<m_size_real;i=i+1) begin
                        for(j=0;j<m_size_real;j=j+1) begin
                            $write("\033[0;37m%6d \033[m", x_matrix_reg[choose_x][i][j]);
                        end
                        $write("                  ");
                        for(j=0;j<m_size_real;j=j+1) begin
                            $write("\033[0;37m%6d \033[m", w_matrix_reg[choose_w][i][j]);
                        end
                        $write("\n\n");
                    end
                    $display("");
                    $display("");
					$finish;
                end
                @(negedge clk);
            end
            $display("\033[0;36m PATTERN %2d\033[m - %2d \033[0;32mIS CORRECT !\033[m , \033[0;33mLatency = %2d\033[m", pat_i, pat_j, latency);
				
            if(output_cycle_cnt < ans_len) begin
                $display("\033[0;31m=============================================================================\033[m");
                $display("\033[0;31m             out_valid shold be high in %2d cycles continuously              \033[m", ans_len);
                $display("\033[0;31m=============================================================================\033[m");
                $finish;
            end
        end
    endtask

    task U_PASS_TASK;
		begin
			$display("");
			$display("");
			$display("\033[1;32m======================================================\033[m");
			$display("\033[0;32m                                                      \033[m");
			$display("\033[1;32m                  Simulation SUCCESS                  \033[m");
			$display("\033[0;32m                                                      \033[m");
			$display("\033[1;32m                YOU PASS ALL PATTERNS !               \033[m");
			$display("\033[0;32m                                                      \033[m");
			$display("\033[0;33m           Total Latency =  %d cycles                 \033[m", total_latency);
			$display("\033[0;32m                                                      \033[m");
			$display("\033[1;32m======================================================\033[m");
			$finish;
		end
	endtask

endmodule