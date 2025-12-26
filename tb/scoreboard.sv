// ============================================================================
// Scoreboard - Tracks expected vs actual behavior
// ============================================================================
module scoreboard;
    
    integer fetch_count;
    integer branch_count;
    integer misprediction_count;
    integer correct_prediction_count;
    integer sequential_fetch_count;
    
    initial begin
        fetch_count = 0;
        branch_count = 0;
        misprediction_count = 0;
        correct_prediction_count = 0;
        sequential_fetch_count = 0;
    end
    
    task record_fetch;
        input [31:0] pc;
        input [31:0] instruction;
        begin
            fetch_count = fetch_count + 1;
            $display("[SCOREBOARD] Fetch #%0d: PC=0x%h, Instruction=0x%h", 
                     fetch_count, pc, instruction);
        end
    endtask
    
    task record_branch;
        input taken;
        input [31:0] target;
        begin
            branch_count = branch_count + 1;
            if (taken)
                $display("[SCOREBOARD] Branch #%0d: TAKEN, Target=0x%h", 
                         branch_count, target);
            else
                $display("[SCOREBOARD] Branch #%0d: NOT TAKEN", branch_count);
        end
    endtask
    
    task record_prediction;
        input correct;
        begin
            if (correct) begin
                correct_prediction_count = correct_prediction_count + 1;
                $display("[SCOREBOARD] Prediction: CORRECT");
            end else begin
                misprediction_count = misprediction_count + 1;
                $display("[SCOREBOARD] Prediction: MISPREDICTED");
            end
        end
    endtask
    
    task print_statistics;
        begin
            $display("\n========================================");
            $display("VERIFICATION STATISTICS");
            $display("========================================");
            $display("Total Fetches:          %0d", fetch_count);
            $display("Total Branches:         %0d", branch_count);
            $display("Correct Predictions:    %0d", correct_prediction_count);
            $display("Mispredictions:         %0d", misprediction_count);
            if (branch_count > 0)
                $display("Prediction Accuracy:    %.2f%%", 
                         (correct_prediction_count * 100.0) / branch_count);
            $display("Sequential Fetches:     %0d", sequential_fetch_count);
            $display("========================================\n");
        end
    endtask

endmodule