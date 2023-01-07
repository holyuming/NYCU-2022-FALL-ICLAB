`include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype_FD.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

// global parameters
real CYCLE = 1; // 1ns
real SEED = 300;
integer PATNUM = 2_000;
integer patnum = 0;


// parameter
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";


// DRAM
logic [7:0] golden_DRAM [ ((65536+256*8)-1) : (65536+0) ];
initial $readmemh(DRAM_p_r, golden_DRAM);


// logic
logic if_needed;
Action action, previous_action;


// golden info
OUT_INFO    golden_info;
D_man_Info  gold_dman;
res_info    gold_res;
Error_Msg   gold_err_msg;
logic [63:0]    gold_out_info;
logic           gold_complete;
Delivery_man_id gold_dman_id, previous_gold_dman_id;
Restaurant_id   gold_rest_id, previous_gold_rest_id;

// info given to design
Ctm_Info            current_customer;
food_ID_servings    current_food_id_servings;

// check ans
integer total_ser_food;

// dram write or read
logic [16:0] addr;
logic [16:0] wb_addr;

// class
class random_value;
    rand Action             action;
    rand Customer_status    status;
    rand Delivery_man_id    dman_id;
    rand Restaurant_id      rest_id;
    rand Food_id            food_id;
    rand servings_of_food   ser_food;

    function new(int SEED);
        this.srandom(SEED);
    endfunction //new()

    constraint limit {
        action inside {Take, Order, Deliver, Cancel};
        status inside {Normal, VIP};
        dman_id inside {[0:255]};
        rest_id inside {[0:255]};
        food_id inside {FOOD1, FOOD2, FOOD3};
        ser_food inside {[1:15]};
    }
endclass //random_value



// class init
random_value    rand_val = new(SEED);


// start simulations
initial begin
    // reset
    reset_task;
    previous_action = Deliver; // deliver
    repeat(2) @(negedge clk);

    rand_val.randomize();
    for (patnum = 0 ; patnum < 60 ; patnum++) begin
        repeat($urandom_range(2, 10)) @(negedge clk);
        rand_val.randomize();
        // check assertion 7
        // repeat(11) @(negedge clk);
        // repeat(1) @(negedge clk);
        // cancel
        action = Cancel;
        // action valid
        inf.act_valid   = 1;
        inf.D.d_act[0]  = Cancel;
        @(negedge clk);
        inf.act_valid   = 0;
        inf.D           = 'dx;           
        repeat($urandom_range(1, 5)) @(negedge clk);
        // check assertion 40
        // nothing

        // restaurant valid
        inf.res_valid       = 1;
        gold_rest_id        = (patnum == 0) ? 38 : (patnum == 20) ? 99 : 0;
        inf.D.d_res_id[0]   = gold_rest_id;
        @(negedge clk);
        inf.res_valid   = 0;
        inf.D           = 'dx;
        repeat($urandom_range(1, 5)) @(negedge clk);
        
        // food valid
        inf.food_valid  = 1;    
        current_food_id_servings.d_food_ID    = (patnum == 20 || patnum == 0) ? FOOD2 : rand_val.food_id;
        current_food_id_servings.d_ser_food   = 4'd0;
        inf.D.d_food_ID_ser[0] = current_food_id_servings;
        @(negedge clk);
        inf.food_valid  = 0;
        inf.D           = 'dx;
        repeat($urandom_range(1, 5)) @(negedge clk);

        // deliverman valid
        inf.id_valid    = 1;
        gold_dman_id    = (patnum == 0) ? 6 : (patnum == 20) ? 1 : rand_val.dman_id;
        inf.D.d_id[0]   = gold_dman_id;
        @(negedge clk);
        inf.id_valid    = 0;
        inf.D           = 'dx;
        
        wait_output;
        check_ans;
        previous_action = action;
        // $display("\033[0;34mPASS PATTERN NO.%5d\033[m \033[0;32m\033[m", patnum);
    end


    for (patnum = patnum; patnum < PATNUM ; patnum++) begin

        repeat($urandom_range(2, 10)) @(negedge clk);
        // assertion 7
        // repeat(11) @(negedge clk);

        // give input
        gen_input;

        // wait out output
        wait_output;

        // check answer
        check_ans;

        // $display("\033[0;34mPASS PATTERN NO.%5d\033[m \033[0;32m\033[m", patnum);
        previous_action         = action;
    end

    @(posedge clk);
    $finish;
end


// tasks

// reset task
task reset_task;
    inf.rst_n       = 1'b1;

    inf.act_valid   = 1'bx;
    inf.res_valid   = 1'bx;
    inf.cus_valid   = 1'bx;
    inf.food_valid  = 1'bx;

    force clk = 0;

    #5; inf.rst_n = 0; 

    inf.act_valid   = 1'b0;
    inf.res_valid   = 1'b0;
    inf.cus_valid   = 1'b0;
    inf.food_valid  = 1'b0;
    inf.id_valid    = 1'b0;

    #5; inf.rst_n = 1;
    #5; release clk;
endtask

// generate input 
Customer_status status;
task gen_input;

    rand_val.randomize();
    action = rand_val.action;

    case (action)
        Take: begin // take

            // determine if_needed
            if_needed   = $urandom_range(0, 1);

            // action valid
            inf.act_valid   = 1;
            inf.D.d_act[0]  = Take;
            @(negedge clk);
            inf.act_valid   = 0;
            inf.D           = 'dx;
            repeat($urandom_range(1, 5)) @(negedge clk);

            // deliverman valid (if needed)
            // don't need to give input only when previous_action == Take && if_needed == 1
            if (!(previous_action === Take && if_needed === 1'b1)) begin // give new deliverman
                inf.id_valid    = 1'b1;
                gold_dman_id    = rand_val.dman_id;
                inf.D.d_id[0]   = gold_dman_id;
                @(negedge clk);
                inf.id_valid    = 1'b0;
                inf.D           = 'dx;
                repeat($urandom_range(1,5)) @(negedge clk);
            end

            // customer valid
            inf.cus_valid   = 1'b1;
            current_customer.ctm_status  = rand_val.status;
            current_customer.res_ID      = rand_val.rest_id;
            current_customer.food_ID     = rand_val.food_id;
            current_customer.ser_food    = rand_val.ser_food;
            inf.D.d_ctm_info[0] = current_customer;
            gold_rest_id        = rand_val.rest_id;
            @(negedge clk);
            inf.cus_valid   = 1'b0;
            inf.D           = 'dx;
        end 
        Order: begin // order 

            // determine if_needed
            if_needed   = $urandom_range(0, 1);

            // action valid
            inf.act_valid = 1;
            inf.D.d_act[0] = Order;
            @(negedge clk);
            inf.act_valid = 0;
            inf.D         = 'dx;  
            repeat($urandom_range(1, 5)) @(negedge clk);

            // restaurant id (if needed)
            if (!(previous_action === Order && if_needed === 1'b1)) begin // give restaurant id
                inf.res_valid       = 1;
                gold_rest_id        = rand_val.rest_id;
                inf.D.d_res_id[0]   = gold_rest_id;
                @(negedge clk);
                inf.res_valid   = 0;
                inf.D           = 'dx;
                repeat($urandom_range(1, 5)) @(negedge clk);
            end

            // food valid
            inf.food_valid  = 1;
            current_food_id_servings.d_food_ID    = rand_val.food_id;
            current_food_id_servings.d_ser_food   = rand_val.ser_food;
            inf.D.d_food_ID_ser[0] = current_food_id_servings;
            @(negedge clk);
            inf.food_valid  = 0;
            inf.D           = 'dx;
        end
        Deliver: begin // deliver

            // action valid
            inf.act_valid = 1;
            inf.D.d_act[0] = Deliver;
            @(negedge clk);
            inf.act_valid = 0;
            inf.D         = 'dx;  
            repeat($urandom_range(1, 5)) @(negedge clk);

            // deliverman valid
            inf.id_valid    = 1;
            gold_dman_id    = rand_val.dman_id;
            inf.D.d_id[0]   = gold_dman_id;
            @(negedge clk);
            inf.id_valid    = 0;
            inf.D           = 'dx;
        end
        Cancel: begin // cancel
            // action valid
            inf.act_valid   = 1;
            inf.D.d_act[0]  = Cancel;
            @(negedge clk);
            inf.act_valid   = 0;
            inf.D           = 'dx;           
            repeat($urandom_range(1, 5)) @(negedge clk);

            // restaurant valid
            inf.res_valid       = 1;
            gold_rest_id        = rand_val.rest_id;
            inf.D.d_res_id[0]   = gold_rest_id;
            @(negedge clk);
            inf.res_valid   = 0;
            inf.D           = 'dx;
            repeat($urandom_range(1, 5)) @(negedge clk);
            
            // food valid
            inf.food_valid  = 1;    
            current_food_id_servings.d_food_ID    = rand_val.food_id;
            current_food_id_servings.d_ser_food   = 4'd0;
            inf.D.d_food_ID_ser[0] = current_food_id_servings;
            @(negedge clk);
            inf.food_valid  = 0;
            inf.D           = 'dx;
            repeat($urandom_range(1, 5)) @(negedge clk);

            // deliverman valid
            inf.id_valid    = 1;
            gold_dman_id    = rand_val.dman_id;
            inf.D.d_id[0]   = gold_dman_id;
            @(negedge clk);
            inf.id_valid    = 0;
            inf.D           = 'dx;
        end
    endcase
endtask

// wait latency
task wait_output;
    @(negedge clk);
    while (inf.out_valid !== 1) begin
        @(negedge clk);
    end
endtask

// check ans
task check_ans;
    // check err msg
    gold_err_msg = No_Err;
    case (action)
        Take: begin
            gold_dman = GetDman(gold_dman_id); // if needed
            gold_res  = GetRes(gold_rest_id);

            if (gold_dman.ctm_info1.ctm_status !== None &&
            gold_dman.ctm_info2.ctm_status !== None) begin
                gold_err_msg = D_man_busy;
            end else begin
                case(current_customer.food_ID)
                    FOOD1: begin
                        if(gold_res.ser_FOOD1 < current_customer.ser_food) begin
                            gold_err_msg = No_Food;
                        end else begin // no_err
                            gold_err_msg = No_Err;
                            gold_res.ser_FOOD1 = gold_res.ser_FOOD1 - current_customer.ser_food;

                            // dman empty
                            if (gold_dman.ctm_info1.ctm_status === None)
                                gold_dman.ctm_info1 = current_customer;

                            // dman has only 1 customer
                            else begin
                                if (current_customer.ctm_status > gold_dman.ctm_info1.ctm_status) begin
                                    gold_dman.ctm_info2 = gold_dman.ctm_info1;
                                    gold_dman.ctm_info1 = current_customer;
                                end else begin
                                    gold_dman.ctm_info2 = current_customer;
                                end
                            end
                        end
                    end 
                    FOOD2: begin
                        if(gold_res.ser_FOOD2 < current_customer.ser_food) begin
                            gold_err_msg = No_Food;
                        end else begin // no_err
                            gold_err_msg = No_Err;
                            gold_res.ser_FOOD2 = gold_res.ser_FOOD2 - current_customer.ser_food;

                            // dman empty
                            if (gold_dman.ctm_info1.ctm_status === None)
                                gold_dman.ctm_info1 = current_customer;

                            // dman has only 1 customer
                            else begin
                                if (current_customer.ctm_status > gold_dman.ctm_info1.ctm_status) begin
                                    gold_dman.ctm_info2 = gold_dman.ctm_info1;
                                    gold_dman.ctm_info1 = current_customer;
                                end else begin
                                    gold_dman.ctm_info2 = current_customer;
                                end
                            end
                        end
                    end
                    FOOD3: begin
                        if(gold_res.ser_FOOD3 < current_customer.ser_food) begin
                            gold_err_msg = No_Food;
                        end else begin // no_err
                            gold_err_msg = No_Err;
                            gold_res.ser_FOOD3 = gold_res.ser_FOOD3 - current_customer.ser_food;

                            // dman empty
                            if (gold_dman.ctm_info1.ctm_status === None)
                                gold_dman.ctm_info1 = current_customer;

                            // dman has only 1 customer
                            else begin
                                if (current_customer.ctm_status > gold_dman.ctm_info1.ctm_status) begin
                                    gold_dman.ctm_info2 = gold_dman.ctm_info1;
                                    gold_dman.ctm_info1 = current_customer;
                                end else begin
                                    gold_dman.ctm_info2 = current_customer;
                                end
                            end
                        end
                    end
                endcase
            end
        end 
        Order: begin
            gold_res  = GetRes(gold_rest_id); // if needed
            total_ser_food = current_food_id_servings.d_ser_food + gold_res.ser_FOOD1 + gold_res.ser_FOOD2 + gold_res.ser_FOOD3;
            
            if (total_ser_food > gold_res.limit_num_orders) begin
                gold_err_msg = Res_busy;
            end else begin
                gold_err_msg = No_Err;          
                case (current_food_id_servings.d_food_ID)
                    FOOD1: gold_res.ser_FOOD1 = gold_res.ser_FOOD1 + current_food_id_servings.d_ser_food;
                    FOOD2: gold_res.ser_FOOD2 = gold_res.ser_FOOD2 + current_food_id_servings.d_ser_food;
                    FOOD3: gold_res.ser_FOOD3 = gold_res.ser_FOOD3 + current_food_id_servings.d_ser_food;
                endcase
            end
        end
        Deliver: begin
            gold_dman = GetDman(gold_dman_id);
            if (gold_dman.ctm_info1.ctm_status === None &&
            gold_dman.ctm_info2.ctm_status === None) begin
                gold_err_msg = No_customers;
            end else begin // no_err
                gold_err_msg = No_Err;
                gold_dman.ctm_info1 = gold_dman.ctm_info2;
                gold_dman.ctm_info2 = 0;
            end
        end
        Cancel: begin
            gold_dman = GetDman(gold_dman_id);

            // dman emtpy
            if (gold_dman.ctm_info1.ctm_status === None &&
            gold_dman.ctm_info2.ctm_status === None) begin
                gold_err_msg = Wrong_cancel;
            end 
            // dman has only 1 customer
            else if (gold_dman.ctm_info1.ctm_status !== None && gold_dman.ctm_info2.ctm_status === None) begin
                if (gold_rest_id === 0) begin
                    if (gold_dman.ctm_info1.res_ID === 0 && gold_dman.ctm_info1.food_ID === current_food_id_servings.d_food_ID) begin // cancel
                        gold_err_msg = No_Err;
                        gold_dman.ctm_info1 = 0;
                        gold_dman.ctm_info2 = 0;
                    end else begin 
                        gold_err_msg = Wrong_food_ID;
                    end
                end else begin
                    if (gold_dman.ctm_info1.res_ID !== gold_rest_id)
                        gold_err_msg = Wrong_res_ID;
                    else if (gold_dman.ctm_info1.food_ID !== current_food_id_servings.d_food_ID)
                        gold_err_msg = Wrong_food_ID;
                    else begin
                        gold_err_msg = No_Err;
                        gold_dman.ctm_info1 = 0;
                        gold_dman.ctm_info2 = 0;
                    end
                end
            end
            // dman has 2 customers
            else if (gold_dman.ctm_info1.ctm_status !== None && gold_dman.ctm_info2.ctm_status !== None) begin
                // wrong res id
                if (gold_dman.ctm_info1.res_ID !== gold_rest_id && gold_dman.ctm_info2.res_ID !== gold_rest_id) begin
                    gold_err_msg = Wrong_res_ID;
                end
                // no_err
                else if ((gold_dman.ctm_info1.res_ID === gold_rest_id && gold_dman.ctm_info1.food_ID === current_food_id_servings.d_food_ID) ||
                (gold_dman.ctm_info2.res_ID === gold_rest_id && gold_dman.ctm_info2.food_ID === current_food_id_servings.d_food_ID)) begin 
                    gold_err_msg = No_Err;
                    // at least one customer has to be canceled
                    // only customer 1 is canceled
                    if ((gold_dman.ctm_info1.food_ID === current_food_id_servings.d_food_ID && gold_dman.ctm_info1.res_ID === gold_rest_id) &&
                    (gold_dman.ctm_info2.food_ID !== current_food_id_servings.d_food_ID || gold_dman.ctm_info2.res_ID !== gold_rest_id)) begin
                        gold_dman.ctm_info1 = gold_dman.ctm_info2;
                        gold_dman.ctm_info2 = 0;
                    end
                    // only customer 2 is canceled
                    else if ((gold_dman.ctm_info1.food_ID !== current_food_id_servings.d_food_ID || gold_dman.ctm_info1.res_ID !== gold_rest_id) &&
                    (gold_dman.ctm_info2.food_ID === current_food_id_servings.d_food_ID && gold_dman.ctm_info2.res_ID === gold_rest_id)) begin
                        gold_dman.ctm_info2 = 0;
                    end
                    // both being canceled
                    else if (gold_dman.ctm_info1.food_ID === current_food_id_servings.d_food_ID && gold_dman.ctm_info1.res_ID === gold_rest_id &&
                    gold_dman.ctm_info2.food_ID === current_food_id_servings.d_food_ID && gold_dman.ctm_info2.res_ID === gold_rest_id) begin
                        gold_dman.ctm_info1 = 0;
                        gold_dman.ctm_info2 = 0;
                    end
                end
                // wrong food id
                else begin
                    gold_err_msg = Wrong_food_ID;
                end
            end
        end
    endcase

    // check err msg
    if (gold_err_msg !== inf.err_msg) begin
        $display("Wrong Answer");
        $finish;
    end

    // check out info
    if (gold_err_msg === No_Err) begin
        case (action)
            Take    : gold_out_info = {gold_dman, gold_res}; 
            Order   : gold_out_info = {32'd0, gold_res};
            Deliver : gold_out_info = {gold_dman, 32'd0};
            Cancel  : gold_out_info = {gold_dman, 32'd0};
        endcase
    end else begin
        gold_out_info = 64'd0;
    end

    if (inf.out_info !== gold_out_info) begin
        $display("Wrong Answer");
        $finish;
    end

    // check complete
    gold_complete = (gold_err_msg !== No_Err) ? 0 : 1;
    if (inf.complete !== gold_complete) begin
        $display("Wrong Answer");
        $finish;
    end

    // wb res
    if (action == Take || action == Order) begin
        wb_addr = 'h10000 + {gold_rest_id, 3'b000};
        golden_DRAM[wb_addr + 0] = gold_res.limit_num_orders;
        golden_DRAM[wb_addr + 1] = gold_res.ser_FOOD1;
        golden_DRAM[wb_addr + 2] = gold_res.ser_FOOD2;
        golden_DRAM[wb_addr + 3] = gold_res.ser_FOOD3;
    end

    // wb dman
    if (action == Take || action == Deliver || action == Cancel) begin
        wb_addr = 'h10000 + {gold_dman_id, 3'b000};
        golden_DRAM[wb_addr + 4] = gold_dman[31:24];
        golden_DRAM[wb_addr + 5] = gold_dman[23:16];
        golden_DRAM[wb_addr + 6] = gold_dman[15:8];
        golden_DRAM[wb_addr + 7] = gold_dman[7:0];
    end

endtask


// functions
// GetDman
function D_man_Info GetDman (
    input Delivery_man_id dman_id
);
logic [16:0] addr;
addr = 'h10000 + {dman_id, 3'b000};

GetDman = {golden_DRAM[addr+4], golden_DRAM[addr+5], golden_DRAM[addr+6], golden_DRAM[addr+7]};
    
endfunction

// GetRes
function res_info GetRes (
    input Restaurant_id res_id
);
logic [16:0] addr;
addr = 'h10000 + {res_id, 3'b000};
GetRes = {golden_DRAM[addr], golden_DRAM[addr+1], golden_DRAM[addr+2], golden_DRAM[addr+3]};

endfunction


endprogram