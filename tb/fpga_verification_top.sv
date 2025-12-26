// ============================================================================
// FPGA Verification Top Module
// Integrates everything for on-FPGA verification
// ============================================================================
module fpga_verification_top #(
    parameter PROGRAM_FILE = "program.mem",
    parameter BRANCH_FILE = "branches.mem",
    parameter NUM_INSTRUCTIONS = 1024
)(
    input wire clk,              // 100 MHz clock
    input wire rst_n,            // Active-low reset
    
    // Control
    input wire start_test,       // Button to start test
    input wire reset_stats,      // Button to reset statistics
    
    // Output
    output wire [7:0] leds,      // LED display
    output wire uart_tx,         // UART output for detailed results
    output wire test_done,       // Test completion indicator
    
    // Debug outputs (optional - connect to ILA)
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instruction,
    output wire debug_prediction,
    output wire [31:0] debug_predicted_target
);

    // Internal signals
    wire [31:0] mem_addr;
    wire mem_read;
    wire [31:0] mem_data;
    wire mem_ready;
    
    wire [31:0] instruction;
    wire [31:0] instruction_pc;
    wire instruction_valid;
    reg fetch_next;
    
    wire branch_resolved;
    wire branch_taken;
    wire [31:0] branch_pc;
    wire [31:0] branch_target;
    
    reg stall;
    wire prefetch_full;
    wire prefetch_empty;
    
    // Ground truth signals
    wire [31:0] gt_pc;
    wire gt_valid;
    wire gt_taken;
    wire [31:0] gt_target;
    
    // Statistics
    wire [31:0] total_predictions;
    wire [31:0] correct_predictions;
    wire [31:0] incorrect_predictions;
    wire [31:0] correct_targets;
    wire [31:0] incorrect_targets;
    
    // Test control
    reg test_running;
    reg test_complete;
    reg [15:0] instruction_counter;
    
    // Debounced button signals
    wire start_test_db;
    wire reset_stats_db;
    
    assign test_done = test_complete;
    
    // Debug outputs
    assign debug_pc = instruction_pc;
    assign debug_instruction = instruction;
    assign debug_prediction = 1'b0; // Connect to internal predictor signal
    assign debug_predicted_target = 32'h0; // Connect to internal signal
    
    // ========================================================================
    // Button Debouncers
    // ========================================================================
    button_debouncer start_db (
        .clk(clk),
        .rst_n(rst_n),
        .button_in(start_test),
        .button_out(start_test_db)
    );
    
    button_debouncer reset_db (
        .clk(clk),
        .rst_n(rst_n),
        .button_in(reset_stats),
        .button_out(reset_stats_db)
    );
    
    // ========================================================================
    // Instantiate Instruction Memory (BRAM)
    // ========================================================================
    bram_instruction_memory #(
        .ADDR_WIDTH(10),
        .INIT_FILE(PROGRAM_FILE)
    ) imem (
        .clk(clk),
        .addr(mem_addr[11:2]), // Word-aligned
        .read_enable(mem_read),
        .data(mem_data),
        .ready(mem_ready)
    );
    
    // ========================================================================
    // Instantiate Branch Ground Truth
    // ========================================================================
    branch_ground_truth #(
        .ADDR_WIDTH(8),
        .INIT_FILE(BRANCH_FILE)
    ) ground_truth (
        .clk(clk),
        .lookup_addr(instruction_pc[9:2]), // Use PC as index
        .valid(gt_valid),
        .pc(gt_pc),
        .taken(gt_taken),
        .target(gt_target)
    );
    
    // ========================================================================
    // Instantiate IFU (Design Under Test)
    // ========================================================================
    instruction_fetch_unit ifu (
        .clk(clk),
        .rst_n(rst_n),
        .mem_addr(mem_addr),
        .mem_read(mem_read),
        .mem_data(mem_data),
        .mem_ready(mem_ready),
        .instruction(instruction),
        .instruction_pc(instruction_pc),
        .instruction_valid(instruction_valid),
        .fetch_next(fetch_next),
        .branch_resolved(branch_resolved),
        .branch_taken(branch_taken),
        .branch_pc(branch_pc),
        .branch_target(branch_target),
        .stall(stall),
        .prefetch_full(prefetch_full),
        .prefetch_empty(prefetch_empty)
    );
    
    // ========================================================================
    // Instantiate Prediction Checker
    // ========================================================================
    prediction_checker pchker (
        .clk(clk),
        .rst_n(rst_n && !reset_stats_db),
        .fetch_pc(instruction_pc),
        .prediction_made(instruction_valid && gt_valid),
        .prediction(1'b0), // Connect to IFU internal prediction signal
        .predicted_target(32'h0), // Connect to IFU internal signal
        .actual_pc(gt_pc),
        .actual_valid(gt_valid),
        .actual_taken(gt_taken),
        .actual_target(gt_target),
        .total_predictions(total_predictions),
        .correct_predictions(correct_predictions),
        .incorrect_predictions(incorrect_predictions),
        .correct_targets(correct_targets),
        .incorrect_targets(incorrect_targets)
    );
    
    // ========================================================================
    // Test Control Logic
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            test_running <= 1'b0;
            test_complete <= 1'b0;
            instruction_counter <= 0;
            fetch_next <= 1'b0;
            stall <= 1'b0;
        end else begin
            // Start test on button press
            if (start_test_db && !test_running && !test_complete) begin
                test_running <= 1'b1;
                test_complete <= 1'b0;
                instruction_counter <= 0;
                fetch_next <= 1'b1;
            end
            
            // Count instructions
            if (test_running && instruction_valid && fetch_next) begin
                instruction_counter <= instruction_counter + 1;
                
                // Stop after processing all instructions
                if (instruction_counter >= NUM_INSTRUCTIONS - 1) begin
                    test_running <= 1'b0;
                    test_complete <= 1'b1;
                    fetch_next <= 1'b0;
                end
            end
            
            // Auto-resolve branches from ground truth
            // In real scenario, this comes from execute stage
            // For verification, we use ground truth
        end
    end
    
    // Generate branch resolution signals from ground truth
    assign branch_resolved = test_running && instruction_valid && gt_valid;
    assign branch_taken = gt_taken;
    assign branch_pc = instruction_pc;
    assign branch_target = gt_target;

endmodule