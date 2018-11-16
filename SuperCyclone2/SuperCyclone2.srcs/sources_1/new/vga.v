`timescale 1ns / 1ns

module vga #(
    parameter H_VISI = 1024,
    parameter H_FRPO = 1056-1024,
    parameter H_SYNP = 1224-1056,
    parameter H_BKPO = 1256-1224,
    parameter V_VISI = 576,
    parameter V_FRPO = 587-576,
    parameter V_SYNP = 593-578,
    parameter V_BKPO = 605-593 
)
(
    input clk,
    input rst,
    output hsync,
    output vsync,
    output [10:0] x,
    output [9:0] y,
    output reg [10:0] xNext,
    output reg [9:0] yNext,
    output inplace
    );
    localparam H_ALL = H_VISI + H_FRPO + H_SYNP + H_BKPO;
    localparam V_ALL = V_VISI + V_FRPO + V_SYNP + V_BKPO;
    localparam H_VISI_END = H_VISI;
    localparam H_FRPO_END = H_VISI + H_FRPO;
    localparam H_SYNP_END = H_VISI + H_FRPO + H_SYNP;
    localparam H_BKPO_END = H_VISI + H_FRPO + H_SYNP + H_BKPO;
    localparam V_VISI_END = V_VISI;
    localparam V_FRPO_END = V_VISI + V_FRPO;
    localparam V_SYNP_END = V_VISI + V_FRPO + V_SYNP;
    localparam V_BKPO_END = V_VISI + V_FRPO + V_SYNP + V_BKPO;

    
    reg [10:0] h_cnt_r = 0;
    reg [9:0] v_cnt_r = 0;
    reg hsync_r = 1;
    reg vsync_r = 1;
    reg h_inplace = 0;
    reg v_inplace = 0;
    
    always @(posedge clk) begin
        if(rst) begin
            h_cnt_r <= 0;
            v_cnt_r <= 0;
        end
        else begin
            if(h_cnt_r < H_VISI_END)begin
                h_cnt_r <= h_cnt_r + 1;
                h_inplace <= 1;
            end
            else if (h_cnt_r >= H_VISI_END && h_cnt_r < H_FRPO_END) begin
                h_cnt_r <= h_cnt_r + 1;
                h_inplace <= 0;
            end
            else if (h_cnt_r >= H_FRPO_END && h_cnt_r < H_SYNP_END) begin
                h_cnt_r <= h_cnt_r + 1;
                hsync_r <= 0;
            end
            else if (h_cnt_r >= H_SYNP_END && h_cnt_r < H_BKPO_END - 1) begin
                h_cnt_r <= h_cnt_r + 1;
                hsync_r <= 1;
            end
            else if(h_cnt_r == H_BKPO_END - 1)
            begin
                h_cnt_r <= 0;
                if(v_cnt_r < V_VISI_END)begin
                    v_cnt_r <= v_cnt_r + 1;
                    v_inplace <= 1;
                end
                else if (v_cnt_r >= V_VISI_END && v_cnt_r < V_FRPO_END) begin
                    v_cnt_r <= v_cnt_r + 1;
                    v_inplace <= 0;
                end
                else if (v_cnt_r >= V_FRPO_END && v_cnt_r < V_SYNP_END) begin
                    v_cnt_r <= v_cnt_r + 1;
                    vsync_r <= 0;
                end
                else if (v_cnt_r >= V_SYNP_END && v_cnt_r < V_BKPO_END - 1) begin
                    v_cnt_r <= v_cnt_r + 1;
                    vsync_r <= 1;
                end
                else if(v_cnt_r == V_BKPO_END - 1) begin
                    v_cnt_r <= 0;
                    v_inplace <= 1;
                end
                else begin
                    v_cnt_r <= 0;
                    v_inplace <= 0;
                    vsync_r <= 1;
                end
            end
            else begin
                h_cnt_r <= 0;
                h_inplace <= 1;
                hsync_r <= 1;
            end
        end
    end
    
    assign hsync = hsync_r;
    assign vsync = vsync_r;
    assign x = (h_cnt_r < H_VISI_END) ? h_cnt_r : 0;
    assign y = (v_cnt_r < V_VISI_END) ? v_cnt_r : 0;
    
    always @* begin
        if (v_cnt_r < V_VISI_END && h_cnt_r < H_VISI_END - 1)
            xNext = h_cnt_r + 1;
        else
            xNext = 0;

        if (v_cnt_r < V_VISI_END && h_cnt_r < H_VISI_END - 1)
            yNext = v_cnt_r;
        else if (v_cnt_r < V_VISI_END - 1 && h_cnt_r >= H_VISI_END - 1)
            yNext = v_cnt_r + 1;
        else
            yNext = 0;
    end
    
    assign inplace = h_inplace && v_inplace;
endmodule
    