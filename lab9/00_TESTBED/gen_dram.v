module GEN_DRAM ();

//===================
//      PARAMETER
//===================
// RES, DMAN
parameter START_ADDR = 'h10000;
parameter NUM_ID     = 'd512; // 64 x 64


//===================
//      VARIABLE
//===================
integer addr;
integer seed = 'd123;

integer food1;
integer food2;
integer food3;
integer order1, order2, order;

integer a,b;
integer status1, status2;
integer restaurant1, restaurant2;
integer food_id1, food_id2;
integer food_num1, food_num2;

integer file;

integer state;
initial begin
	state = 0;
    file = $fopen("../00_TESTBED/DRAM/dram.dat","w");

    for(addr=START_ADDR; addr<START_ADDR+'h4*NUM_ID; addr=addr+'h4) begin
		$fwrite(file, "@%5h\n", addr);
		if(state==0) begin
			food1 = {$random(seed)}%'d80;
			food2 = {$random(seed)}%'d80;
			food3 = {$random(seed)}%'d80;
			order1 = {$random(seed)}%'d15+food1+food2+food3;
			order2 = {$random(seed)}%'d256;
			order  = (order2>order1)? order2: order1;
			
			$fwrite(file, "%h ", order[7:0]);
			$fwrite(file, "%h ", food1[7:0]);
			$fwrite(file, "%h ", food2[7:0]);
			$fwrite(file, "%h\n", food3[7:0]);
			state = 1;
		end
		else begin
			a = {$random(seed)} % 'd3;
			if(a==0) begin
				status1 = 'd0;
				restaurant1 = 'd0;
				food_id1 = 'd0;
				food_num1 = 'd0;
				status2 = 'd0;
				restaurant2 = 'd0;
				food_id2 = 'd0;
				food_num2 = 'd0;
				
				$fwrite(file, "%h ", {status1[1:0], restaurant1[7:2]});
				$fwrite(file, "%h ", {restaurant1[1:0], food_id1[1:0], food_num1[3:0]});
				$fwrite(file, "%h ", {status2[1:0], restaurant2[7:2]});
				$fwrite(file, "%h\n", {restaurant2[1:0], food_id2[1:0], food_num2[3:0]});
			end
			else if(a==1) begin
				status1 = {$random(seed)}%'h2;
				status1 = (status1==1)? 'd1: 'd3;
				restaurant1 = {$random(seed)};
				food_id1 = {$random(seed)}%'h3;
				food_num1 = {$random(seed)};
				status2 = 'd0;
				restaurant2 = 'd0;
				food_id2 = 'd0;
				food_num2 = 'd0;
				
				$fwrite(file, "%h ", {status1[1:0], restaurant1[7:2]});
				$fwrite(file, "%h ", {restaurant1[1:0], food_id1[1:0], food_num1[3:0]});
				$fwrite(file, "%h ", {status2[1:0], restaurant2[7:2]});
				$fwrite(file, "%h\n", {restaurant2[1:0], food_id2[1:0], food_num2[3:0]});
			end
			else begin
				b = {$random(seed)} % 'd3;
				if(b==0) begin
					status1 = 'h3;
					status2 = 'h3;
				end
				else if(b==1) begin
					status1 = 'h3;
					status2 = 'h1;
				end
				else begin
					status1 = 'h1;
					status2 = 'h1;
				end
				restaurant1 = {$random(seed)};
				food_id1 = {$random(seed)}%'h3;
				food_num1 = {$random(seed)};
				restaurant2 = {$random(seed)};
				food_id2 = {$random(seed)}%'h3;
				food_num2 = {$random(seed)};
				
				$fwrite(file, "%h ", {status1[1:0], restaurant1[7:2]});
				$fwrite(file, "%h ", {restaurant1[1:0], food_id1[1:0], food_num1[3:0]});
				$fwrite(file, "%h ", {status2[1:0], restaurant2[7:2]});
				$fwrite(file, "%h\n", {restaurant2[1:0], food_id2[1:0], food_num2[3:0]});
			end
			state = 0;
		end
    end
    $fclose(file);

end

endmodule

