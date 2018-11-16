module CLZAlgorithm(
    input clk,
    input [31:0] A,
    input ena,
    output [5:0] R,  //Max: 32, 6 bits
    output busy
);
    reg lastEna;
    reg [7:0] counter;
    localparam COUNTER_CYCLE = 25;

    always @(posedge clk) begin
        // negedge of main clk
        lastEna <= ena;
        if (ena != lastEna)
        begin
            counter <= 0;
        end
        else if (ena) begin
            counter <= counter + 1;
        end
    end

    assign busy = ena & (counter != COUNTER_CYCLE);

    generate
        genvar i;

        wire [31:0] A_Encoded;

        for(i = 0; i < 16; i = i+1)
        begin : A_Encoding
            assign A_Encoded[i*2 +: 2] = (A[i*2 +: 2] == 2'b00) ? 2'b10 : (A[i*2 +: 2] == 2'b01) ? 2'b01 : 2'b00;
        end

        wire [23:0] A_1;
        
        for(i = 0; i < 8; i = i+1)
        begin : A_1_Assembling
            assign A_1[i*3 +: 3] = (A_Encoded[i*4+3] & A_Encoded[i*4+1]) ? (3'b100) : (A_Encoded[i*4+3] == 0) ? ({1'b0, A_Encoded[i*4 + 2 +: 2]}) : {2'b01,A_Encoded[i*4 +: 1]};
        end

        wire [15:0] A_2;

        for(i = 0; i < 4; i = i+1)
        begin : A_2_Assembling
            assign A_2[i*4 +: 4] = (A_1[i*6+5] & A_1[i*6+2]) ? (4'b1000) : (A_1[i*6+5] == 0) ? ({1'b0, A_1[i*6 + 3 +: 3]}) : {2'b01, A_1[i*6 +: 2]};
        end

        wire [9:0] A_3;
        for(i = 0; i < 2; i = i+1)
        begin : A_3_Assembling
            assign A_3[i*5 +: 5] = (A_2[i*8+7] & A_2[i*8+3]) ? (5'b10000) : (A_2[i*8+7] == 0) ? ({1'b0, A_2[i*8 + 4 +: 4]}) : {2'b01, A_2[i*8 +: 3]};
        end

        wire [5:0] A_4;
        assign A_4 = (A_3[9] & A_3[4]) ? (6'b100000) : (A_3[9] == 0) ? ({1'b0, A_3[5 +: 5]}) : {2'b01, A_3[0 +: 4]};
    endgenerate
    
    assign R = A_4;
endmodule