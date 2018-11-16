`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/11/20 09:34:56
// Design Name: 
// Module Name: Divider
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module freqDivider #(
    parameter twoPower = 14
)(
    input clk_i,
    input reset,
    output clk_o
    );
    
    reg [twoPower - 1:0] counter;

    always@(posedge clk_i)
    begin
        if(reset)
            counter <= 0;
        else
            counter <= counter + 1;
    end

    assign clk_o = counter[twoPower - 1];

endmodule
