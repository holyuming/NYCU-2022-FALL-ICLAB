module bridge(input clk, INF.bridge_inf inf);
import usertype::*;



//================================================================
// logic 
//================================================================
logic [16:0] added_addr;


//================================================================
// state 
//================================================================
typedef enum logic [3:0] {
    IDLE,
    ADDR_R,
    DATA_R,
    ADDR_W,
    DATA_W,
    RES_B,
    OUT
} bridge_state;

bridge_state c_state, n_state;

//================================================================
//   FSM
//================================================================

// fsm
always_comb begin : fsm_comb
    case (c_state)
        IDLE    : begin
            if (inf.C_in_valid == 1)    n_state = (inf.C_r_wb == 0) ? ADDR_W : ADDR_R;
            else                        n_state = IDLE;
        end

        ADDR_R  : n_state = (inf.AR_READY == 1) ? DATA_R : ADDR_R;
        DATA_R  : n_state = (inf.R_VALID == 1) ? OUT : DATA_R;

        ADDR_W  : n_state = (inf.AW_READY == 1) ? DATA_W : ADDR_W;
        DATA_W  : n_state = (inf.W_READY == 1) ? RES_B : DATA_W;

        RES_B   : n_state = (inf.B_VALID == 1) ? OUT : RES_B;

        OUT     : n_state = IDLE;
        default : n_state = IDLE; 
    endcase
end

always_ff @( posedge clk, negedge inf.rst_n ) begin : fsm_ff
    if (!inf.rst_n)     c_state <= IDLE;
    else                c_state <= n_state;
end


// axi lite protocol
always_comb begin : add_addr
    added_addr = 'h10000 + {{inf.C_addr, 3'b000}};    
end


// output to FD
always_ff @( posedge clk, negedge inf.rst_n ) begin : out_to_FD
    if (!inf.rst_n) begin
        inf.C_out_valid <= 0;
        inf.C_data_r    <= 0;
    end
    else begin
        inf.C_out_valid <= (n_state == OUT) ? 1 : 0;
        inf.C_data_r    <= (inf.R_VALID == 1) ? inf.R_DATA : 0; 
    end
end

always_ff @( posedge clk, negedge inf.rst_n ) begin : output_to_dram_ff
    if (!inf.rst_n) begin
        inf.AR_ADDR     <= 0;   
        inf.AW_ADDR     <= 0;  
        inf.W_DATA      <= 0;

        inf.AR_VALID    <= 0;
        inf.R_READY     <= 0;
        inf.AW_VALID    <= 0;
        inf.W_VALID     <= 0;
        inf.B_READY     <= 0;
    end
    else begin           
        inf.AR_ADDR <= added_addr; 
        inf.AW_ADDR <= added_addr;
        inf.W_DATA  <= inf.C_data_w;

        inf.AR_VALID    <= (n_state == ADDR_R) ? 1 : 0;
        inf.R_READY     <= (n_state == DATA_R) ? 1 : 0;
        inf.AW_VALID    <= (n_state == ADDR_W) ? 1 : 0;
        inf.W_VALID     <= (n_state == DATA_W) ? 1 : 0;
        inf.B_READY     <= (n_state == RES_B) ? 1 : 0;
    end
end

endmodule