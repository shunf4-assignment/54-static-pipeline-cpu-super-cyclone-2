`timescale 1ns/1ns
`include "sdHeader.vh"
/* SPI 控制器。驱动 SPI 总线. */
module spi_controller(
    input clk,  // 系统时钟，不一定是 SPI 实际操作 SD 卡的控制时钟。主要用于这个控制器的内部状态机。
    input rst,
    
    input en,

    input iClk74En,
    output reg oClk74Ok,

    input iTxEn,
    output reg oTxOk,
    input [7:0] iTxData,

    output reg oRxOk,
    input iRxEn,
    output reg [7:0] oRxData,

    output reg oClk8Ok,
    input iClk8En,

    output SPI_CLK,
    output SPI_MOSI,
    input SPI_MISO,
    output SPI_CSn,
    output SD_RESET,

    output reg [4:0] spiState,

    input [1:0] speedChoice
);
        localparam T_HALFSPICLK_TICKS = 9'd175;   //285kHz
        localparam T_HALFSPICLK_TICKS_HS = 9'd4;   //12.5MHz
        localparam T_HALFSPICLK_TICKS_ULTRA_HS = 9'd2;   //25MHz
        localparam T_HALFSPICLK_TICKS_EXTREME_HS = 9'd1;   //50MHz

        wire[8:0] t_halfspiclk_ticks;
        assign t_halfspiclk_ticks = 
            (speedChoice == 0) ? T_HALFSPICLK_TICKS
            : (speedChoice == 1) ? T_HALFSPICLK_TICKS_HS
            : (speedChoice == 2) ? T_HALFSPICLK_TICKS_ULTRA_HS
            : T_HALFSPICLK_TICKS_EXTREME_HS ;

        localparam T_74CLK_TICKS = 9'd80;
        localparam T_8CLK_TICKS = 7'h10;

        localparam S_INIT = 5'd0;
        localparam S_CLK74_RISE = 5'd1;
        localparam S_CLK74_FALL = 5'd2;
        localparam S_CLK74_DONE = 5'd3;
        localparam S_CLK74_RESET = 5'd4;

        localparam S_TX_LOAD = 5'd1; //加载下一个bit，同时时钟下降
        localparam S_TX_RISE = 5'd2; //时钟上升，该数据写入
        localparam S_TX_DONE = 5'd3;
        localparam S_TX_RESET = 5'd4;

        localparam S_RX_LOAD = 5'd1; //时钟上升，读入数据
        localparam S_RX_FALL = 5'd2; //时钟下降，进行字节是否读完的检测
        localparam S_RX_DONE = 5'd3;
        localparam S_RX_RESET = 5'd4;

        reg SPI_CLK_r;
        reg SPI_CSn_r;
        reg SPI_MOSI_r;
        reg SD_RESET_r;

        assign SPI_CLK = en ? SPI_CLK_r : 1'bz;
        assign SPI_CSn = en ? SPI_CSn_r : 1'bz;
        assign SPI_MOSI = en ? SPI_MOSI_r : 1'bz;
        assign SD_RESET = en ? SD_RESET_r : 1'b1;

        //需要计数输出时钟的场景：
        //      clk74, tx, rx, clk8

        reg [8:0] clk_cnt = 0;
        reg [8:0] spiclk_cnt = 0;
        reg [3:0] bit_cnt = 0;
        reg [7:0] read_byte = 0;

        //用于产生SPI时钟的计数器
        reg spiclk_ena = 0;
        always @(posedge clk) begin
            if(rst) begin
                clk_cnt <= 0;
            end else begin
                if(clk_cnt == t_halfspiclk_ticks - 1)
                    clk_cnt <= 8'd0;
                else if(spiclk_ena)
                    clk_cnt <= clk_cnt + 1;
                else
                    clk_cnt <= 0;
            end
        end

        

        always @(posedge clk) begin
            if(rst) begin
                SPI_CLK_r <= `Disabled;    //SPI MODE 0
                SPI_CSn_r <= `Enabled;
                spiState <= S_INIT;
                SPI_MOSI_r <= `Enabled;
                oClk74Ok <= `Disabled;
                oTxOk <= `Disabled;
                oRxOk <= `Disabled;
                oRxData <= `Disabled;
                oClk8Ok <= `Disabled;
                SD_RESET_r <= `Disabled;
                
                spiclk_ena <= `Disabled;

                spiclk_cnt <= 0;
                bit_cnt <= 0;
                read_byte <= 0;
            end
            else if(iClk74En) begin
                spiclk_ena <= `Enabled;
                case (spiState)
                    S_INIT:
                    begin
                        SPI_CSn_r <= `Disabled;
                        SPI_MOSI_r <= `Enabled;
                        spiState <= spiState + 1;
                    end

                    S_CLK74_RISE:
                    begin
                        if(spiclk_cnt == T_74CLK_TICKS)
                        begin
                            spiclk_cnt <= 8'd0;
                            spiState <= S_CLK74_DONE;
                        end else if (clk_cnt == t_halfspiclk_ticks - 1) begin
                            SPI_CLK_r <= 1'b1;
                            spiclk_cnt <= spiclk_cnt + 1;
                            spiState <= spiState + 1;
                        end
                    end

                    S_CLK74_FALL:
                    begin
                        if(clk_cnt == t_halfspiclk_ticks - 1)begin
                            SPI_CLK_r <= `Disabled;
                            spiState <= spiState - 1;
                        end
                    end

                    S_CLK74_DONE:
                    begin
                        oClk74Ok <= 1'b1;
                        SPI_CSn_r <= 1'b1;                        
                        spiState <= spiState + 1;
                    end

                    default:
                    begin
                        oClk74Ok <= 1'b0;
                        SPI_CSn_r <= 1'b1;
                        spiState <= S_INIT;
                        spiclk_ena <= 1'b0;
                    end

                endcase
            end
            else if(iClk8En) begin
                spiclk_ena <= 1'b1;
                case (spiState)
                    S_INIT:
                    begin
                        SPI_CSn_r <= 1'b1;
                        SPI_MOSI_r <= 1'b1;
                        spiState <= spiState + 1;
                    end

                    S_CLK74_RISE:
                    begin
                        if(spiclk_cnt == T_8CLK_TICKS)
                        begin
                            spiclk_cnt <= 8'd0;
                            spiState <= S_CLK74_DONE;
                        end else if (clk_cnt == t_halfspiclk_ticks - 1) begin
                            SPI_CLK_r <= 1'b1;
                            spiclk_cnt <= spiclk_cnt + 1;
                            spiState <= spiState + 1;
                        end
                    end

                    S_CLK74_FALL:
                    begin
                        if(clk_cnt == t_halfspiclk_ticks - 1)begin
                            SPI_CLK_r <= 1'b0;
                            spiState <= spiState - 1;
                        end
                    end

                    S_CLK74_DONE:
                    begin
                        oClk8Ok <= 1'b1;
                        spiState <= spiState + 1;
                    end

                    default:        //RESET
                    begin
                        oClk8Ok <= 1'b0;
                        SPI_CSn_r <= 1'b1;
                        spiState <= S_INIT;
                        spiclk_ena <= 1'b0;
                    end

                endcase
            end else if(iTxEn) begin
                spiclk_ena <= 1'b1;
                case (spiState)
                    S_INIT:
                    begin
                        spiState <=spiState + 1;
                        bit_cnt <= 'd8;
                        SPI_CLK_r <= 1'b0;
                        SPI_CSn_r <= 1'b0;
                    end
                    S_TX_LOAD:
                    begin
                        //从高位到低位传
                        if(clk_cnt == t_halfspiclk_ticks - 1) begin
                            SPI_MOSI_r <= iTxData[bit_cnt - 1];
                            bit_cnt <= bit_cnt - 1;
                            spiState <= spiState + 1;
                            SPI_CLK_r <= 0;
                        end
                    end
                    S_TX_RISE:
                    begin
                        if(clk_cnt == t_halfspiclk_ticks - 1) begin
                            SPI_CLK_r <= 1;
                            if(bit_cnt == 0)begin
                                //传完了
                                spiState <= spiState + 1;
                            end else begin
                                spiState <= spiState - 1;
                            end
                        end
                    end
                    S_TX_DONE:
                    begin
                        //在最后一次置上升沿后，再停留半个时钟周期
                        if(clk_cnt == t_halfspiclk_ticks - 1) begin
                            SPI_CLK_r <= 1'b0;
                            SPI_CSn_r <= 1'b1;
                            oTxOk <= 1'b1;
                            spiState <= spiState + 1;
                        end
                    end
                    default:
                    begin
                        SPI_CLK_r <= 1'b0;
                        SPI_CSn_r <= 1'b1;
                        SPI_MOSI_r <= 1'b1;
                        oTxOk <= 1'b0;
                        spiclk_ena <= 1'b0;
                        spiState <= S_INIT;
                    end
                endcase
            end else if(iRxEn) begin
                spiclk_ena <= 1'b1;
                case (spiState)
                    S_INIT:
                    begin
                      spiState <= spiState + 1;
                      bit_cnt <= 'd0;
                      SPI_CLK_r <= 1'b0;
                      SPI_CSn_r <= 1'b0;
                      SPI_MOSI_r <= 1'b1;
                    end

                    S_RX_LOAD:
                    begin
                        if(clk_cnt == t_halfspiclk_ticks - 1) begin
                            SPI_CLK_r <= 1;
                            oRxData <= {oRxData[6:0], SPI_MISO};
                            bit_cnt <= bit_cnt + 1;
                            spiState <= spiState + 1;
                        end
                    end

                    S_RX_FALL:
                    begin
                        if(clk_cnt == t_halfspiclk_ticks - 1) begin
                            SPI_CLK_r <= 0;
                            if(bit_cnt == 8)
                                spiState <= spiState + 1;
                            else
                                spiState <= spiState - 1;
                        end
                    end

                    S_RX_DONE:
                    begin
                      SPI_CLK_r <= 1'b0;
                      SPI_CSn_r <= 1'b1;
                      oRxOk <= 1'b1;
                      spiState <= spiState + 1;
                    end

                    default:
                    begin
                      SPI_CLK_r <= 1'b0;
                      SPI_CSn_r <= 1'b1;
                      oRxOk <= 1'b0;
                      spiclk_ena <= 1'b0;
                      spiState <= S_INIT;
                    end
                endcase
            end
            else begin
                spiclk_ena <= 1'b0;
            end
        end

endmodule