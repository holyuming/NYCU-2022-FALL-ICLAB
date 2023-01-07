module FD(input clk, INF.FD_inf inf);
import usertype::*;

//===========================================================================
// parameter 
//===========================================================================
typedef enum logic [3:0] { 
    IDLE, 
    DRAM_A_D_MAN, 
    DRAM_D_MAN, 
    DRAM_A_RES, 
    DRAM_RES, 
    CAL,  
    WB_A_D_MAN,
    WB_D_MAN,
    WB_A_RES,
    WB_RES,
    OUT 
} FD_state;

//===========================================================================
// logic 
//===========================================================================
// fsm
FD_state c_state, n_state;

// store input
Action              action,     n_action;
Delivery_man_id     d_man_id,   n_d_man_id;
Restaurant_id       res_id,     n_res_id;
food_ID_servings    fd_id_s,    n_fd_id_s;
Ctm_Info            cus_info,   n_cus_info;

// data from dram
logic [63:0]  revised_dram_data;
OUT_INFO gold_info, n_gold_info;

// write back data
OUT_INFO wb_data,       n_wb_data;
OUT_INFO og_dman_data,  n_og_dman_data;
OUT_INFO og_res_data,   n_og_res_data;

// cal
logic [8:0] total_ser_food;
logic [7:0] res_addr, dman_addr;

// output
logic n_out_valid, n_complete;
logic n_C_in_valid;
logic n_C_r_wb;
logic [7:0]     n_C_addr;
logic [63:0]    n_C_data_w, n_out_info;
Error_Msg n_err_msg;
 
//===========================================================================
// design
//===========================================================================

// fsm and all the signals
always_comb begin : fsm_comb
    // default
    n_state         = c_state;
    n_gold_info     = gold_info;
    n_err_msg       = No_Err;
    n_og_dman_data  = og_dman_data;
    n_og_res_data   = og_res_data;
    total_ser_food  = fd_id_s.d_ser_food + gold_info.golden_res_info.ser_FOOD1 + gold_info.golden_res_info.ser_FOOD2 + gold_info.golden_res_info.ser_FOOD3;

    case (c_state)
        IDLE    : begin
            case (action)
                Cancel,
                Deliver : n_state = (inf.id_valid == 1)     ? DRAM_A_D_MAN  : IDLE;
                Take    : n_state = (inf.cus_valid == 1)    ? DRAM_A_D_MAN  : IDLE;
                Order   : n_state = (inf.food_valid == 1)   ? DRAM_A_RES    : IDLE;
            endcase
        end 

        DRAM_A_D_MAN    : n_state = DRAM_D_MAN;
        DRAM_A_RES      : n_state = DRAM_RES;

        DRAM_D_MAN  : begin
            if (inf.C_out_valid == 1) begin
                n_gold_info.golden_d_man_info.ctm_info1 = revised_dram_data[31:16];
                n_gold_info.golden_d_man_info.ctm_info2 = revised_dram_data[15:0];

                n_og_dman_data.golden_res_info              = revised_dram_data[63:32];
                n_og_dman_data.golden_d_man_info.ctm_info1  = revised_dram_data[31:16];
                n_og_dman_data.golden_d_man_info.ctm_info2  = revised_dram_data[15:0];
                case (action)
                    // only need d man info
                    Cancel  : n_state = CAL;
                    Deliver : n_state = CAL;
                    // need d man info & res info
                    Take    : n_state = DRAM_A_RES;
                    Order   : n_state = DRAM_A_RES; 
                endcase
            end
            else    n_state = DRAM_D_MAN;
        end
        DRAM_RES    : begin
            if (inf.C_out_valid == 1) begin
                n_gold_info.golden_res_info = revised_dram_data[63:32];
                n_state = CAL;

                n_og_res_data.golden_res_info              = revised_dram_data[63:32];
                n_og_res_data.golden_d_man_info.ctm_info1  = revised_dram_data[31:16];
                n_og_res_data.golden_d_man_info.ctm_info2  = revised_dram_data[15:0];
            end
            else    n_state = DRAM_RES;
        end
        CAL : begin
            case (action)
                Cancel  : begin
                    // deliver man empty
                    if (gold_info.golden_d_man_info.ctm_info1.ctm_status == None &&
                        gold_info.golden_d_man_info.ctm_info2.ctm_status == None) begin
                        n_err_msg   = Wrong_cancel;  
                        n_state     = OUT;       
                    end
                    // deliver man has only 1 customer
                    else if (gold_info.golden_d_man_info.ctm_info1.ctm_status != None && gold_info.golden_d_man_info.ctm_info2.ctm_status == None) begin
                        if (gold_info.golden_d_man_info.ctm_info1.res_ID != res_id) begin
                            n_err_msg   = Wrong_res_ID;
                            n_state     = OUT;
                        end
                        else if (gold_info.golden_d_man_info.ctm_info1.food_ID != fd_id_s.d_food_ID) begin
                            n_err_msg   = Wrong_food_ID;
                            n_state     = OUT;
                        end
                        else begin // no error --> modify gold info, then WB
                            n_err_msg   = No_Err;
                            n_state     = WB_A_D_MAN;
                            // customer 1 has to be canceled
                            n_gold_info.golden_d_man_info.ctm_info1 = 0;
                            n_gold_info.golden_d_man_info.ctm_info2 = 0;
                        end
                    end
                    // deliver man has 2 customer
                    else if (gold_info.golden_d_man_info.ctm_info1.ctm_status != None && gold_info.golden_d_man_info.ctm_info2.ctm_status != None) begin
                        if (gold_info.golden_d_man_info.ctm_info1.res_ID != res_id && gold_info.golden_d_man_info.ctm_info2.res_ID != res_id) begin
                            n_err_msg   = Wrong_res_ID;
                            n_state     = OUT;
                        end
                        // no error --> modify gold info, then WB
                        // customer 1 or customer 2
                        else if ( (gold_info.golden_d_man_info.ctm_info1.res_ID == res_id)&&(gold_info.golden_d_man_info.ctm_info1.food_ID == fd_id_s.d_food_ID) || 
						           (gold_info.golden_d_man_info.ctm_info2.res_ID == res_id)&&(gold_info.golden_d_man_info.ctm_info2.food_ID == fd_id_s.d_food_ID)) begin
							n_err_msg   = No_Err;
                            n_state     = WB_A_D_MAN;
                            // at least one customer has to be canceled
                            // only customer 1 canceled
                            if ((gold_info.golden_d_man_info.ctm_info1.food_ID == fd_id_s.d_food_ID && 
                                gold_info.golden_d_man_info.ctm_info1.res_ID == res_id ) && 
                                (gold_info.golden_d_man_info.ctm_info2.food_ID != fd_id_s.d_food_ID ||
                                gold_info.golden_d_man_info.ctm_info2.res_ID != res_id)) begin
                                n_gold_info.golden_d_man_info.ctm_info1 = gold_info.golden_d_man_info.ctm_info2;
                                n_gold_info.golden_d_man_info.ctm_info2 = 0;
                            end
                            // only customer 2 canceled
                            else if ((gold_info.golden_d_man_info.ctm_info1.food_ID != fd_id_s.d_food_ID || 
                            gold_info.golden_d_man_info.ctm_info1.res_ID != res_id) && 
                            (gold_info.golden_d_man_info.ctm_info2.food_ID == fd_id_s.d_food_ID &&
                            gold_info.golden_d_man_info.ctm_info2.res_ID == res_id)) begin
                                n_gold_info.golden_d_man_info.ctm_info1 = gold_info.golden_d_man_info.ctm_info1;
                                n_gold_info.golden_d_man_info.ctm_info2 = 0;
                            end
                            // both being canceled
                            else if (gold_info.golden_d_man_info.ctm_info1.food_ID == fd_id_s.d_food_ID && 
                            gold_info.golden_d_man_info.ctm_info1.res_ID == res_id &&
                            gold_info.golden_d_man_info.ctm_info2.food_ID == fd_id_s.d_food_ID &&
                            gold_info.golden_d_man_info.ctm_info2.res_ID == res_id) begin
                                n_gold_info.golden_d_man_info.ctm_info1 = 0;
                                n_gold_info.golden_d_man_info.ctm_info2 = 0;
                            end
                        end
                        else begin // wrong food id
                            n_err_msg   = Wrong_food_ID;
                            n_state     = OUT;
                        end
                    end
                end 

                Deliver : begin
                    if (gold_info.golden_d_man_info.ctm_info1.ctm_status == None &&
                        gold_info.golden_d_man_info.ctm_info2.ctm_status == None) begin
                            n_err_msg   = No_customers;
                            n_state     = OUT;
                    end
                    else begin  // no error --> modify gold info, then WB
                        n_gold_info.golden_d_man_info.ctm_info1 = gold_info.golden_d_man_info.ctm_info2;
                        n_gold_info.golden_d_man_info.ctm_info2 = 0;
                        n_err_msg   = No_Err;
                        n_state     = WB_A_D_MAN;
                    end
                end

                Take    : begin
                    if (gold_info.golden_d_man_info.ctm_info1.ctm_status != None &&
                        gold_info.golden_d_man_info.ctm_info2.ctm_status != None) begin
                            n_err_msg   = D_man_busy;
                            n_state     = OUT; 
                    end
                    else begin 
                        case (cus_info.food_ID)
                            FOOD1   : begin
                                if (gold_info.golden_res_info.ser_FOOD1 < cus_info.ser_food) begin
                                    n_err_msg   = No_Food;
                                    n_state     = OUT;
                                end
                                else begin // no error --> modify gold info, then WB
                                    n_gold_info.golden_res_info.ser_FOOD1 = gold_info.golden_res_info.ser_FOOD1 - cus_info.ser_food;
                                    n_state = WB_A_D_MAN;

                                    // d man empty
                                    if (gold_info.golden_d_man_info.ctm_info1.ctm_status == None) begin
                                        n_gold_info.golden_d_man_info.ctm_info1 = cus_info;
                                    end
                                    // d man has only 1 customer
                                    else begin
                                        if (cus_info.ctm_status > gold_info.golden_d_man_info.ctm_info1.ctm_status) begin
                                            n_gold_info.golden_d_man_info.ctm_info1 = cus_info;
                                            n_gold_info.golden_d_man_info.ctm_info2 = gold_info.golden_d_man_info.ctm_info1;
                                        end else begin
                                            n_gold_info.golden_d_man_info.ctm_info2 = cus_info;
                                        end
                                    end
                                end
                            end
                            FOOD2   : begin
                                if (gold_info.golden_res_info.ser_FOOD2 < cus_info.ser_food) begin
                                    n_err_msg   = No_Food;
                                    n_state     = OUT;
                                end
                                else begin // no error --> modify gold info, then WB
                                    n_gold_info.golden_res_info.ser_FOOD2 = gold_info.golden_res_info.ser_FOOD2 - cus_info.ser_food;
                                    n_state = WB_A_D_MAN;

                                    // d man emtpy
                                    if (gold_info.golden_d_man_info.ctm_info1.ctm_status == None) begin
                                        n_gold_info.golden_d_man_info.ctm_info1 = cus_info;
                                    end 
                                    // d man only 1 customer
                                    else begin
                                        if (cus_info.ctm_status > gold_info.golden_d_man_info.ctm_info1.ctm_status) begin
                                            n_gold_info.golden_d_man_info.ctm_info1 = cus_info;
                                            n_gold_info.golden_d_man_info.ctm_info2 = gold_info.golden_d_man_info.ctm_info1;
                                        end else begin
                                            n_gold_info.golden_d_man_info.ctm_info2 = cus_info;
                                        end
                                    end
                                end
                            end
                            FOOD3   : begin
                                if (gold_info.golden_res_info.ser_FOOD3 < cus_info.ser_food) begin
                                    n_err_msg   = No_Food;
                                    n_state     = OUT;
                                end
                                else begin // no error --> modify gold info, then WB
                                    n_gold_info.golden_res_info.ser_FOOD3 = gold_info.golden_res_info.ser_FOOD3 - cus_info.ser_food;
                                    n_state = WB_A_D_MAN;

                                    // d man emtpy
                                    if (gold_info.golden_d_man_info.ctm_info1.ctm_status == None) begin
                                        n_gold_info.golden_d_man_info.ctm_info1 = cus_info;
                                    end 
                                    // d man only 1 customer
                                    else begin
                                        if (cus_info.ctm_status > gold_info.golden_d_man_info.ctm_info1.ctm_status) begin
                                            n_gold_info.golden_d_man_info.ctm_info1 = cus_info;
                                            n_gold_info.golden_d_man_info.ctm_info2 = gold_info.golden_d_man_info.ctm_info1;
                                        end else begin
                                            n_gold_info.golden_d_man_info.ctm_info2 = cus_info;
                                        end
                                    end
                                end
                            end 
                        endcase
                    end
                end
                
                Order   : begin
                    if (total_ser_food > gold_info.golden_res_info.limit_num_orders) begin
                        n_err_msg   = Res_busy;
                        n_state     = OUT;
                    end
                    else begin // no error --> modify gold info, then WB
                        case (fd_id_s.d_food_ID)
                            FOOD1   : n_gold_info.golden_res_info.ser_FOOD1 = gold_info.golden_res_info.ser_FOOD1 + fd_id_s.d_ser_food;
                            FOOD2   : n_gold_info.golden_res_info.ser_FOOD2 = gold_info.golden_res_info.ser_FOOD2 + fd_id_s.d_ser_food;
                            FOOD3   : n_gold_info.golden_res_info.ser_FOOD3 = gold_info.golden_res_info.ser_FOOD3 + fd_id_s.d_ser_food;
                        endcase
                        n_state = WB_A_RES;
                    end
                end

                // wrong
                default : n_state = IDLE; 
            endcase
        end
        WB_A_D_MAN  : n_state = WB_D_MAN;
        WB_A_RES    : n_state = WB_RES;

        WB_D_MAN    : begin
            if (inf.C_out_valid == 1) begin
                if (action == Take && dman_addr != res_addr)    n_state = WB_A_RES;
                else                                            n_state = OUT;
            end else begin
                n_state = WB_D_MAN;
            end
        end
        WB_RES      : n_state = (inf.C_out_valid == 1) ? OUT : WB_RES;

        OUT : n_state = IDLE;

        default : n_state = c_state; 
    endcase
end

always_ff @( posedge clk, negedge inf.rst_n ) begin : fsm_ff
    if (!inf.rst_n)     c_state <= IDLE;
    else                c_state <= n_state; 
end

always_comb begin : wb_comb
    dman_addr   = d_man_id;
    res_addr    = (action == Take) ? cus_info.res_ID : res_id;

    if      (c_state == WB_A_D_MAN) begin
        if (dman_addr == res_addr && action == Take) begin
            n_wb_data.golden_d_man_info = gold_info.golden_d_man_info;
            n_wb_data.golden_res_info   = gold_info.golden_res_info;
        end
        else begin
            n_wb_data.golden_d_man_info = gold_info.golden_d_man_info;
            n_wb_data.golden_res_info   = og_dman_data.golden_res_info;   
        end
    end
    else if (c_state == WB_A_RES) begin
        n_wb_data.golden_d_man_info = og_res_data.golden_d_man_info;
        n_wb_data.golden_res_info   = gold_info.golden_res_info;
    end
    else    n_wb_data = wb_data;
end

always_ff @( posedge clk, negedge inf.rst_n ) begin : gold_info_ff
    if (!inf.rst_n) begin
        gold_info       <= 0;
        og_dman_data    <= 0;
        og_res_data     <= 0;
        wb_data         <= 0;
    end else begin
        gold_info       <= n_gold_info;
        og_dman_data    <= n_og_dman_data;
        og_res_data     <= n_og_res_data;
        wb_data         <= n_wb_data;
    end
end

// store input data
always_comb begin : store_input_comb
    n_action    = (inf.act_valid == 1)  ? inf.D.d_act[0]            : action;
    n_d_man_id  = (inf.id_valid == 1)   ? inf.D.d_id[0]             : d_man_id;
    n_res_id    = (inf.res_valid == 1)  ? inf.D.d_res_id[0]         : res_id;
    n_fd_id_s   = (inf.food_valid == 1) ? inf.D.d_food_ID_ser[0]    : fd_id_s;
    n_cus_info  = (inf.cus_valid == 1)  ? inf.D.d_ctm_info[0]       : cus_info;
end  

always_ff @( posedge clk, negedge inf.rst_n ) begin : store_input_ff
    if (!inf.rst_n) begin
        action      <= No_action;
        d_man_id    <= 0;
        res_id      <= 0;
        fd_id_s     <= 0;
        cus_info    <= 0;
    end else begin
        action      <= n_action;
        d_man_id    <= n_d_man_id;
        res_id      <= n_res_id;
        fd_id_s     <= n_fd_id_s;
        cus_info    <= n_cus_info;
    end
end


// data from dram & calculations (golden res & d_man info, error message)
always_comb begin : revised_dram_data_comb
    revised_dram_data = {
        inf.C_data_r[7:0],
        inf.C_data_r[15:8],
        inf.C_data_r[23:16],
        inf.C_data_r[31:24],
        inf.C_data_r[39:32],
        inf.C_data_r[47:40],
        inf.C_data_r[55:48],
        inf.C_data_r[63:56]
    };
end

logic tmp;
always_comb begin 
    if (inf.C_addr == 102) tmp = 1;
    else tmp = 0;
end

// output 
always_comb begin : output_comb
    n_out_valid = (n_state == OUT) ? 1 : 0;
    n_C_in_valid = (c_state == DRAM_A_D_MAN || c_state == DRAM_A_RES || c_state == WB_A_D_MAN || c_state == WB_A_RES) ? 1 : 0;

    if      (c_state == DRAM_A_D_MAN)   n_C_addr = d_man_id;
    else if (c_state == DRAM_A_RES)     n_C_addr = (action == Take) ? cus_info.res_ID : res_id;
    else if (c_state == WB_A_D_MAN)     n_C_addr = d_man_id;
    else if (c_state == WB_A_RES)       n_C_addr = (action == Take) ? cus_info.res_ID : res_id;
    else                                n_C_addr = inf.C_addr;

    if (n_out_valid == 1 && n_err_msg != No_Err)    n_complete = 0;
    else                                            n_complete = 1;

    n_C_r_wb = (c_state == WB_A_RES || c_state == WB_A_D_MAN) ? 0 : 1;
    n_C_data_w = {
        n_wb_data[39:32],
        n_wb_data[47:40],
        n_wb_data[55:48],
        n_wb_data[63:56],

        n_wb_data.golden_res_info.ser_FOOD3,
        n_wb_data.golden_res_info.ser_FOOD2,
        n_wb_data.golden_res_info.ser_FOOD1,
        n_wb_data.golden_res_info.limit_num_orders
    };

    if (n_complete == 0) // has error
        n_out_info = 0;
    else begin
        case (action)
            Take    : n_out_info = {gold_info.golden_d_man_info, gold_info.golden_res_info}; 
            Order   : n_out_info = {32'd0, gold_info.golden_res_info};
            Deliver : n_out_info = {gold_info.golden_d_man_info, 32'd0};
            Cancel  : n_out_info = {gold_info.golden_d_man_info, 32'd0};
            default : n_out_info = 0; 
        endcase
    end
end

always_ff @( posedge clk, negedge inf.rst_n ) begin : output_ff
    if (!inf.rst_n) begin
        inf.out_valid   <= 0;
        inf.err_msg     <= 0;
        inf.complete    <= 0;
        inf.out_info    <= 0;
        inf.C_addr      <= 0;
        inf.C_data_w    <= 0;
        inf.C_in_valid  <= 0;
        inf.C_r_wb      <= 0;       // default: 1 (read access)
    end else begin
        inf.out_valid   <= n_out_valid;
        inf.err_msg     <= (n_state == OUT) ? n_err_msg : 0;
        inf.complete    <= n_complete;
        inf.out_info    <= n_out_info;
        inf.C_addr      <= n_C_addr; 
        inf.C_data_w    <= n_C_data_w;
        inf.C_in_valid  <= n_C_in_valid;
        inf.C_r_wb      <= n_C_r_wb;
    end   
end


endmodule