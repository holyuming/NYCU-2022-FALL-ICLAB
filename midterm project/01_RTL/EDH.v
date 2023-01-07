// synopsys translate_off
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW_addsub_dx.v"
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW_minmax.v"
// synopsys translate_on
module EDH #(parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 128) (
    /* design */

        // input
        input wire clk, rst_n, in_valid,
        input wire [1:0] op,
        input wire [3:0] pic_no,
        input wire [5:0] se_no,

        // output
        output reg busy,

    /* DRAM */

        // axi write address
        // src master
        output reg [ID_WIDTH-1:0]     awid_m_inf,
        output reg [ADDR_WIDTH-1:0] awaddr_m_inf,
        output reg [2:0]            awsize_m_inf,
        output reg [1:0]           awburst_m_inf,
        output reg [7:0]             awlen_m_inf,
        output reg                 awvalid_m_inf,
        // src slave
        input wire                 awready_m_inf,


        // axi write data
        // src master
        output reg [DATA_WIDTH-1:0]  wdata_m_inf,
        output reg                   wlast_m_inf,
        output reg                  wvalid_m_inf,
        // src slave
        input wire                  wready_m_inf,
        
        // axi write response
        // src slave
        input wire  [ID_WIDTH-1:0]     bid_m_inf,
        input wire  [1:0]            bresp_m_inf,
        input wire                  bvalid_m_inf,
        // src master 
        output reg                  bready_m_inf,

        // axi read address
        // src master
        output reg [ID_WIDTH-1:0]     arid_m_inf,
        output reg [ADDR_WIDTH-1:0] araddr_m_inf,
        output reg [7:0]             arlen_m_inf,
        output reg [2:0]            arsize_m_inf,
        output reg [1:0]           arburst_m_inf,
        output reg                 arvalid_m_inf,
        // src slave
        input wire                 arready_m_inf,

        // axi read data
        // slave
        input wire [ID_WIDTH-1:0]      rid_m_inf,
        input wire [DATA_WIDTH-1:0]  rdata_m_inf,
        input wire [1:0]             rresp_m_inf,
        input wire                   rlast_m_inf,
        input wire                  rvalid_m_inf,
        // master
        output reg                  rready_m_inf
);

// ================================================================================
// |                              PARAMS                                          |
// ================================================================================

// for main design
localparam  S_IDLE = 0, 
            S_READ = 1,
            S_SE_ADDR = 2,
            S_SE_DATA = 3,
            S_PIC_ADDR = 4,
            S_PIC_DATA = 5,
            
            S_ERO_DILA = 6,

            S_WR_ADDR = 7,
            S_WR_DATA = 8,
            S_WR_RES = 9,
            
            S_CDFTABLE0 = 10,
            S_CDFTABLE1 = 11,
            S_CDF_MIN = 12,
            S_CDF_DIV = 13,
            S_CDF_WB = 14;
            

integer i, j, k;
genvar m, n, l;


// ================================================================================
// |                             WIRE & REG                                       |
// ================================================================================

// fsm
reg [3:0] c_state, n_state;

// counter
reg [11:0] counter, n_counter;     // max at 4095
reg [2:0] counter8;     // max at 7

// save input
reg [1:0] opcode;
reg [3:0] pic_idx;
reg [5:0] se_idx;

// se
reg [7:0] se [0:3][0:3];


// calculation FF (4 x 64) pic
reg [7:0] pic [0:3][0:66], n_pic [0:3][0:66]; 
reg [8:0] ero_dila_cnt;


// cdf table, histagram related
reg [12:0] cdf_table [0:255][0:1], n_cdf_table [0:255][0:1];   // max at 4096
reg [7:0] sel0, sel1;
reg [7:0] pixel [0:15];
reg [7:0] cdf_result [0:15];
reg [12:0] cdf_min;
reg [7:0] cdf_mapping_value [0:255];
reg [20:0] numerator;
reg [12:0] denominator;
reg [7:0] hv;


// SRAM --> pic
wire [DATA_WIDTH-1:0] picQ;
reg [DATA_WIDTH-1:0] picD;
reg [7:0] picAddr;      // max at 255
reg picWen;
PIC_MEM PIC0 (    
    .Q(picQ), 
    .CLK(clk), 
    .CEN(1'b0), 
    .WEN(picWen), 
    .A(picAddr), 
    .D(picD), 
    .OEN(1'b0)
);

// SRAM --> output
wire [DATA_WIDTH-1:0] outQ;
reg [DATA_WIDTH-1:0] outD;
reg [7:0] outAddr;      // max at 255
reg outWen;
PIC_MEM OUT0 (    
    .Q(outQ), 
    .CLK(clk), 
    .CEN(1'b0), 
    .WEN(outWen), 
    .A(outAddr), 
    .D(outD), 
    .OEN(1'b0)
);





// =====================================================================
//                          FSM
// =====================================================================

// fsm
always @(*) begin
    case (c_state)
        S_IDLE      : n_state = (in_valid == 1) ? S_READ : S_IDLE;
        S_READ      : n_state = S_SE_ADDR;

        S_SE_ADDR   : n_state = (arready_m_inf == 1) ? S_SE_DATA : S_SE_ADDR;
        S_SE_DATA   : n_state = (rlast_m_inf == 1) ? S_PIC_ADDR : S_SE_DATA;

        S_PIC_ADDR  : n_state = (arready_m_inf == 1) ? S_PIC_DATA : S_PIC_ADDR;
        S_PIC_DATA  : begin
            if (rlast_m_inf == 1 && opcode != 2)    n_state = S_ERO_DILA;
            else if (rlast_m_inf == 1)              n_state = S_CDFTABLE0;
            else                                    n_state = S_PIC_DATA;
        end

        S_ERO_DILA  : n_state = (ero_dila_cnt == 271) ? S_WR_ADDR : S_ERO_DILA;

        S_CDFTABLE0 : n_state = (counter == 255 && counter8 == 7) ? S_CDFTABLE1 : S_CDFTABLE0; 
        S_CDFTABLE1 : n_state = (counter == 255) ? S_CDF_MIN : S_CDFTABLE1;
        S_CDF_MIN   : n_state = (counter == 255 || cdf_min != 0) ? S_CDF_DIV : S_CDF_MIN;
        S_CDF_DIV   : n_state = (counter == 255) ? S_CDF_WB : S_CDF_DIV;

        S_CDF_WB    : n_state = (counter == 256) ? S_WR_ADDR : S_CDF_WB; 
        
        S_WR_ADDR   : n_state = (awready_m_inf == 1) ? S_WR_DATA : S_WR_ADDR;
        S_WR_DATA   : n_state = (counter[7:0] == 255) ? S_WR_RES : S_WR_DATA;
        S_WR_RES    : n_state = (bvalid_m_inf == 1) ? S_IDLE : S_WR_RES;

        default:  n_state = S_IDLE;
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) c_state <= S_IDLE;
    else        c_state <= n_state;
end


// =====================================================================
//                          DRAM (axi)
// =====================================================================

// axi read addr
always @(*) begin
    arid_m_inf = 4'd0;
    arsize_m_inf = 3'b100;
    arburst_m_inf = 2'b01;

    case (c_state)
        S_SE_ADDR   :  begin
            araddr_m_inf    = {20'h00030, 2'b0, se_idx, 4'h0};
            arlen_m_inf     = 0;       // read out only 1 kernel
            arvalid_m_inf   = 1;
        end
        S_PIC_ADDR  : begin
            araddr_m_inf    = {16'h0004, pic_idx, 12'h000};
            arlen_m_inf     = 255;      // 4 * 64 row
            arvalid_m_inf   = 1;
        end
        default: begin
            araddr_m_inf    = 0;
            arlen_m_inf     = 0;
            arvalid_m_inf   = 0;
        end
    endcase
end

// axi read data
always @(*) begin
    rready_m_inf = (c_state == S_SE_DATA || c_state == S_PIC_DATA) ? 1 : 0;
end

// axi write addr
always @(*) begin
    awid_m_inf = 0;
    awsize_m_inf = 3'b100;
    awburst_m_inf = 2'b01;
    
    case (c_state)
        S_WR_ADDR   : begin
            awaddr_m_inf = {16'h0004, pic_idx, 12'h000};
            awlen_m_inf = 255;
            awvalid_m_inf = 1;
        end 
        default: begin
            awaddr_m_inf = 0;
            awlen_m_inf = 0;
            awvalid_m_inf = 0;
        end
    endcase
end

// axi write data
always @(*) begin
    case (c_state)
        S_WR_DATA   : begin
            wdata_m_inf = outQ;
            wvalid_m_inf = 1;
            wlast_m_inf = (counter[7:0] == 255) ? 1 : 0;
        end
        default: begin
            wdata_m_inf = 0;
            wvalid_m_inf = 0;
            wlast_m_inf = 0;
        end
    endcase
end

// axi write response
always @(*) begin
    bready_m_inf = (c_state == S_WR_DATA || c_state == S_WR_RES) ? 1 : 0;
end

// =====================================================================
//                           COUNTER
// =====================================================================
// base counter
always @(*) begin
    case(c_state)
        S_IDLE      : n_counter = 0;
        S_PIC_DATA  : n_counter = (counter == 255) ? 0 : (rready_m_inf == 1 && rvalid_m_inf == 1) ? counter + 1 : counter;
        S_ERO_DILA  : n_counter = counter + 1;
        S_CDFTABLE0 : n_counter = (counter == 255 && counter8 == 7) ? 0 : (counter8 == 7) ? counter + 1 : counter;
        S_CDFTABLE1 : n_counter = (counter == 255) ? 0 : counter + 1;
        S_CDF_MIN   : n_counter = (counter == 255 || cdf_min != 0) ? 0 : counter + 1;
        S_CDF_DIV   : n_counter = (counter == 255) ? 0 : counter + 1;
        S_CDF_WB    : n_counter = (counter == 256) ? 0 : counter + 1;
        S_WR_ADDR   : n_counter = 0;
        S_WR_DATA   : n_counter = (wvalid_m_inf == 1 && wready_m_inf == 1) ? counter + 1 : counter;
        default     : n_counter = counter;
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     counter <= 0;
    else            counter <= n_counter;
end


// erosion & dilation specific counter
always @(*) begin
    ero_dila_cnt = counter[8:0];
end


// counter8 --> for cdf table0
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) counter8 <= 0;
    else begin
        case (c_state)
            S_IDLE      : counter8 <= 0;
            S_CDFTABLE0 : counter8 <= counter8 + 1;
            default     : counter8 <= 0; 
        endcase
    end
end

// =====================================================================
//                 LOAD PIC FROM DRAM TO SRAM
// =====================================================================

// pic sram
always @(*) begin
    picAddr = (c_state == S_PIC_DATA || c_state == S_ERO_DILA || c_state == S_CDFTABLE0 || c_state == S_CDF_WB) ? counter : 0;
    picWen  = (c_state == S_PIC_DATA) ? 0 : 1;   // only in s_pic_data, we can write
    picD    = rdata_m_inf;
end

// output sram
always @(*) begin
    outWen = ((c_state == S_ERO_DILA && (15 <= ero_dila_cnt) && (ero_dila_cnt <= 270)) || c_state == S_CDF_WB) ? 0 : 1;

    case (c_state)
        S_ERO_DILA  : outAddr = (outWen == 1) ? 0 : ero_dila_cnt - 15;
        S_WR_DATA   : outAddr = (wready_m_inf == 0) ? 0 : ero_dila_cnt + 1;
        S_CDF_WB    : outAddr = (outWen == 1) ? 0 : counter[7:0] - 1;
        default     : outAddr = 0; 
    endcase
end
always @(*) begin
    if (opcode == 2) begin
        outD = {
            cdf_result[15],
            cdf_result[14],
            cdf_result[13],
            cdf_result[12],
            cdf_result[11],
            cdf_result[10],
            cdf_result[9],
            cdf_result[8],
            cdf_result[7],
            cdf_result[6],
            cdf_result[5],
            cdf_result[4],
            cdf_result[3],
            cdf_result[2],
            cdf_result[1],
            cdf_result[0]
        };
    end
    else begin
        outD = {selected_window[15].result,
                selected_window[14].result,
                selected_window[13].result,
                selected_window[12].result,
                selected_window[11].result,
                selected_window[10].result,
                selected_window[9].result,
                selected_window[8].result,
                selected_window[7].result,
                selected_window[6].result,
                selected_window[5].result,
                selected_window[4].result,
                selected_window[3].result,
                selected_window[2].result,
                selected_window[1].result,
                selected_window[0].result};
    end
end



// =====================================================================
//                 SAVE OP, SE_NO, PIC_NO into flip-flops
// =====================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        opcode  <= 0;
        pic_idx <= 0;
        se_idx  <= 0;
    end
    else begin
        opcode  <= (in_valid == 1) ? op : opcode;
        pic_idx <= (in_valid == 1) ? pic_no : pic_idx;
        se_idx  <= (in_valid == 1) ? se_no : se_idx;
    end
end


// =====================================================================
//                             KERNEL
// =====================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i=0 ; i<4 ; i=i+1) begin
            for (j=0 ; j<4 ; j=j+1) begin
                se[i][j] <= 0;
            end
        end
    end
    else begin
        case (c_state)
            S_SE_DATA   : begin
                // dilation
                if (opcode == 1) begin
                    se[0][0] <= rdata_m_inf[127:120];
                    se[0][1] <= rdata_m_inf[119:112];
                    se[0][2] <= rdata_m_inf[111:104];
                    se[0][3] <= rdata_m_inf[103:96];
                    se[1][0] <= rdata_m_inf[95:88];
                    se[1][1] <= rdata_m_inf[87:80];
                    se[1][2] <= rdata_m_inf[79:72];
                    se[1][3] <= rdata_m_inf[71:64];
                    se[2][0] <= rdata_m_inf[63:56];
                    se[2][1] <= rdata_m_inf[55:48];
                    se[2][2] <= rdata_m_inf[47:40];
                    se[2][3] <= rdata_m_inf[39:32];
                    se[3][0] <= rdata_m_inf[31:24];
                    se[3][1] <= rdata_m_inf[23:16];
                    se[3][2] <= rdata_m_inf[15:8];
                    se[3][3] <= rdata_m_inf[7:0];
                end
                // erosion
                else begin
                    se[0][0]  <= rdata_m_inf[7:0];
                    se[0][1]  <= rdata_m_inf[15:8];
                    se[0][2]  <= rdata_m_inf[23:16];
                    se[0][3]  <= rdata_m_inf[31:24];
                    se[1][0]  <= rdata_m_inf[39:32];
                    se[1][1]  <= rdata_m_inf[47:40];
                    se[1][2]  <= rdata_m_inf[55:48];
                    se[1][3]  <= rdata_m_inf[63:56];
                    se[2][0]  <= rdata_m_inf[71:64];
                    se[2][1]  <= rdata_m_inf[79:72];
                    se[2][2]  <= rdata_m_inf[87:80];
                    se[2][3]  <= rdata_m_inf[95:88];
                    se[3][0]  <= rdata_m_inf[103:96];
                    se[3][1]  <= rdata_m_inf[111:104];
                    se[3][2]  <= rdata_m_inf[119:112];
                    se[3][3]  <= rdata_m_inf[127:120];
                end
            end 
            default: begin
                for (i=0 ; i<4 ; i=i+1) begin
                    for (j=0 ; j<4 ; j=j+1) begin
                        se[i][j] <= se[i][j];
                    end
                end
            end 
        endcase
    end
end


// =====================================================================
//                             PICTURE
// =====================================================================
always @(*) begin
    // default
    for (i=0 ; i<4 ; i=i+1) begin
        for (j=0 ; j<67 ; j=j+1) begin
            n_pic[i][j] = pic[i][j];
        end
    end

    // erosion & dilation
    case (ero_dila_cnt[1:0])
        1: begin
            for (i=0 ; i<3 ; i=i+1) begin
                for (j=0 ; j<16 ; j=j+1) begin
                    n_pic[i][j] = pic[i+1][j];
                end
            end
        end 
        2: begin
            for (i=0 ; i<3 ; i=i+1) begin
                for (j=16 ; j<32 ; j=j+1) begin
                    n_pic[i][j] = pic[i+1][j];
                end
            end
        end
        3: begin
            for (i=0 ; i<3 ; i=i+1) begin
                for (j=32 ; j<48 ; j=j+1) begin
                    n_pic[i][j] = pic[i+1][j];
                end
            end
        end
        0: begin
            for (i=0 ; i<3 ; i=i+1) begin
                for (j=48 ; j<64 ; j=j+1) begin
                    n_pic[i][j] = pic[i+1][j];
                end
            end
        end
    endcase
    
    if (c_state == S_ERO_DILA ) begin
        case (ero_dila_cnt[1:0])
            1: begin
                n_pic[3][0]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[7:0] : 0;
                n_pic[3][1]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[15:8] : 0;
                n_pic[3][2]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[23:16] : 0;
                n_pic[3][3]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[31:24] : 0;
                n_pic[3][4]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[39:32] : 0;
                n_pic[3][5]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[47:40] : 0;
                n_pic[3][6]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[55:48] : 0;
                n_pic[3][7]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[63:56] : 0;
                n_pic[3][8]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[71:64] : 0;
                n_pic[3][9]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[79:72] : 0;
                n_pic[3][10] = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[87:80] : 0;
                n_pic[3][11] = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[95:88] : 0;
                n_pic[3][12] = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[103:96] : 0;
                n_pic[3][13] = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[111:104] : 0;
                n_pic[3][14] = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[119:112] : 0;
                n_pic[3][15] = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[127:120] : 0;
            end
            2: begin
                n_pic[3][16]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[7:0] : 0;
                n_pic[3][17]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[15:8] : 0;
                n_pic[3][18]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[23:16] : 0;
                n_pic[3][19]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[31:24] : 0;
                n_pic[3][20]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[39:32] : 0;
                n_pic[3][21]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[47:40] : 0;
                n_pic[3][22]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[55:48] : 0;
                n_pic[3][23]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[63:56] : 0;
                n_pic[3][24]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[71:64] : 0;
                n_pic[3][25]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[79:72] : 0;
                n_pic[3][26]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[87:80] : 0;
                n_pic[3][27]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[95:88] : 0;
                n_pic[3][28]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[103:96] : 0;
                n_pic[3][29]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[111:104] : 0;
                n_pic[3][30]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[119:112] : 0;
                n_pic[3][31]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[127:120] : 0;
            end
            3: begin
                n_pic[3][32]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[7:0] : 0;
                n_pic[3][33]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[15:8] : 0;
                n_pic[3][34]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[23:16] : 0;
                n_pic[3][35]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[31:24] : 0;
                n_pic[3][36]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[39:32] : 0;
                n_pic[3][37]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[47:40] : 0;
                n_pic[3][38]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[55:48] : 0;
                n_pic[3][39]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[63:56] : 0;
                n_pic[3][40]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[71:64] : 0;
                n_pic[3][41]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[79:72] : 0;
                n_pic[3][42]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[87:80] : 0;
                n_pic[3][43]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[95:88] : 0;
                n_pic[3][44]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[103:96] : 0;
                n_pic[3][45]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[111:104] : 0;
                n_pic[3][46]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[119:112] : 0;
                n_pic[3][47]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[127:120] : 0;
            end
            0: begin
                n_pic[3][48]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[7:0] : 0;
                n_pic[3][49]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[15:8] : 0;
                n_pic[3][50]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[23:16] : 0;
                n_pic[3][51]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[31:24] : 0;
                n_pic[3][52]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[39:32] : 0;
                n_pic[3][53]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[47:40] : 0;
                n_pic[3][54]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[55:48] : 0;
                n_pic[3][55]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[63:56] : 0;
                n_pic[3][56]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[71:64] : 0;
                n_pic[3][57]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[79:72] : 0;
                n_pic[3][58]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[87:80] : 0;
                n_pic[3][59]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[95:88] : 0;
                n_pic[3][60]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[103:96] : 0;
                n_pic[3][61]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[111:104] : 0;
                n_pic[3][62]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[119:112] : 0;
                n_pic[3][63]  = (1 <= ero_dila_cnt && ero_dila_cnt <= 256) ? picQ[127:120] : 0;
            end 
        endcase
    end
end


generate
for (m=0 ; m<4 ; m=m+1) begin
    for (n=0 ; n<67 ; n=n+1) begin

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) pic[m][n] <= 0;
            else        pic[m][n] <= n_pic[m][n];
        end

    end
end 
endgenerate


// =====================================================================
//                       EROSION & DILATION
// =====================================================================

// selected windows & calculations
generate
for (m=0 ; m<16;  m=m+1) begin : selected_window    // picture - kernel, picture + kernel

    reg [7:0] sw[0:3][0:3];
    wire [7:0] cal[0:3][0:3];
    wire [7:0] result;


    // sw
    always @(*) begin 
        case (ero_dila_cnt[1:0])
            3: begin
                sw[0][0] = pic[0][m];
                sw[0][1] = pic[0][m+1];
                sw[0][2] = pic[0][m+2];
                sw[0][3] = pic[0][m+3];
                sw[1][0] = pic[1][m];
                sw[1][1] = pic[1][m+1];
                sw[1][2] = pic[1][m+2];
                sw[1][3] = pic[1][m+3];
                sw[2][0] = pic[2][m];
                sw[2][1] = pic[2][m+1];
                sw[2][2] = pic[2][m+2];
                sw[2][3] = pic[2][m+3];
                sw[3][0] = pic[3][m];
                sw[3][1] = pic[3][m+1];
                sw[3][2] = pic[3][m+2];
                sw[3][3] = pic[3][m+3];
            end 
            0: begin
                sw[0][0] = pic[0][m+16];
                sw[0][1] = pic[0][m+17];
                sw[0][2] = pic[0][m+18];
                sw[0][3] = pic[0][m+19];
                sw[1][0] = pic[1][m+16];
                sw[1][1] = pic[1][m+17];
                sw[1][2] = pic[1][m+18];
                sw[1][3] = pic[1][m+19];
                sw[2][0] = pic[2][m+16];
                sw[2][1] = pic[2][m+17];
                sw[2][2] = pic[2][m+18];
                sw[2][3] = pic[2][m+19];
                sw[3][0] = pic[3][m+16];
                sw[3][1] = pic[3][m+17];
                sw[3][2] = pic[3][m+18];
                sw[3][3] = pic[3][m+19];
            end
            1: begin
                sw[0][0] = pic[0][m+32];
                sw[0][1] = pic[0][m+33];
                sw[0][2] = pic[0][m+34];
                sw[0][3] = pic[0][m+35];
                sw[1][0] = pic[1][m+32];
                sw[1][1] = pic[1][m+33];
                sw[1][2] = pic[1][m+34];
                sw[1][3] = pic[1][m+35];
                sw[2][0] = pic[2][m+32];
                sw[2][1] = pic[2][m+33];
                sw[2][2] = pic[2][m+34];
                sw[2][3] = pic[2][m+35];
                sw[3][0] = pic[3][m+32];
                sw[3][1] = pic[3][m+33];
                sw[3][2] = pic[3][m+34];
                sw[3][3] = pic[3][m+35];
            end
            2: begin
                sw[0][0] = pic[0][m+48];
                sw[0][1] = pic[0][m+49];
                sw[0][2] = pic[0][m+50];
                sw[0][3] = pic[0][m+51];
                sw[1][0] = pic[1][m+48];
                sw[1][1] = pic[1][m+49];
                sw[1][2] = pic[1][m+50];
                sw[1][3] = pic[1][m+51];
                sw[2][0] = pic[2][m+48];
                sw[2][1] = pic[2][m+49];
                sw[2][2] = pic[2][m+50];
                sw[2][3] = pic[2][m+51];
                sw[3][0] = pic[3][m+48];
                sw[3][1] = pic[3][m+49];
                sw[3][2] = pic[3][m+50];
                sw[3][3] = pic[3][m+51];
            end
        endcase
    end


    // cal (DW)
    DW_addsub_dx #(8) addsub0 (.a(sw[0][0]), .b(se[0][0]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[0][0]), .co1(), .co2());
    DW_addsub_dx #(8) addsub1 (.a(sw[0][1]), .b(se[0][1]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[0][1]), .co1(), .co2());
    DW_addsub_dx #(8) addsub2 (.a(sw[0][2]), .b(se[0][2]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[0][2]), .co1(), .co2());
    DW_addsub_dx #(8) addsub3 (.a(sw[0][3]), .b(se[0][3]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[0][3]), .co1(), .co2());
    DW_addsub_dx #(8) addsub4 (.a(sw[1][0]), .b(se[1][0]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[1][0]), .co1(), .co2());
    DW_addsub_dx #(8) addsub5 (.a(sw[1][1]), .b(se[1][1]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[1][1]), .co1(), .co2());
    DW_addsub_dx #(8) addsub6 (.a(sw[1][2]), .b(se[1][2]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[1][2]), .co1(), .co2());
    DW_addsub_dx #(8) addsub7 (.a(sw[1][3]), .b(se[1][3]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[1][3]), .co1(), .co2());
    DW_addsub_dx #(8) addsub8 (.a(sw[2][0]), .b(se[2][0]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[2][0]), .co1(), .co2());
    DW_addsub_dx #(8) addsub9 (.a(sw[2][1]), .b(se[2][1]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[2][1]), .co1(), .co2());
    DW_addsub_dx #(8) addsubA (.a(sw[2][2]), .b(se[2][2]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[2][2]), .co1(), .co2());
    DW_addsub_dx #(8) addsubB (.a(sw[2][3]), .b(se[2][3]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[2][3]), .co1(), .co2());
    DW_addsub_dx #(8) addsubC (.a(sw[3][0]), .b(se[3][0]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[3][0]), .co1(), .co2());
    DW_addsub_dx #(8) addsubD (.a(sw[3][1]), .b(se[3][1]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[3][1]), .co1(), .co2());
    DW_addsub_dx #(8) addsubE (.a(sw[3][2]), .b(se[3][2]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[3][2]), .co1(), .co2());
    DW_addsub_dx #(8) addsubF (.a(sw[3][3]), .b(se[3][3]), .ci1(1'b0), .ci2(1'b0), .addsub(!opcode[0]), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[3][3]), .co1(), .co2());


    // compare (DW)
    DW_minmax #(8, 16) minmax0 (.a(
        {
            cal[0][0], cal[0][1], cal[0][2], cal[0][3], 
            cal[1][0], cal[1][1], cal[1][2], cal[1][3], 
            cal[2][0], cal[2][1], cal[2][2], cal[2][3], 
            cal[3][0], cal[3][1], cal[3][2], cal[3][3]
        }
    ), .tc(1'b0), .min_max(opcode[0]), .value(result), .index());
end
endgenerate


// =====================================================================
//                           CDF TABLE 
// =====================================================================

// sel0, sel1 --> compare two pixel at a cycle
always @(*) begin
    case (counter8)
        0: begin
            sel0 = picQ[7:0];
            sel1 = picQ[15:8];
        end 
        1: begin
            sel0 = picQ[23:16];
            sel1 = picQ[31:24];
        end 
        2: begin
            sel0 = picQ[39:32];
            sel1 = picQ[47:40];
        end 
        3: begin
            sel0 = picQ[55:48];
            sel1 = picQ[63:56];
        end 
        4: begin
            sel0 = picQ[71:64];
            sel1 = picQ[79:72];
        end 
        5: begin
            sel0 = picQ[87:80];
            sel1 = picQ[95:88];
        end 
        6: begin
            sel0 = picQ[103:96];
            sel1 = picQ[111:104];
        end 
        7: begin
            sel0 = picQ[119:112];
            sel1 = picQ[127:120];
        end 
    endcase
end


always @(*) begin
    // default
    for (i=0 ; i<256 ; i=i+1) begin
        n_cdf_table[i][0] = cdf_table[i][0];
    end

    if (c_state == S_CDFTABLE0) begin
        if (sel0 == sel1)
            n_cdf_table[sel0][0] = cdf_table[sel0][0] + 2;
        else begin
            n_cdf_table[sel0][0] = cdf_table[sel0][0] + 1;
            n_cdf_table[sel1][0] = cdf_table[sel1][0] + 1;
        end
    end

    if (c_state == S_IDLE) begin
        for (i=0 ; i<256 ; i=i+1) begin
            n_cdf_table[i][0] = 0;
        end
    end
end

always @(*) begin
    n_cdf_table[0][1] = (c_state == S_IDLE) ? 0 : (c_state == S_CDFTABLE1) ? cdf_table[0][0] : cdf_table[0][1];
    for (i=1 ; i<256 ; i=i+1) begin
        n_cdf_table[i][1] = (c_state == S_IDLE) ? 0 : (c_state == S_CDFTABLE1) ? cdf_table[i][0] + cdf_table[i-1][1] : cdf_table[i][1];
    end
end

generate
for (m=0 ; m<256 ; m=m+1) begin : CDF_TABLE
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)     cdf_table[m][0] <= 0;
        else            cdf_table[m][0] <= n_cdf_table[m][0];
    end    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)     cdf_table[m][1] <= 0;
        else            cdf_table[m][1] <= n_cdf_table[m][1];
    end
end
endgenerate

// pixel
always @(*) begin
    pixel[0]  = picQ[7:0];
    pixel[1]  = picQ[15:8];
    pixel[2]  = picQ[23:16];
    pixel[3]  = picQ[31:24];
    pixel[4]  = picQ[39:32];
    pixel[5]  = picQ[47:40];
    pixel[6]  = picQ[55:48];
    pixel[7]  = picQ[63:56];
    pixel[8]  = picQ[71:64];
    pixel[9]  = picQ[79:72];
    pixel[10] = picQ[87:80];
    pixel[11] = picQ[95:88];
    pixel[12] = picQ[103:96];
    pixel[13] = picQ[111:104];
    pixel[14] = picQ[119:112];
    pixel[15] = picQ[127:120];
end


// cdf result
always @(*) begin
    for (i=0 ; i<16 ; i=i+1) begin
        cdf_result[i] = cdf_mapping_value[pixel[i]];
    end
end

// cdf mapping value
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) numerator <= 0;
    else        numerator <= ((cdf_table[n_counter[7:0]][1] - cdf_min) << 8) - (cdf_table[n_counter[7:0]][1] - cdf_min);
end
always @(*) begin
    hv          = (cdf_min == 4096) ? 0 : numerator / (4096 - cdf_min);
end
generate
for (m=0 ; m<256 ; m=m+1) begin    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) cdf_mapping_value[m] <= 0;
        else begin
            case (c_state)
                S_IDLE      : cdf_mapping_value[m] <= 0;
                S_CDF_DIV   : cdf_mapping_value[m] <= (counter[7:0] == m) ? hv : cdf_mapping_value[m]; 
            endcase
        end
    end
end
endgenerate

// cdf min
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cdf_min <= 0;
    else begin
        case (c_state)
            S_IDLE      : cdf_min <= 0;
            S_CDF_MIN   : cdf_min <= (cdf_min == 0) ? cdf_table[counter[7:0]][1] : cdf_min;            
        endcase
    end
end


// =====================================================================
//                             BUSY 
// =====================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) busy <= 0;
    else        busy <= (c_state == S_IDLE) ? 0 : 1;
end

    
endmodule