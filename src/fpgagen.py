#!/usr/bin/env python3
"""
FPGA Verification Tools
Generates BRAM initialization files for hardware-in-the-loop verification
"""

import sys
import argparse
from typing import List, Tuple, Dict

# ============================================================================
# Assembly to Machine Code Converter
# ============================================================================

class RISCVAssembler:
    """Simple RISC-V assembler for basic instructions"""
    
    def __init__(self):
        self.labels = {}
        self.instructions = []
        self.pc = 0
        
    def assemble(self, assembly_code: str) -> List[int]:
        """Assemble RISC-V assembly to machine code"""
        lines = assembly_code.strip().split('\n')
        
        # First pass: collect labels
        current_pc = 0
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if ':' in line:
                label = line.split(':')[0].strip()
                self.labels[label] = current_pc
                continue
            current_pc += 4
        
        # Second pass: generate machine code
        current_pc = 0
        machine_code = []
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#') or ':' in line:
                continue
                
            parts = line.replace(',', ' ').split()
            opcode = parts[0].lower()
            
            # Generate machine code based on instruction
            if opcode in ['beq', 'bne', 'blt', 'bge']:
                code = self._encode_branch(opcode, parts[1:], current_pc)
            elif opcode in ['jal', 'jalr']:
                code = self._encode_jump(opcode, parts[1:], current_pc)
            elif opcode in ['add', 'sub', 'and', 'or', 'xor']:
                code = self._encode_rtype(opcode, parts[1:])
            elif opcode in ['addi', 'andi', 'ori', 'xori']:
                code = self._encode_itype(opcode, parts[1:])
            elif opcode == 'nop':
                code = 0x00000013  # ADDI x0, x0, 0
            else:
                code = 0x00000013  # Default to NOP
                
            machine_code.append(code)
            current_pc += 4
            
        return machine_code
    
    def _encode_branch(self, opcode: str, operands: List[str], pc: int) -> int:
        """Encode branch instructions"""
        rs1 = self._parse_register(operands[0])
        rs2 = self._parse_register(operands[1])
        target = operands[2]
        
        # Calculate offset
        if target in self.labels:
            offset = self.labels[target] - pc
        else:
            offset = int(target, 0)
            
        # Branch encoding
        funct3_map = {'beq': 0b000, 'bne': 0b001, 'blt': 0b100, 'bge': 0b101}
        funct3 = funct3_map.get(opcode, 0)
        
        imm12 = offset & 0x1000
        imm10_5 = (offset & 0x7E0) << 20
        imm4_1 = (offset & 0x1E) << 7
        imm11 = (offset & 0x800) >> 4
        
        return 0x63 | (funct3 << 12) | (rs1 << 15) | (rs2 << 20) | imm4_1 | imm11 | imm10_5 | imm12
    
    def _encode_jump(self, opcode: str, operands: List[str], pc: int) -> int:
        """Encode jump instructions"""
        if opcode == 'jal':
            rd = self._parse_register(operands[0])
            target = operands[1]
            if target in self.labels:
                offset = self.labels[target] - pc
            else:
                offset = int(target, 0)
            return 0x6F | (rd << 7) | (offset & 0xFFFFF000)
        else:  # jalr
            rd = self._parse_register(operands[0])
            rs1 = self._parse_register(operands[1])
            offset = int(operands[2], 0) if len(operands) > 2 else 0
            return 0x67 | (rd << 7) | (0 << 12) | (rs1 << 15) | ((offset & 0xFFF) << 20)
    
    def _encode_rtype(self, opcode: str, operands: List[str]) -> int:
        """Encode R-type instructions"""
        rd = self._parse_register(operands[0])
        rs1 = self._parse_register(operands[1])
        rs2 = self._parse_register(operands[2])
        
        funct3_map = {'add': 0b000, 'sub': 0b000, 'and': 0b111, 
                      'or': 0b110, 'xor': 0b100}
        funct7_map = {'add': 0b0000000, 'sub': 0b0100000, 'and': 0b0000000,
                      'or': 0b0000000, 'xor': 0b0000000}
        
        return 0x33 | (rd << 7) | (funct3_map[opcode] << 12) | \
               (rs1 << 15) | (rs2 << 20) | (funct7_map[opcode] << 25)
    
    def _encode_itype(self, opcode: str, operands: List[str]) -> int:
        """Encode I-type instructions"""
        rd = self._parse_register(operands[0])
        rs1 = self._parse_register(operands[1])
        imm = int(operands[2], 0)
        
        funct3_map = {'addi': 0b000, 'andi': 0b111, 'ori': 0b110, 'xori': 0b100}
        
        return 0x13 | (rd << 7) | (funct3_map[opcode] << 12) | \
               (rs1 << 15) | ((imm & 0xFFF) << 20)
    
    def _parse_register(self, reg: str) -> int:
        """Parse register name to number"""
        reg = reg.lower().strip()
        if reg.startswith('x'):
            return int(reg[1:])
        # Map common register names
        reg_map = {
            'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
            't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8,
            's1': 9, 'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13,
            'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
            's2': 18, 's3': 19, 's4': 20, 's5': 21,
            's6': 22, 's7': 23, 's8': 24, 's9': 25,
            's10': 26, 's11': 27, 't3': 28, 't4': 29,
            't5': 30, 't6': 31
        }
        return reg_map.get(reg, 0)


# ============================================================================
# Trace to Ground Truth Converter
# ============================================================================

class BranchTraceParser:
    """Parse execution trace to extract branch behavior"""
    
    def __init__(self):
        self.branches = []
    
    def parse_trace(self, trace_file: str) -> List[Tuple[int, bool, int]]:
        """
        Parse trace file
        Format: PC TAKEN TARGET
        Example:
            0x00000040 1 0x00000100
            0x00000080 0 0x00000084
        """
        branches = []
        
        with open(trace_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                    
                parts = line.split()
                if len(parts) >= 3:
                    pc = int(parts[0], 16)
                    taken = int(parts[1]) != 0
                    target = int(parts[2], 16)
                    branches.append((pc, taken, target))
        
        return branches
    
    def generate_from_assembly(self, machine_code: List[int]) -> List[Tuple[int, bool, int]]:
        """
        Generate expected branch behavior from machine code
        Simple static analysis
        """
        branches = []
        pc = 0
        
        for i, inst in enumerate(machine_code):
            opcode = inst & 0x7F
            
            # Branch instructions (opcode 0x63)
            if opcode == 0x63:
                # Extract immediate
                imm12 = (inst >> 31) & 0x1
                imm10_5 = (inst >> 25) & 0x3F
                imm4_1 = (inst >> 8) & 0xF
                imm11 = (inst >> 7) & 0x1
                
                offset = (imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1)
                if imm12:  # Sign extend
                    offset |= 0xFFFFE000
                
                target = (pc + offset) & 0xFFFFFFFF
                
                # For static analysis, assume branches alternate or follow pattern
                # In real scenario, you'd run the program and trace actual behavior
                taken = (i % 2 == 0)  # Simple pattern for demo
                branches.append((pc, taken, target))
            
            # JAL instruction (opcode 0x6F)
            elif opcode == 0x6F:
                imm20 = (inst >> 31) & 0x1
                imm10_1 = (inst >> 21) & 0x3FF
                imm11 = (inst >> 20) & 0x1
                imm19_12 = (inst >> 12) & 0xFF
                
                offset = (imm20 << 20) | (imm19_12 << 12) | (imm11 << 11) | (imm10_1 << 1)
                if imm20:
                    offset |= 0xFFE00000
                
                target = (pc + offset) & 0xFFFFFFFF
                branches.append((pc, True, target))  # JAL always taken
            
            pc += 4
        
        return branches


# ============================================================================
# Memory File Generator
# ============================================================================

def generate_program_mem(machine_code: List[int], output_file: str):
    """Generate program.mem file for BRAM initialization"""
    with open(output_file, 'w') as f:
        for i, inst in enumerate(machine_code):
            f.write(f"{inst:08X}\n")
    print(f"Generated {output_file} with {len(machine_code)} instructions")


def generate_branch_mem(branches: List[Tuple[int, bool, int]], output_file: str):
    """
    Generate branches.mem file for ground truth
    Format: {valid[65], taken[64], pc[63:32], target[31:0]}
    """
    # Create lookup table indexed by PC[9:2]
    branch_table = {}
    
    for pc, taken, target in branches:
        index = (pc >> 2) & 0xFF  # Use PC[9:2] as index
        # Pack: valid(1) | taken(1) | pc(32) | target(32) = 66 bits
        valid = 1
        entry = (valid << 65) | (int(taken) << 64) | (pc << 32) | target
        branch_table[index] = entry
    
    # Write to file
    with open(output_file, 'w') as f:
        for i in range(256):  # 256 entries
            if i in branch_table:
                entry = branch_table[i]
                # Write as hex (66 bits = 17 hex digits, but we'll use 18 for alignment)
                f.write(f"{entry:018X}\n")
            else:
                f.write("000000000000000000\n")  # Invalid entry
    
    print(f"Generated {output_file} with {len(branches)} branch entries")


# ============================================================================
# Main Program
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description='Generate FPGA verification files')
    parser.add_argument('--assembly', '-a', type=str, help='Assembly file')
    parser.add_argument('--trace', '-t', type=str, help='Branch trace file')
    parser.add_argument('--program-out', '-p', default='program.mem', 
                       help='Output program memory file')
    parser.add_argument('--branch-out', '-b', default='branches.mem',
                       help='Output branch ground truth file')
    parser.add_argument('--example', action='store_true',
                       help='Generate example files')
    
    args = parser.parse_args()
    
    if args.example:
        # Generate example files
        print("Generating example files...")
        
        example_asm = """
# Example RISC-V Assembly Program
# Simple loop with branches

        addi x1, x0, 10      # x1 = 10 (loop counter)
        addi x2, x0, 0       # x2 = 0 (sum)
        
loop:
        addi x2, x2, 1       # sum++
        addi x1, x1, -1      # counter--
        bne x1, x0, loop     # if counter != 0, goto loop
        
        addi x3, x0, 100     # x3 = 100
        addi x4, x0, 50      # x4 = 50
        
        blt x4, x3, taken    # if x4 < x3, goto taken
        addi x5, x0, 1       # not taken path
        jal x0, end
        
taken:
        addi x5, x0, 2       # taken path
        
end:
        addi x6, x0, 0       # end marker
        beq x0, x0, end      # infinite loop
"""
        
        # Save example assembly
        with open('example.asm', 'w') as f:
            f.write(example_asm)
        print("Generated example.asm")
        
        # Assemble
        assembler = RISCVAssembler()
        machine_code = assembler.assemble(example_asm)
        
        # Generate program.mem
        generate_program_mem(machine_code, 'program.mem')
        
        # Generate branch trace (from static analysis)
        trace_parser = BranchTraceParser()
        branches = trace_parser.generate_from_assembly(machine_code)
        
        # Generate branches.mem
        generate_branch_mem(branches, 'branches.mem')
        
        print("\nExample files generated successfully!")
        print("Files created:")
        print("  - example.asm")
        print("  - program.mem")
        print("  - branches.mem")
        
    elif args.assembly:
        # Process user assembly file
        print(f"Processing assembly file: {args.assembly}")
        
        with open(args.assembly, 'r') as f:
            assembly_code = f.read()
        
        assembler = RISCVAssembler()
        machine_code = assembler.assemble(assembly_code)
        
        generate_program_mem(machine_code, args.program_out)
        
        if args.trace:
            # Use provided trace file
            trace_parser = BranchTraceParser()
            branches = trace_parser.parse_trace(args.trace)
        else:
            # Generate from static analysis
            trace_parser = BranchTraceParser()
            branches = trace_parser.generate_from_assembly(machine_code)
        
        generate_branch_mem(branches, args.branch_out)
        
        print("\nFiles generated successfully!")
        
    else:
        parser.print_help()


if __name__ == '__main__':
    main()

