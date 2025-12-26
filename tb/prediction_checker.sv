// ============================================================================
// Prediction Checker
// Compares IFU predictions with ground truth
// ============================================================================
module prediction_checker(
    input wire clk,
    input wire rst_n,
    
    // From IFU
    input wire [31:0] fetch_pc,
    input wire prediction_made,
    input wire prediction,
    input wire [31:0] predicted_target,
    
    // Ground truth
    input wire [31:0] actual_pc,
    input wire actual_valid,
    input wire actual_taken,
    input wire [31:0] actual_target,
    
    // Statistics
    output reg [31:0] total_predictions,
    output reg [31:0] correct_predictions,
    output reg [31:0] incorrect_predictions,
    output reg [31:0] correct_targets,
    output reg [31:0] incorrect_targets
);

    reg match_found;
    reg prediction_correct;
    reg target_correct;
    
    always @(*) begin
        match_found = actual_valid && (fetch_pc == actual_pc);
        
        if (match_found) begin
            prediction_correct = (prediction == actual_taken);
            target_correct = (!actual_taken) || (predicted_target == actual_target);
        end else begin
            prediction_correct = 1'b0;
            target_correct = 1'b0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_predictions <= 0;
            correct_predictions <= 0;
            incorrect_predictions <= 0;
            correct_targets <= 0;
            incorrect_targets <= 0;
        end else if (prediction_made && match_found) begin
            total_predictions <= total_predictions + 1;
            
            if (prediction_correct) begin
                correct_predictions <= correct_predictions + 1;
            end else begin
                incorrect_predictions <= incorrect_predictions + 1;
            end
            
            if (actual_taken) begin
                if (target_correct) begin
                    correct_targets <= correct_targets + 1;
                end else begin
                    incorrect_targets <= incorrect_targets + 1;
                end
            end
        end
    end

endmodule
