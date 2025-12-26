// ============================================================================
// Testbench
// ============================================================================
module tb_instruction_fetch_unit;

    reg clk;
    reg rst_n;
    reg [31:0] mem_data;
    reg mem_ready;
    reg fetch_next;
    reg branch_resolved;
    reg branch_taken;
    reg [31:0] branch_pc;
    reg [31:0] branch_target;
    reg stall;
    
    wire [31:0] mem_addr;
    wire mem_read;
    wire [31:0] instruction;
    wire [31:0] instruction_pc;
    wire instruction_valid;
    wire prefetch_full;
    wire prefetch_empty;

    // Exposed prediction signals
    wire prediction_valid;
    wire prediction;
    wire [31:0] predicted_target;
    wire [31:0] current_fetch_pc;
    
    // Instantiate IFU
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
        .prefetch_empty(prefetch_empty),
        .prediction_valid(prediction_valid),
        .prediction(prediction),
        .predicted_target(predicted_target),
        .current_fetch_pc(current_fetch_pc)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Simple memory model
    always @(*) begin
        if (mem_read) begin
            mem_data = mem_addr + 32'hA0A0A0A0; // Dummy instruction
            mem_ready = 1'b1;
        end else begin
            mem_data = 32'h0;
            mem_ready = 1'b0;
        end
    end
    
    // Test sequence
    initial begin
        $display("Starting Instruction Fetch Unit Simulation");
        $display("=============================================");
        
        // Initialize
        rst_n = 0;
        fetch_next = 0;
        branch_resolved = 0;
        branch_taken = 0;
        branch_pc = 0;
        branch_target = 0;
        stall = 0;
        
        #20 rst_n = 1;
        
        // Test 1: Sequential fetching
        $display("\nTest 1: Sequential Fetching");
        #10 fetch_next = 1;
        
        repeat (10) begin
            @(posedge clk);
            if (instruction_valid) begin
                $display("Time=%0t PC=%h Instruction=%h", $time, instruction_pc, instruction);
            end
        end
        
        // Test 2: Branch prediction
        $display("\nTest 2: Branch Taken");
        @(posedge clk);
        branch_resolved = 1;
        branch_taken = 1;
        branch_pc = 32'h00000020;
        branch_target = 32'h00000100;
        
        @(posedge clk);
        branch_resolved = 0;
        
        repeat (5) begin
            @(posedge clk);
            if (instruction_valid) begin
                $display("Time=%0t PC=%h Instruction=%h", $time, instruction_pc, instruction);
            end
        end
        
        // Test 3: Stall
        $display("\nTest 3: Stall Condition");
        stall = 1;
        repeat (3) @(posedge clk);
        stall = 0;
        
        repeat (5) @(posedge clk);
        
        $display("\nSimulation Complete");
        $finish;
    end
    
    // Monitor
    initial begin
        $monitor("Time=%0t PC=%h MEM_ADDR=%h VALID=%b FULL=%b EMPTY=%b", 
                 $time, instruction_pc, mem_addr, instruction_valid, 
                 prefetch_full, prefetch_empty);
    end

endmodule
