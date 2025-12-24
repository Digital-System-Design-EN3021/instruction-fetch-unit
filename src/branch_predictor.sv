// 2-bit Saturating Counter States

`define STRONG_NOT_TAKEN 2'b00
`define WEAK_NOT_TAKEN   2'b01
`define WEAK_TAKEN       2'b10
`define STRONG_TAKEN     2'b11

// ============================================================================
// Branch Predictor Module
// Implements 2-bit saturating counter with BHT and BTB
// ============================================================================
module branch_predictor #(
    parameter BHT_SIZE = 256,  // Number of entries in BHT
    parameter BTB_SIZE = 256   // Number of entries in BTB
)(
    input wire clk,
    input wire rst_n,
    
    // Prediction request
    input wire [31:0] pc_in,
    input wire predict_enable,
    output reg prediction,           // 1 = taken, 0 = not taken
    output reg [31:0] predicted_target,
    output reg prediction_valid,
    
    // Update from execution stage
    input wire update_enable,
    input wire [31:0] update_pc,
    input wire update_taken,
    input wire [31:0] update_target
);

    // BHT - stores 2-bit saturating counters
    reg [1:0] bht [0:BHT_SIZE-1];
    
    // BTB - stores branch target addresses
    reg [31:0] btb_target [0:BTB_SIZE-1];
    reg [31:0] btb_tag [0:BTB_SIZE-1];
    reg btb_valid [0:BTB_SIZE-1];
    
    // Index calculation
    wire [7:0] predict_index = pc_in[9:2];
    wire [7:0] update_index = update_pc[9:2];
    
    integer i;
    
    // Initialize
    initial begin
        for (i = 0; i < BHT_SIZE; i = i + 1) begin
            bht[i] = `WEAK_NOT_TAKEN;
            btb_valid[i] = 0;
        end
    end
    
    // Prediction logic
    always @(*) begin
        if (predict_enable) begin
            // Check if branch is in BTB
            if (btb_valid[predict_index] && (btb_tag[predict_index] == pc_in)) begin
                prediction_valid = 1'b1;
                predicted_target = btb_target[predict_index];
                // Predict taken if counter >= 2 (WEAK_TAKEN or STRONG_TAKEN)
                prediction = bht[predict_index][1];
            end else begin
                prediction_valid = 1'b0;
                predicted_target = 32'h0;
                prediction = 1'b0;
            end
        end else begin
            prediction_valid = 1'b0;
            predicted_target = 32'h0;
            prediction = 1'b0;
        end
    end
    
    // Update logic (on clock edge)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < BHT_SIZE; i = i + 1) begin
                bht[i] <= `WEAK_NOT_TAKEN;
                btb_valid[i] <= 0;
            end
        end else if (update_enable) begin
            // Update BTB
            btb_tag[update_index] <= update_pc;
            btb_target[update_index] <= update_target;
            btb_valid[update_index] <= 1'b1;
            
            // Update 2-bit saturating counter
            case (bht[update_index])
                `STRONG_NOT_TAKEN: begin
                    if (update_taken)
                        bht[update_index] <= `WEAK_NOT_TAKEN;
                end
                
                `WEAK_NOT_TAKEN: begin
                    if (update_taken)
                        bht[update_index] <= `WEAK_TAKEN;
                    else
                        bht[update_index] <= `STRONG_NOT_TAKEN;
                end
                
                `WEAK_TAKEN: begin
                    if (update_taken)
                        bht[update_index] <= `STRONG_TAKEN;
                    else
                        bht[update_index] <= `WEAK_NOT_TAKEN;
                end
                
                `STRONG_TAKEN: begin
                    if (!update_taken)
                        bht[update_index] <= `WEAK_TAKEN;
                end
            endcase
        end
    end

endmodule