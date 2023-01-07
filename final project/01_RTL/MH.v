// synopsys translate_off
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW_addsub_dx.v"
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW_minmax.v"
// synopsys translate_on
module MH(
    //Input Port
    clk,
    clk2,
    rst_n,
    in_valid,
    op_valid,
    op,
    pic_data,
    se_data,

    //Output Port
    out_valid,
    out_data
);

//==============================================//
//               Input and Output               //
//==============================================//

input wire          clk, clk2, rst_n, in_valid, op_valid;
input wire [2:0]    op;
input wire [31:0]   pic_data;
input wire [7:0]    se_data;

output reg          out_valid;
output reg [31:0]   out_data;


//==============================================//
//             Parameter and Integer            //
//==============================================//
integer i, j;
genvar  m, n;

localparam  IDLE        = 0,
            READ        = 1,
            EROSION     = 2,
            DILATION    = 3,
            LOAD_PIC    = 4,
            PDF         = 5,
            CDF         = 6,
            CDF_MIN     = 7,
            CDF_MAP     = 8,
            HIS_OUT     = 9
            ;

//==============================================//
//           Reg and Wire declaration           //
//==============================================//

// fsm
reg [3:0]   c_state, n_state;

// counter
reg [7:0]   counter, n_counter;
reg [8:0]   load_counter, n_load_counter;

// store op
reg [2:0]   operation;

// store se_data
reg [7:0]   se [0:3][0:3], n_se [0:3][0:3];

// whole 32 x 32 pic
reg [7:0]   pic [0:34][0:34], n_pic [0:34][0:34];

// erosion & dilation
reg [4:0]   ero_dila_sw_row;
reg [4:0]   offset;
reg [7:0]   c_se[0:3][0:3];
reg         min_max, add_sub;
reg [31:0]  ero_dila_out;

// histagram
reg [10:0]  pdf_table [0:255], n_pdf_table [0:255];
reg [10:0]  cdf_table [0:255], n_cdf_table [0:255];
reg [10:0]  cdf_min, n_cdf_min;
reg [7:0]   cdf_map [0:255], n_cdf_map[0:255];
reg [17:0]  numerator, n_numerator;
reg [9:0]   denominator, n_denominator;

// output
reg         n_out_valid;
reg [31:0]  n_out_data;

// sram
reg [7:0]       pic0_addr;  // 32 x 8 = 256, [7:3] --> row, [2:0] col
reg             pic0_wr;
reg [31:0]      pic0_D;
wire [31:0]     pic0_Q;

RAISH0  PIC0 (  
    .CLK(clk), 
    .CEN(1'b0),  
    .OEN(1'b0), 
    .WEN(pic0_wr),  
    .A(pic0_addr),  
    .D(pic0_D), 
    .Q(pic0_Q)
);

//==============================================//
//                   DESIGN                     //
//==============================================//

// fsm
always @(*) begin
    case (c_state)
        IDLE    : n_state = (in_valid == 1) ? READ : IDLE; 
        READ    : begin
            if (in_valid == 1)  n_state = READ;
            else begin
                case (operation)
                    // 000 -> (his)
                    3'b000  : n_state = PDF;
                    // dilation first
                    3'b011,
                    3'b111  : n_state = DILATION;
                    // erosion first
                    3'b110,
                    3'b010  : n_state = EROSION;      // erosion (pic - se --> min), dilation (pic + se --> max)
                    default : n_state = c_state;
                endcase
            end
        end
        EROSION : begin
            if (counter == 255)     n_state = (operation == 3'b010 || operation == 3'b111) ? IDLE : LOAD_PIC;
            else                    n_state = c_state;
        end
        DILATION: begin
            if (counter == 255)     n_state = (operation == 3'b011 || operation == 3'b110) ? IDLE : LOAD_PIC;
            else                    n_state = c_state;
        end 
        LOAD_PIC: begin
            case (operation)
                3'b110  : n_state = (load_counter == 256) ? DILATION    : c_state;
                3'b111  : n_state = (load_counter == 256) ? EROSION     : c_state;
                default : n_state = c_state;
            endcase
        end
        PDF     : n_state = (load_counter == 511) ? CDF     : c_state;
        CDF     : n_state = (load_counter == 255) ? CDF_MIN : c_state;
        CDF_MIN : n_state = (cdf_min != 0)        ? CDF_MAP : c_state;
        CDF_MAP : n_state = (counter == 255)      ? HIS_OUT : c_state;
        HIS_OUT : n_state = (counter == 255)      ? IDLE    : c_state;
        default : n_state = c_state; 
    endcase    
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     c_state <= IDLE;
    else            c_state <= n_state;
end


// all kinds of counters
always @(*) begin
    // counter
    if (in_valid == 1) 
        n_counter = counter + 1;
    else if (c_state != n_state) begin
        n_counter = 0;
    end else begin
        case (c_state)
            EROSION,
            DILATION,
            PDF,
            CDF_MIN,
            CDF_MAP,
            HIS_OUT,
            LOAD_PIC: n_counter = counter + 1; 
            default : n_counter = 0; 
        endcase
    end

    // load counter (also used for histagram)
    case (c_state)
        CDF_MIN,
        IDLE    : n_load_counter = 0;
        PDF,
        CDF,
        LOAD_PIC: n_load_counter = load_counter + 1; 
        default : n_load_counter = load_counter; 
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        counter         <= 0;
        load_counter    <= 0;
    end
    else begin
        counter         <= n_counter;
        load_counter    <= n_load_counter;
    end
end


// store op
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)     operation   <= 0;
    else            operation   <= (op_valid == 1) ? op : operation;
end


// store se_data
always @(*) begin
    for (i=0 ; i<=3 ; i=i+1) begin
        for (j=0 ; j<=2 ; j=j+1) begin
            n_se[i][j] = (in_valid == 1 && (0 <= counter && counter <= 15)) ? se[i][j+1] : se[i][j];
        end
    end
    n_se[0][3] = (in_valid == 1 && (0 <= counter && counter <= 15)) ? se[1][0] : se[0][3];
    n_se[1][3] = (in_valid == 1 && (0 <= counter && counter <= 15)) ? se[2][0] : se[1][3]; 
    n_se[2][3] = (in_valid == 1 && (0 <= counter && counter <= 15)) ? se[3][0] : se[2][3]; 

    // input put to last se[3][3]
    n_se[3][3] = (in_valid == 1 && (0 <= counter && counter <= 15)) ? se_data : se[3][3];
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i=0 ; i<=3 ; i=i+1) begin
            for (j=0 ; j<=3 ; j=j+1) begin
                se[i][j]    <= 0;
            end
        end
    end else begin
        for (i=0 ; i<=3 ; i=i+1) begin
            for (j=0 ; j<=3 ; j=j+1) begin
                se[i][j]    <= n_se[i][j];
            end
        end 
    end
end


// pic
always @(*) begin
    // default
    for (i=0 ; i<=34 ; i=i+1) begin
        for (j=0 ; j<=34 ; j=j+1) begin
            n_pic[i][j] = pic[i][j];
        end
    end

    // store inputs
    if (in_valid == 1) begin
        for (i=0 ; i<=31 ; i=i+1) begin
            for (j=0 ; j<=27 ; j=j+1) begin
                n_pic[i][j] = pic[i][j+4];
            end
        end
        for (i=0 ; i<=30 ; i=i+1) begin
            for (j=28 ; j<=31 ; j=j+1) begin
                n_pic[i][j] = pic[i+1][j-28];
            end
        end
        n_pic[31][28] = pic_data[7:0];
        n_pic[31][29] = pic_data[15:8];
        n_pic[31][30] = pic_data[23:16];
        n_pic[31][31] = pic_data[31:24];
    end

    // shift 4
    else if (c_state == LOAD_PIC || c_state == HIS_OUT) begin
        for (i=0 ; i<=31 ; i=i+1) begin
            for (j=0 ; j<=27 ; j=j+1) begin
                n_pic[i][j] = pic[i][j+4];
            end
        end
        for (i=0 ; i<=30 ; i=i+1) begin
            for (j=28 ; j<=31 ; j=j+1) begin
                n_pic[i][j] = pic[i+1][j-28];
            end
        end
        n_pic[31][28] = pic0_Q[7:0];
        n_pic[31][29] = pic0_Q[15:8];
        n_pic[31][30] = pic0_Q[23:16];
        n_pic[31][31] = pic0_Q[31:24];
    end

    // shift 2
    else if (c_state == PDF) begin
        for (i=0 ; i<=31 ; i=i+1) begin
            for (j=0 ; j<=29 ; j=j+1) begin
                n_pic[i][j] = pic[i][j+2];
            end
        end
        for (i=0 ; i<=30 ; i=i+1) begin
            n_pic[i][30] = pic[i+1][0];
            n_pic[i][31] = pic[i+1][1];
        end
        n_pic[31][30] = pic[0][0];
        n_pic[31][31] = pic[0][1];
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i=0 ; i<=34 ; i=i+1) begin
            for (j=0 ; j<=34 ; j=j+1) begin
                pic[i][j]   <= 0;
            end
        end
    end else begin
        for (i=0 ; i<=34 ; i=i+1) begin
            for (j=0 ; j<=34 ; j=j+1) begin
                pic[i][j]   <= n_pic[i][j];
            end
        end
    end
end


// erosion & dilation calculations (calculate 4 pixels at a time (4 * 8 = 32 bits))
always @(*) begin
    ero_dila_sw_row = counter[7:3];
    offset          = counter[2:0] << 2;
    case (c_state)
        DILATION: begin
            min_max = 1;    // 1 -> max
            add_sub = 0;    // 0 -> add
            for (i=0 ; i<=3 ; i=i+1) begin
                for (j=0 ; j<=3 ; j=j+1) begin
                    c_se[i][j] = se[3 - i][3 - j];
                end
            end
        end 
        default: begin
            min_max = 0;    // 0 -> min
            add_sub = 1;    // 1 -> sub
            for (i=0 ; i<=3 ; i=i+1) begin
                for (j=0 ; j<=3 ; j=j+1) begin
                    c_se[i][j] = se[i][j];
                end
            end
        end
    endcase
end

generate
for (m=0 ; m<=3 ; m=m+1) begin : selected_window
    reg [7:0]   sw  [0:3][0:3];
    wire [7:0]  cal [0:3][0:3];
    wire [7:0]  result;

    // sliding window
    always @(*) begin   
        sw[0][0] = pic[ero_dila_sw_row    ][m + 0 + offset];
        sw[0][1] = pic[ero_dila_sw_row    ][m + 1 + offset];
        sw[0][2] = pic[ero_dila_sw_row    ][m + 2 + offset];
        sw[0][3] = pic[ero_dila_sw_row    ][m + 3 + offset];
        sw[1][0] = pic[ero_dila_sw_row + 1][m + 0 + offset];
        sw[1][1] = pic[ero_dila_sw_row + 1][m + 1 + offset];
        sw[1][2] = pic[ero_dila_sw_row + 1][m + 2 + offset];
        sw[1][3] = pic[ero_dila_sw_row + 1][m + 3 + offset];
        sw[2][0] = pic[ero_dila_sw_row + 2][m + 0 + offset];
        sw[2][1] = pic[ero_dila_sw_row + 2][m + 1 + offset];
        sw[2][2] = pic[ero_dila_sw_row + 2][m + 2 + offset];
        sw[2][3] = pic[ero_dila_sw_row + 2][m + 3 + offset];
        sw[3][0] = pic[ero_dila_sw_row + 3][m + 0 + offset];
        sw[3][1] = pic[ero_dila_sw_row + 3][m + 1 + offset];
        sw[3][2] = pic[ero_dila_sw_row + 3][m + 2 + offset];
        sw[3][3] = pic[ero_dila_sw_row + 3][m + 3 + offset]; 
    end

    // CAL (DW), .addsub (1 -> sub, 0 -> add)
    DW_addsub_dx #(8) addsub0 (.a(sw[0][0]), .b(c_se[0][0]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[0][0]), .co1(), .co2());
    DW_addsub_dx #(8) addsub1 (.a(sw[0][1]), .b(c_se[0][1]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[0][1]), .co1(), .co2());
    DW_addsub_dx #(8) addsub2 (.a(sw[0][2]), .b(c_se[0][2]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[0][2]), .co1(), .co2());
    DW_addsub_dx #(8) addsub3 (.a(sw[0][3]), .b(c_se[0][3]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[0][3]), .co1(), .co2());
    DW_addsub_dx #(8) addsub4 (.a(sw[1][0]), .b(c_se[1][0]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[1][0]), .co1(), .co2());
    DW_addsub_dx #(8) addsub5 (.a(sw[1][1]), .b(c_se[1][1]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[1][1]), .co1(), .co2());
    DW_addsub_dx #(8) addsub6 (.a(sw[1][2]), .b(c_se[1][2]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[1][2]), .co1(), .co2());
    DW_addsub_dx #(8) addsub7 (.a(sw[1][3]), .b(c_se[1][3]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[1][3]), .co1(), .co2());
    DW_addsub_dx #(8) addsub8 (.a(sw[2][0]), .b(c_se[2][0]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[2][0]), .co1(), .co2());
    DW_addsub_dx #(8) addsub9 (.a(sw[2][1]), .b(c_se[2][1]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[2][1]), .co1(), .co2());
    DW_addsub_dx #(8) addsubA (.a(sw[2][2]), .b(c_se[2][2]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[2][2]), .co1(), .co2());
    DW_addsub_dx #(8) addsubB (.a(sw[2][3]), .b(c_se[2][3]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[2][3]), .co1(), .co2());
    DW_addsub_dx #(8) addsubC (.a(sw[3][0]), .b(c_se[3][0]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[3][0]), .co1(), .co2());
    DW_addsub_dx #(8) addsubD (.a(sw[3][1]), .b(c_se[3][1]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[3][1]), .co1(), .co2());
    DW_addsub_dx #(8) addsubE (.a(sw[3][2]), .b(c_se[3][2]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[3][2]), .co1(), .co2());
    DW_addsub_dx #(8) addsubF (.a(sw[3][3]), .b(c_se[3][3]), .ci1(1'b0), .ci2(1'b0), .addsub(add_sub), .tc(1'b0), .sat(1'b1), .avg(1'b0), .dplx(1'b0), .sum(cal[3][3]), .co1(), .co2());

    // compare (DW), .min_max (0 -> min, 1 -> max)
    DW_minmax #(8, 16) minmax0 (.a(
        {
            cal[0][0], cal[0][1], cal[0][2], cal[0][3], 
            cal[1][0], cal[1][1], cal[1][2], cal[1][3], 
            cal[2][0], cal[2][1], cal[2][2], cal[2][3], 
            cal[3][0], cal[3][1], cal[3][2], cal[3][3]
        }
    ), .tc(1'b0), .min_max(min_max), .value(result), .index());
end
endgenerate

always @(*) begin
    ero_dila_out = { 
        selected_window[3].result, 
        selected_window[2].result, 
        selected_window[1].result, 
        selected_window[0].result 
    };
end


// sram controls
always @(*) begin
    case (c_state)
        EROSION: begin
            pic0_wr     = 0; 
            pic0_addr   = counter;
            pic0_D      = ero_dila_out;
        end
        DILATION: begin
            pic0_wr     = 0; 
            pic0_addr   = counter;
            pic0_D      = ero_dila_out;
        end
        LOAD_PIC: begin
            pic0_wr     = 1; // read
            pic0_addr   = counter;
            pic0_D      = 0;
        end
        default : begin
            pic0_wr     = 1; // default read 
            pic0_addr   = 0;
            pic0_D      = 0;
        end
    endcase
end


// histagram
// pdf
always @(*) begin
    // default
    for (i=0 ; i<=255 ; i=i+1) begin
        n_pdf_table[i] = pdf_table[i];
    end
    // update
    case (c_state)
        IDLE    : begin
            for (i=0 ; i<=255 ; i=i+1) begin
                n_pdf_table[i] = 0;
            end
        end 
        PDF     : begin
            if (pic[0][0] == pic[0][1]) begin
                n_pdf_table[ pic[0][0] ] = pdf_table[ pic[0][0] ] + 2;
            end else begin
                n_pdf_table[ pic[0][0] ] = pdf_table[ pic[0][0] ] + 1;
                n_pdf_table[ pic[0][1] ] = pdf_table[ pic[0][1] ] + 1;
            end
        end
    endcase
end


// cdf
always @(*) begin
    // default
    for (i=0 ; i<=255 ; i=i+1) begin
        n_cdf_table[i] = cdf_table[i];
    end
    // update
    if (c_state == IDLE) begin
        for (i=0 ; i<=255 ; i=i+1) begin
            n_cdf_table[i] = 0;
        end
    end 

    else if (c_state == CDF) begin
        n_cdf_table[0] = pdf_table[0];
        for (i=1 ; i<=255 ; i=i+1) begin
            n_cdf_table[i] = cdf_table[i-1] + pdf_table[i];
        end
    end
end


// cdf min
always @(*) begin
    case (c_state)
        IDLE    : n_cdf_min = 0;
        CDF_MIN : n_cdf_min = (cdf_table[ counter ] != 0 && cdf_min == 0)  ? cdf_table[ counter ] : cdf_min;
        default : n_cdf_min = cdf_min; 
    endcase
end


// cdf map
always @(*) begin
    // default
    for (i=0 ; i<=255 ; i=i+1) begin
        n_cdf_map[i] = cdf_map[i];
    end
    n_numerator     = ((cdf_table[n_counter] - cdf_min) << 8) - (cdf_table[n_counter] - cdf_min);
    n_denominator   = 1024 - cdf_min;
    // update
    case (c_state)
        IDLE    : begin
            for (i=0 ; i<=255 ; i=i+1) begin
                n_cdf_map[i] = 0;
            end
        end 
        CDF_MAP : begin
            n_cdf_map[255] = (denominator == 0) ? 0 : numerator / denominator;
            for (i=0 ; i<=254 ; i=i+1) begin
                n_cdf_map[i] = cdf_map[i+1];
            end
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        numerator   <= 0;
        denominator <= 1024;
        cdf_min     <= 0;
        for (i=0 ; i<=255 ; i=i+1) begin
            pdf_table[i]    <= 0;
            cdf_table[i]    <= 0;
            cdf_map[i]      <= 0;
        end
    end else begin
        numerator   <= n_numerator;
        denominator <= n_denominator;
        cdf_min     <= n_cdf_min;
        for (i=0 ; i<=255 ; i=i+1) begin
            pdf_table[i]    <= n_pdf_table[i];
            cdf_table[i]    <= n_cdf_table[i];
            cdf_map[i]      <= n_cdf_map[i];
        end
    end
end


// output
always @(*) begin
    case (c_state)
        EROSION : begin
            n_out_valid = (operation == 3'b010 || operation == 3'b111) ? 1 : 0;
            n_out_data  = (operation == 3'b010 || operation == 3'b111) ? ero_dila_out : 0;
        end 
        DILATION: begin
            n_out_valid = (operation == 3'b011 || operation == 3'b110) ? 1 : 0;
            n_out_data  = (operation == 3'b011 || operation == 3'b110) ? ero_dila_out : 0;
        end
        HIS_OUT : begin
            n_out_valid = 1;
            n_out_data  = {
                cdf_map[pic[0][3]],
                cdf_map[pic[0][2]],
                cdf_map[pic[0][1]],
                cdf_map[pic[0][0]]
            };
        end
        default : begin
            n_out_valid = 0; 
            n_out_data  = 0;
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid   <= 0;
        out_data    <= 0;
    end else begin
        out_valid   <= n_out_valid;
        out_data    <= n_out_data;
    end
end


endmodule 