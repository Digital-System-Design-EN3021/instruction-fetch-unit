// ============================================================================
// Coverage Monitor - Functional Coverage
// ============================================================================
module coverage_monitor(
    input wire clk,
    input wire rst_n,
    input wire [31:0] pc,
    input wire instruction_valid,
    input wire branch_taken,
    input wire branch_resolved,
    input wire prediction,
    input wire prediction_valid,
    input wire prefetch_full,
    input wire prefetch_empty,
    input wire stall
);

    // Coverage bins
    reg sequential_fetch_covered;
    reg branch_taken_covered;
    reg branch_not_taken_covered;
    reg prediction_correct_covered;
    reg prediction_incorrect_covered;
    reg buffer_full_covered;
    reg buffer_empty_covered;
    reg stall_condition_covered;
    
    initial begin
        sequential_fetch_covered = 0;
        branch_taken_covered = 0;
        branch_not_taken_covered = 0;
        prediction_correct_covered = 0;
        prediction_incorrect_covered = 0;
        buffer_full_covered = 0;
        buffer_empty_covered = 0;
        stall_condition_covered = 0;
    end
    
    always @(posedge clk) begin
        if (rst_n) begin
            // Cover sequential fetch
            if (instruction_valid && !branch_resolved)
                sequential_fetch_covered = 1;
            
            // Cover branch outcomes
            if (branch_resolved) begin
                if (branch_taken)
                    branch_taken_covered = 1;
                else
                    branch_not_taken_covered = 1;
            end
            
            // Cover buffer states
            if (prefetch_full)
                buffer_full_covered = 1;
            if (prefetch_empty)
                buffer_empty_covered = 1;
            
            // Cover stall
            if (stall)
                stall_condition_covered = 1;
        end
    end
    
    task print_coverage;
        integer total_bins;
        integer covered_bins;
        begin
            total_bins = 8;
            covered_bins = sequential_fetch_covered + branch_taken_covered + 
                          branch_not_taken_covered + prediction_correct_covered +
                          prediction_incorrect_covered + buffer_full_covered +
                          buffer_empty_covered + stall_condition_covered;
            
            $display("\n========================================");
            $display("FUNCTIONAL COVERAGE REPORT");
            $display("========================================");
            $display("Sequential Fetch:       %s", sequential_fetch_covered ? "COVERED" : "NOT COVERED");
            $display("Branch Taken:           %s", branch_taken_covered ? "COVERED" : "NOT COVERED");
            $display("Branch Not Taken:       %s", branch_not_taken_covered ? "COVERED" : "NOT COVERED");
            $display("Prediction Correct:     %s", prediction_correct_covered ? "COVERED" : "NOT COVERED");
            $display("Prediction Incorrect:   %s", prediction_incorrect_covered ? "COVERED" : "NOT COVERED");
            $display("Buffer Full:            %s", buffer_full_covered ? "COVERED" : "NOT COVERED");
            $display("Buffer Empty:           %s", buffer_empty_covered ? "COVERED" : "NOT COVERED");
            $display("Stall Condition:        %s", stall_condition_covered ? "COVERED" : "NOT COVERED");
            $display("----------------------------------------");
            $display("Coverage: %0d/%0d bins (%.1f%%)", covered_bins, total_bins, 
                     (covered_bins * 100.0) / total_bins);
            $display("========================================\n");
        end
    endtask

endmodule
