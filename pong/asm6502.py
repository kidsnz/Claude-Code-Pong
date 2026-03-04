#!/usr/bin/env python3
"""
Simple 2-pass 6502 Assembler (DASM-compatible subset)
Supports Atari 2600 development.
"""

import sys
import re
import os

# ---------------------------------------------------------------------------
# 6502 opcode table
# Addressing modes: imp, acc, imm, zp, zpx, zpy, abs, absx, absy,
#                   ind, indx, indy, rel
# ---------------------------------------------------------------------------
OPCODES = {
    ('ADC','imm'):0x69, ('ADC','zp'):0x65, ('ADC','zpx'):0x75,
    ('ADC','abs'):0x6D, ('ADC','absx'):0x7D, ('ADC','absy'):0x79,
    ('ADC','indx'):0x61, ('ADC','indy'):0x71,
    ('AND','imm'):0x29, ('AND','zp'):0x25, ('AND','zpx'):0x35,
    ('AND','abs'):0x2D, ('AND','absx'):0x3D, ('AND','absy'):0x39,
    ('AND','indx'):0x21, ('AND','indy'):0x31,
    ('ASL','acc'):0x0A, ('ASL','zp'):0x06, ('ASL','zpx'):0x16,
    ('ASL','abs'):0x0E, ('ASL','absx'):0x1E,
    ('BCC','rel'):0x90, ('BCS','rel'):0xB0, ('BEQ','rel'):0xF0,
    ('BMI','rel'):0x30, ('BNE','rel'):0xD0, ('BPL','rel'):0x10,
    ('BVC','rel'):0x50, ('BVS','rel'):0x70,
    ('BIT','zp'):0x24, ('BIT','abs'):0x2C,
    ('BRK','imp'):0x00,
    ('CLC','imp'):0x18, ('CLD','imp'):0xD8, ('CLI','imp'):0x58, ('CLV','imp'):0xB8,
    ('CMP','imm'):0xC9, ('CMP','zp'):0xC5, ('CMP','zpx'):0xD5,
    ('CMP','abs'):0xCD, ('CMP','absx'):0xDD, ('CMP','absy'):0xD9,
    ('CMP','indx'):0xC1, ('CMP','indy'):0xD1,
    ('CPX','imm'):0xE0, ('CPX','zp'):0xE4, ('CPX','abs'):0xEC,
    ('CPY','imm'):0xC0, ('CPY','zp'):0xC4, ('CPY','abs'):0xCC,
    ('DEC','zp'):0xC6, ('DEC','zpx'):0xD6, ('DEC','abs'):0xCE, ('DEC','absx'):0xDE,
    ('DEX','imp'):0xCA, ('DEY','imp'):0x88,
    ('EOR','imm'):0x49, ('EOR','zp'):0x45, ('EOR','zpx'):0x55,
    ('EOR','abs'):0x4D, ('EOR','absx'):0x5D, ('EOR','absy'):0x59,
    ('EOR','indx'):0x41, ('EOR','indy'):0x51,
    ('INC','zp'):0xE6, ('INC','zpx'):0xF6, ('INC','abs'):0xEE, ('INC','absx'):0xFE,
    ('INX','imp'):0xE8, ('INY','imp'):0xC8,
    ('JMP','abs'):0x4C, ('JMP','ind'):0x6C,
    ('JSR','abs'):0x20,
    ('LDA','imm'):0xA9, ('LDA','zp'):0xA5, ('LDA','zpx'):0xB5,
    ('LDA','abs'):0xAD, ('LDA','absx'):0xBD, ('LDA','absy'):0xB9,
    ('LDA','indx'):0xA1, ('LDA','indy'):0xB1,
    ('LDX','imm'):0xA2, ('LDX','zp'):0xA6, ('LDX','zpy'):0xB6,
    ('LDX','abs'):0xAE, ('LDX','absy'):0xBE,
    ('LDY','imm'):0xA0, ('LDY','zp'):0xA4, ('LDY','zpx'):0xB4,
    ('LDY','abs'):0xAC, ('LDY','absx'):0xBC,
    ('LSR','acc'):0x4A, ('LSR','zp'):0x46, ('LSR','zpx'):0x56,
    ('LSR','abs'):0x4E, ('LSR','absx'):0x5E,
    ('NOP','imp'):0xEA,
    ('ORA','imm'):0x09, ('ORA','zp'):0x05, ('ORA','zpx'):0x15,
    ('ORA','abs'):0x0D, ('ORA','absx'):0x1D, ('ORA','absy'):0x19,
    ('ORA','indx'):0x01, ('ORA','indy'):0x11,
    ('PHA','imp'):0x48, ('PHP','imp'):0x08,
    ('PLA','imp'):0x68, ('PLP','imp'):0x28,
    ('ROL','acc'):0x2A, ('ROL','zp'):0x26, ('ROL','zpx'):0x36,
    ('ROL','abs'):0x2E, ('ROL','absx'):0x3E,
    ('ROR','acc'):0x6A, ('ROR','zp'):0x66, ('ROR','zpx'):0x76,
    ('ROR','abs'):0x6E, ('ROR','absx'):0x7E,
    ('RTI','imp'):0x40, ('RTS','imp'):0x60,
    ('SBC','imm'):0xE9, ('SBC','zp'):0xE5, ('SBC','zpx'):0xF5,
    ('SBC','abs'):0xED, ('SBC','absx'):0xFD, ('SBC','absy'):0xF9,
    ('SBC','indx'):0xE1, ('SBC','indy'):0xF1,
    ('SEC','imp'):0x38, ('SED','imp'):0xF8, ('SEI','imp'):0x78,
    ('STA','zp'):0x85, ('STA','zpx'):0x95,
    ('STA','abs'):0x8D, ('STA','absx'):0x9D, ('STA','absy'):0x99,
    ('STA','indx'):0x81, ('STA','indy'):0x91,
    ('STX','zp'):0x86, ('STX','zpy'):0x96, ('STX','abs'):0x8E,
    ('STY','zp'):0x84, ('STY','zpx'):0x94, ('STY','abs'):0x8C,
    ('TAX','imp'):0xAA, ('TAY','imp'):0xA8,
    ('TSX','imp'):0xBA, ('TXA','imp'):0x8A, ('TXS','imp'):0x9A, ('TYA','imp'):0x98,
}

BRANCHES = {'BCC','BCS','BEQ','BMI','BNE','BPL','BVC','BVS'}

# Instruction sizes (bytes)
def opcode_size(mode):
    return {
        'imp':1, 'acc':1,
        'imm':2, 'zp':2, 'zpx':2, 'zpy':2, 'rel':2, 'indx':2, 'indy':2,
        'abs':3, 'absx':3, 'absy':3, 'ind':3,
    }[mode]


class AssemblerError(Exception):
    def __init__(self, msg, line=None, lineno=None):
        loc = f" (line {lineno}: {line!r})" if lineno else ""
        super().__init__(msg + loc)


class Assembler:
    def __init__(self):
        self.symbols = {}   # name -> value
        self.memory = {}    # addr -> byte
        self.pc = 0
        self.origin = 0
        self.pass_num = 0
        self.errors = []
        self.current_file = "<input>"
        # segments for RAM / ROM separation
        self.seg_unitialized = False

    # ------------------------------------------------------------------
    # Value parsing
    # ------------------------------------------------------------------
    def parse_value(self, token, lineno=None, line=None):
        """Parse a numeric token or expression. Returns int."""
        token = token.strip()
        if not token:
            raise AssemblerError("Empty value", line, lineno)

        # Try simple literals first
        try:
            return self._eval_expr(token, lineno, line)
        except AssemblerError:
            raise
        except Exception as e:
            raise AssemblerError(f"Cannot parse value '{token}': {e}", line, lineno)

    def _eval_expr(self, expr, lineno=None, line=None):
        """Evaluate a simple expression (handles +, -, *, /, |, &, ^, <<, >>)."""
        expr = expr.strip()

        # Handle unary < (low byte) and > (high byte)
        if expr.startswith('<'):
            return self._eval_expr(expr[1:], lineno, line) & 0xFF
        if expr.startswith('>'):
            return (self._eval_expr(expr[1:], lineno, line) >> 8) & 0xFF

        # Tokenize: split on operators but keep them
        # Simple recursive descent for + and -
        # First handle * - |  & ^ << >>
        val = self._parse_or(expr, lineno, line)
        return val

    def _parse_or(self, expr, lineno, line):
        parts = self._split_binary(expr, '|')
        if len(parts) > 1:
            result = 0
            for p in parts:
                result |= self._parse_xor(p.strip(), lineno, line)
            return result
        return self._parse_xor(expr, lineno, line)

    def _parse_xor(self, expr, lineno, line):
        parts = self._split_binary(expr, '^')
        if len(parts) > 1:
            result = self._parse_and(parts[0].strip(), lineno, line)
            for p in parts[1:]:
                result ^= self._parse_and(p.strip(), lineno, line)
            return result
        return self._parse_and(expr, lineno, line)

    def _parse_and(self, expr, lineno, line):
        parts = self._split_binary(expr, '&')
        if len(parts) > 1:
            result = self._parse_shift(parts[0].strip(), lineno, line)
            for p in parts[1:]:
                result &= self._parse_shift(p.strip(), lineno, line)
            return result
        return self._parse_shift(expr, lineno, line)

    def _parse_shift(self, expr, lineno, line):
        if '<<' in expr:
            parts = expr.split('<<', 1)
            return self._parse_addsub(parts[0].strip(), lineno, line) << self._parse_addsub(parts[1].strip(), lineno, line)
        if '>>' in expr:
            parts = expr.split('>>', 1)
            return self._parse_addsub(parts[0].strip(), lineno, line) >> self._parse_addsub(parts[1].strip(), lineno, line)
        return self._parse_addsub(expr, lineno, line)

    def _parse_addsub(self, expr, lineno, line):
        # Split on + and - at top level (not inside parens)
        tokens = self._split_addsub(expr)
        if not tokens:
            raise AssemblerError(f"Empty expression", line, lineno)
        result = self._parse_muldiv(tokens[0][1], lineno, line)
        for op, part in tokens[1:]:
            val = self._parse_muldiv(part, lineno, line)
            if op == '+':
                result += val
            else:
                result -= val
        return result

    def _split_addsub(self, expr):
        """Split on + and - respecting parentheses and unary."""
        tokens = []
        depth = 0
        current = ''
        op = '+'
        i = 0
        while i < len(expr):
            c = expr[i]
            if c == '(':
                depth += 1
                current += c
            elif c == ')':
                depth -= 1
                current += c
            elif c in '+-' and depth == 0 and current.strip():
                tokens.append((op, current.strip()))
                op = c
                current = ''
            else:
                current += c
            i += 1
        if current.strip():
            tokens.append((op, current.strip()))
        return tokens

    def _parse_muldiv(self, expr, lineno, line):
        parts = self._split_binary(expr, '*')
        if len(parts) > 1:
            result = self._parse_atom(parts[0].strip(), lineno, line)
            for p in parts[1:]:
                result *= self._parse_atom(p.strip(), lineno, line)
            return result
        parts = self._split_binary(expr, '/')
        if len(parts) > 1:
            result = self._parse_atom(parts[0].strip(), lineno, line)
            for p in parts[1:]:
                result //= self._parse_atom(p.strip(), lineno, line)
            return result
        return self._parse_atom(expr, lineno, line)

    def _split_binary(self, expr, op):
        """Split expression on binary operator (not inside parens)."""
        parts = []
        depth = 0
        current = ''
        i = 0
        while i < len(expr):
            c = expr[i]
            if c == '(':
                depth += 1
                current += c
            elif c == ')':
                depth -= 1
                current += c
            elif c == op and depth == 0:
                parts.append(current)
                current = ''
            else:
                current += c
            i += 1
        parts.append(current)
        return parts if len(parts) > 1 else [expr]

    def _parse_atom(self, token, lineno, line):
        token = token.strip()
        if not token:
            raise AssemblerError("Empty atom", line, lineno)

        # Parenthesized expression
        if token.startswith('(') and token.endswith(')'):
            return self._eval_expr(token[1:-1], lineno, line)

        # Unary minus
        if token.startswith('-'):
            return -self._parse_atom(token[1:], lineno, line)

        # Unary < > (low/high byte)
        if token.startswith('<'):
            return self._parse_atom(token[1:], lineno, line) & 0xFF
        if token.startswith('>'):
            return (self._parse_atom(token[1:], lineno, line) >> 8) & 0xFF

        # Hex: $XX
        if token.startswith('$'):
            return int(token[1:], 16)

        # Binary: %XXXXXXXX
        if token.startswith('%'):
            return int(token[1:], 2)

        # Char: 'X'
        if token.startswith("'") and token.endswith("'") and len(token) >= 3:
            return ord(token[1])

        # Decimal
        if token.isdigit() or (token.startswith('-') and token[1:].isdigit()):
            return int(token)

        # Current PC
        if token == '*':
            return self.pc

        # Symbol
        if re.match(r'^[A-Za-z_.][A-Za-z0-9_.]*$', token):
            if token in self.symbols:
                return self.symbols[token]
            elif self.pass_num == 1:
                return 0  # Forward reference, will be resolved in pass 2
            else:
                raise AssemblerError(f"Undefined symbol: '{token}'", line, lineno)

        raise AssemblerError(f"Cannot parse atom: '{token}'", line, lineno)

    # ------------------------------------------------------------------
    # Memory output
    # ------------------------------------------------------------------
    def emit_byte(self, b):
        if not self.seg_unitialized:
            self.memory[self.pc] = b & 0xFF
        self.pc += 1

    def emit_word(self, w):
        self.emit_byte(w & 0xFF)
        self.emit_byte((w >> 8) & 0xFF)

    def write_byte(self, addr, b):
        """Patch a byte at a specific address."""
        self.memory[addr] = b & 0xFF

    # ------------------------------------------------------------------
    # Operand parsing
    # ------------------------------------------------------------------
    def parse_operand(self, operand, mnemonic, lineno, line):
        """
        Parse an operand string and return (mode, value_or_None).
        For branches, value is the target address (we compute offset later).
        """
        operand = operand.strip()

        if not operand:
            return ('imp', None)

        operand_up = operand.upper()

        # Accumulator
        if operand_up == 'A':
            return ('acc', None)

        # Immediate: #val
        if operand.startswith('#'):
            val = self.parse_value(operand[1:], lineno, line)
            return ('imm', val & 0xFF)

        # Indirect X: (val,X)
        m = re.match(r'^\((.+),\s*[Xx]\)$', operand)
        if m:
            val = self.parse_value(m.group(1), lineno, line)
            return ('indx', val & 0xFF)

        # Indirect Y: (val),Y
        m = re.match(r'^\((.+)\),\s*[Yy]$', operand)
        if m:
            val = self.parse_value(m.group(1), lineno, line)
            return ('indy', val & 0xFF)

        # Indirect: (val) - only for JMP
        m = re.match(r'^\((.+)\)$', operand)
        if m:
            val = self.parse_value(m.group(1), lineno, line)
            return ('ind', val)

        # Absolute X/Y or Zero-page X/Y
        m = re.match(r'^(.+),\s*([XxYy])$', operand)
        if m:
            val = self.parse_value(m.group(1), lineno, line)
            idx = m.group(2).upper()
            if 0 <= val <= 0xFF:
                return ('zpx' if idx == 'X' else 'zpy', val)
            else:
                return ('absx' if idx == 'X' else 'absy', val)

        # Branch instructions always use relative mode
        if mnemonic in BRANCHES:
            val = self.parse_value(operand, lineno, line)
            return ('rel', val)

        # Absolute or zero-page
        val = self.parse_value(operand, lineno, line)
        # Force absolute with 'a:' prefix handling or if >$FF
        if operand.lower().startswith('a:'):
            return ('abs', val)
        if 0 <= val <= 0xFF:
            # Could be zp or abs - prefer zp unless forced
            return ('zp', val)
        else:
            return ('abs', val)

    # ------------------------------------------------------------------
    # Assembler directives
    # ------------------------------------------------------------------
    def handle_directive(self, directive, operand, lineno, line):
        d = directive.upper()

        if d in ('PROCESSOR', '.PROCESSOR'):
            pass  # ignore

        elif d in ('ORG', '.ORG', '*='):
            self.pc = self.parse_value(operand, lineno, line)
            self.origin = self.pc

        elif d in ('EQU', '.EQU', '='):
            # handled by caller (needs label name)
            pass

        elif d in ('BYTE', '.BYTE', 'DC.B', 'DB', '.DB'):
            for part in self._split_comma(operand):
                part = part.strip()
                if part.startswith('"') or part.startswith("'"):
                    quote = part[0]
                    s = part[1:]
                    if s.endswith(quote):
                        s = s[:-1]
                    for c in s:
                        self.emit_byte(ord(c))
                else:
                    self.emit_byte(self.parse_value(part, lineno, line))

        elif d in ('WORD', '.WORD', 'DC.W', 'DW', '.DW'):
            for part in self._split_comma(operand):
                self.emit_word(self.parse_value(part.strip(), lineno, line))

        elif d in ('DS', '.DS', 'RES'):
            count = self.parse_value(operand.strip().split(',')[0], lineno, line)
            fill = 0
            if ',' in operand:
                fill = self.parse_value(operand.split(',',1)[1].strip(), lineno, line)
            for _ in range(count):
                self.emit_byte(fill)

        elif d in ('ALIGN', '.ALIGN'):
            boundary = self.parse_value(operand, lineno, line)
            while self.pc % boundary != 0:
                self.emit_byte(0xFF)

        elif d in ('INCLUDE', '.INCLUDE'):
            # Just skip includes for now
            pass

        elif d in ('SEG', 'SEG.U', '.SEG'):
            # Segment handling
            if 'SEG.U' in directive.upper() or operand.strip().upper().endswith('.U'):
                self.seg_unitialized = True
            else:
                self.seg_unitialized = False

        elif d in ('IFCONST', 'IFNCONST', 'IF', 'ELSE', 'ENDIF',
                   '.IF', '.ELSE', '.ENDIF', 'MAC', 'ENDM',
                   'SUBROUTINE', '.SUBROUTINE'):
            pass  # simplified: ignore conditionals

        elif d in ('ECHO', '.ECHO'):
            pass

        elif d in ('HEX', '.HEX'):
            # Inline hex bytes: HEX 01 02 03
            hexstr = operand.replace(' ', '')
            for i in range(0, len(hexstr), 2):
                self.emit_byte(int(hexstr[i:i+2], 16))

        else:
            pass  # Unknown directive, ignore

    def _split_comma(self, s):
        """Split on commas, respecting parentheses and quotes."""
        parts = []
        depth = 0
        in_quote = False
        quote_char = ''
        current = ''
        for c in s:
            if in_quote:
                current += c
                if c == quote_char:
                    in_quote = False
            elif c in '"\'':
                in_quote = True
                quote_char = c
                current += c
            elif c == '(':
                depth += 1
                current += c
            elif c == ')':
                depth -= 1
                current += c
            elif c == ',' and depth == 0:
                parts.append(current)
                current = ''
            else:
                current += c
        parts.append(current)
        return parts

    # ------------------------------------------------------------------
    # Main assembly
    # ------------------------------------------------------------------
    def assemble_file(self, filename):
        with open(filename, 'r') as f:
            source = f.read()
        return self.assemble(source, filename)

    def assemble(self, source, filename="<string>"):
        self.current_file = filename
        lines = source.splitlines()

        # Two-pass assembly
        for pass_num in (1, 2):
            self.pass_num = pass_num
            self.pc = 0
            self.seg_unitialized = False

            for lineno, raw_line in enumerate(lines, 1):
                line = raw_line

                # Strip comments
                # Be careful with strings containing ;
                in_q = False
                qq = ''
                stripped = ''
                i = 0
                while i < len(line):
                    c = line[i]
                    if in_q:
                        stripped += c
                        if c == qq:
                            in_q = False
                    elif c in '"\'':
                        in_q = True
                        qq = c
                        stripped += c
                    elif c == ';':
                        break
                    else:
                        stripped += c
                    i += 1
                line = stripped.rstrip()

                if not line.strip():
                    continue

                # Parse: [label[:]] [mnemonic [operand]]
                # Check for label at start (no leading space or has colon)
                label = None
                mnemonic = None
                operand = ''

                # Check if line starts with whitespace (no label on this line)
                if line[0] in ' \t':
                    rest = line.strip()
                else:
                    # Might have a label
                    m = re.match(r'^([A-Za-z_.][A-Za-z0-9_.]*)\s*:?\s*(.*)', line)
                    if m:
                        potential_label = m.group(1)
                        rest_of_line = m.group(2).strip()
                        # Check if it's a directive/mnemonic without label
                        if potential_label.upper() in self._all_mnemonics():
                            rest = line.strip()
                            potential_label = None
                        else:
                            label = potential_label
                            rest = rest_of_line
                    else:
                        rest = line.strip()

                # Parse mnemonic and operand from rest
                if rest:
                    parts = rest.split(None, 1)
                    mnemonic = parts[0].upper()
                    operand = parts[1] if len(parts) > 1 else ''
                    # Strip inline comments from operand
                    operand = operand.strip()

                # Register label
                if label:
                    if mnemonic and mnemonic in ('EQU', '.EQU', '='):
                        val = self.parse_value(operand, lineno, raw_line)
                        self.symbols[label] = val
                        mnemonic = None  # consumed
                    else:
                        self.symbols[label] = self.pc

                if not mnemonic:
                    continue

                # Handle directives
                if mnemonic.startswith('.') or mnemonic in (
                    'PROCESSOR','ORG','BYTE','WORD','DS','ALIGN','INCLUDE',
                    'SEG','HEX','DC','DB','DW','ECHO','MAC','ENDM',
                    'SUBROUTINE','IFCONST','IFNCONST','IF','ELSE','ENDIF',
                    'RES',
                ):
                    self.handle_directive(mnemonic, operand, lineno, raw_line)
                    continue

                # Handle EQU without label (e.g. from include files)
                if mnemonic == 'EQU':
                    continue

                # Handle SEG variants
                if mnemonic in ('SEG.U',):
                    self.seg_unitialized = True
                    continue

                # Special: *= is org
                if mnemonic == '*=':
                    self.pc = self.parse_value(operand, lineno, raw_line)
                    self.origin = self.pc
                    continue

                # It must be a 6502 instruction
                mn = mnemonic
                if mn not in {k[0] for k in OPCODES}:
                    # Could be undefined directive, skip with warning on pass 2
                    if pass_num == 2:
                        print(f"Warning: Unknown mnemonic '{mn}' at line {lineno}", file=sys.stderr)
                    continue

                # Instructions that default to accumulator when no operand given
                ACC_DEFAULTS = {'ASL', 'LSR', 'ROL', 'ROR'}
                if not operand.strip() and mn in ACC_DEFAULTS:
                    operand = 'A'

                # Parse operand
                try:
                    mode, val = self.parse_operand(operand, mn, lineno, raw_line)
                except AssemblerError as e:
                    if pass_num == 2:
                        print(f"Error: {e}", file=sys.stderr)
                        self.errors.append(str(e))
                    self.pc += 3  # assume worst case
                    continue

                # Look up opcode
                key = (mn, mode)
                if key not in OPCODES:
                    # Try abs instead of zp or vice versa
                    if mode == 'zp' and (mn, 'abs') in OPCODES:
                        mode = 'abs'
                        key = (mn, mode)
                    elif mode == 'zpx' and (mn, 'absx') in OPCODES:
                        mode = 'absx'
                        key = (mn, mode)
                    elif mode == 'zpy' and (mn, 'absy') in OPCODES:
                        mode = 'absy'
                        key = (mn, mode)
                    elif mode == 'abs' and val is not None and 0 <= val <= 0xFF and (mn, 'zp') in OPCODES:
                        mode = 'zp'
                        key = (mn, mode)
                    else:
                        if pass_num == 2:
                            print(f"Error: No opcode for ({mn}, {mode}) at line {lineno}: {raw_line!r}", file=sys.stderr)
                            self.errors.append(f"No opcode ({mn},{mode})")
                        self.pc += opcode_size(mode) if mode in ('imp','acc','imm','zp','zpx','zpy','rel','indx','indy') else 3
                        continue

                opcode = OPCODES[key]
                size = opcode_size(mode)

                if pass_num == 2:
                    # Emit opcode
                    self.emit_byte(opcode)

                    if mode == 'imp' or mode == 'acc':
                        pass
                    elif mode == 'imm' or mode == 'zp' or mode == 'zpx' or mode == 'zpy' or mode == 'indx' or mode == 'indy':
                        self.emit_byte(val & 0xFF)
                    elif mode == 'rel':
                        # val is target address
                        offset = val - (self.pc + 1)
                        if not (-128 <= offset <= 127):
                            print(f"Error: Branch out of range at line {lineno} (offset={offset})", file=sys.stderr)
                            self.errors.append(f"Branch out of range at line {lineno}")
                        self.emit_byte(offset & 0xFF)
                    elif mode in ('abs', 'absx', 'absy', 'ind'):
                        self.emit_word(val)
                    else:
                        self.emit_byte(val & 0xFF)
                else:
                    # Pass 1: just advance PC
                    self.pc += size

    def _all_mnemonics(self):
        return {k[0] for k in OPCODES} | {
            'PROCESSOR', 'ORG', 'BYTE', 'WORD', 'DS', 'ALIGN', 'INCLUDE',
            'SEG', 'HEX', 'DC', 'DB', 'DW', 'ECHO', 'MAC', 'ENDM',
            'SUBROUTINE', 'IFCONST', 'IFNCONST', 'IF', 'ELSE', 'ENDIF',
            'EQU', 'RES', 'SEG.U',
        }

    def get_rom(self, start_addr, size):
        """Extract ROM bytes from start_addr to start_addr+size-1."""
        rom = bytearray(0xFF for _ in range(size))
        for addr, byte in self.memory.items():
            offset = addr - start_addr
            if 0 <= offset < size:
                rom[offset] = byte
        return bytes(rom)


def main():
    import argparse
    parser = argparse.ArgumentParser(description='6502 Assembler for Atari 2600')
    parser.add_argument('input', help='Input .asm file')
    parser.add_argument('-o', '--output', default='out.bin', help='Output binary file')
    parser.add_argument('-f', '--format', choices=['2600', 'raw'], default='2600',
                        help='Output format: 2600=4KB ROM, raw=raw binary')
    parser.add_argument('-v', '--verbose', action='store_true')
    args = parser.parse_args()

    asm = Assembler()
    asm.assemble_file(args.input)

    if asm.errors:
        print(f"Assembly failed with {len(asm.errors)} error(s).", file=sys.stderr)
        sys.exit(1)

    if args.format == '2600':
        rom = asm.get_rom(0xF000, 4096)
    else:
        # Find min/max address
        if asm.memory:
            min_addr = min(asm.memory.keys())
            max_addr = max(asm.memory.keys())
            size = max_addr - min_addr + 1
            rom = asm.get_rom(min_addr, size)
        else:
            rom = b''

    with open(args.output, 'wb') as f:
        f.write(rom)

    if args.verbose:
        print(f"Assembled {len(asm.memory)} bytes -> {args.output} ({len(rom)} byte ROM)")
        # Dump symbols
        for name, val in sorted(asm.symbols.items()):
            print(f"  {name} = ${val:04X}")

    print(f"OK: {args.output} ({len(rom)} bytes)")


if __name__ == '__main__':
    main()
