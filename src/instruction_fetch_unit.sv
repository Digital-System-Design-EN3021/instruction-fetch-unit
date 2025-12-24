
// ============================================================================
// Instruction Fetch Unit (Top Module)
// Integrates prefetch buffer and branch predictor
// ============================================================================
module instruction_fetch_unit(
    input wire clk,
    input wire rst_n,
    
    // Interface to instruction memory
    output reg [31:0] mem_addr,
    output reg mem_read,
    input wire [31:0] mem_data,
    input wire mem_ready,
    
    // Interface to decode/execute stage
    output wire [31:0] instruction,
    output wire [31:0] instruction_pc,
    output wire instruction_valid,
    input wire fetch_next,
    
    // Branch resolution from execute stage
    input wire branch_resolved,
    input wire branch_taken,
    input wire [31:0] branch_pc,
    input wire [31:0] branch_target,
    
    // Control signals
    input wire stall,
    output wire prefetch_full,
    output wire prefetch_empty
);

    // Internal signals
    wire prediction;
    wire [31:0] predicted_target;
    wire prediction_valid;
    reg [31:0] current_pc;
    reg [31:0] next_pc;
    
    wire prefetch_write_enable;
    wire prefetch_read_enable;
    wire [3:0] prefetch_count;
    
    reg flush_pipeline;
    reg branch_mispredicted;
    
    // Instantiate branch predictor
    branch_predictor bp (
        .clk(clk),
        .rst_n(rst_n),
        .pc_in(current_pc),
        .predict_enable(mem_read),
        .prediction(prediction),
        .predicted_target(predicted_target),
        .prediction_valid(prediction_valid),
        .update_enable(branch_resolved),
        .update_pc(branch_pc),
        .update_taken(branch_taken),
        .update_target(branch_target)
    );
    
    // Instantiate prefetch buffer
    prefetch_buffer pb (
        .clk(clk),
        .rst_n(rst_n),
        .write_enable(prefetch_write_enable),
        .write_data(mem_data),
        .write_pc(mem_addr),
        .read_enable(prefetch_read_enable),
        .read_data(instruction),
        .read_pc(instruction_pc),
        .valid(instruction_valid),
        .full(prefetch_full),
        .empty(prefetch_empty),
        .count(prefetch_count),
        .flush(flush_pipeline)
    );
    
    // Prefetch control
    assign prefetch_write_enable = mem_ready && mem_read;
    assign prefetch_read_enable = fetch_next && !stall;
    
    // PC update logic
    always @(*) begin
        if (branch_mispredicted) begin
            // Branch was mispredicted, use correct target
            next_pc = branch_target;
        end else if (prediction_valid && prediction) begin
            // Branch predicted taken
            next_pc = predicted_target;
        end else begin
            // Sequential fetch
            next_pc = current_pc + 4;
        end
    end
    
    // Check for misprediction
    always @(*) begin
        branch_mispredicted = 1'b0;
        flush_pipeline = 1'b0;
        
        if (branch_resolved) begin
            if (prediction_valid) begin
                // Check if prediction was correct
                if (branch_taken != prediction) begin
                    branch_mispredicted = 1'b1;
                    flush_pipeline = 1'b1;
                end else if (branch_taken && (branch_target != predicted_target)) begin
                    branch_mispredicted = 1'b1;
                    flush_pipeline = 1'b1;
                end
            end else if (branch_taken) begin
                // Branch was not predicted but was taken
                branch_mispredicted = 1'b1;
                flush_pipeline = 1'b1;
            end
        end
    end
    
    // Fetch state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_pc <= 32'h00000000;
            mem_addr <= 32'h00000000;
            mem_read <= 1'b0;
        end else begin
            if (flush_pipeline) begin
                current_pc <= branch_target;
                mem_addr <= branch_target;
                mem_read <= 1'b1;
            end else if (!stall && !prefetch_full) begin
                // Continue prefetching
                current_pc <= next_pc;
                mem_addr <= next_pc;
                mem_read <= 1'b1;
            end else if (prefetch_full) begin
                // Stop fetching when buffer is full
                mem_read <= 1'b0;
            end
        end
    end

endmodule
