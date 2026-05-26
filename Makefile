##
## Atari 2600 Pong - Build System
## Requires: Python 3
##

ASM    = python3 asm6502.py
SRC    = pong.asm
ROM    = pong.bin
EMU    = stella

.PHONY: all clean run

all: $(ROM)

$(ROM): $(SRC) asm6502.py
	$(ASM) $(SRC) -o $(ROM) -v

clean:
	rm -f $(ROM)

run: $(ROM)
	$(EMU) $(ROM)
