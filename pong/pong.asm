;;; ============================================================
;;; Atari 2600 Pong Clone  (NTSC, 4KB ROM)
;;; 6507 Assembly - DASM-compatible
;;;
;;; Controls:
;;;   Left  Player (P0): Joystick 0 Up/Down
;;;   Right Player (P1): Joystick 1 Up/Down
;;;
;;; Scoring: First to 9 wins, then scores reset
;;; ============================================================

    processor 6502

;;; ============================================================
;;; TIA Write Registers
;;; ============================================================
VSYNC   = $00
VBLANK  = $01
WSYNC   = $02
NUSIZ0  = $04
NUSIZ1  = $05
COLUP0  = $06
COLUP1  = $07
COLUPF  = $08
COLUBK  = $09
CTRLPF  = $0A
PF0     = $0D
PF1     = $0E
PF2     = $0F
RESP0   = $10
RESP1   = $11
RESBL   = $14
AUDC0   = $15
AUDF0   = $17
AUDV0   = $19
GRP0    = $1B
GRP1    = $1C
ENABL   = $1F
HMP0    = $20
HMP1    = $21
HMBL    = $24
HMOVE   = $2A
HMCLR   = $2B
CXCLR   = $2C

;;; ============================================================
;;; RIOT Registers
;;; ============================================================
SWCHA   = $280
INTIM   = $284
TIM64T  = $296

;;; ============================================================
;;; RAM - Zero Page ($80-$FF)
;;; ============================================================
    SEG.U ram
    ORG $80

P0Y         ds 1    ; Left  paddle top Y in play area (0-135)
P1Y         ds 1    ; Right paddle top Y in play area (0-135)
BallX       ds 1    ; Ball X, 0-159 (screen pixels)
BallY       ds 1    ; Ball Y in play area, 0-159
BallDX      ds 1    ; Ball X velocity: 1=right $FF=left (signed byte)
BallDY      ds 1    ; Ball Y velocity: 1=down  $FF=up   (signed byte)
Score0      ds 1    ; Left  score (0-9 BCD)
Score1      ds 1    ; Right score (0-9 BCD)
SndTimer    ds 1    ; Sound countdown
SndFreq     ds 1    ; Sound AUDF value
SndVol      ds 1    ; Sound AUDV value
NxtGRP0     ds 1    ; Pre-computed GRP0 for next line
NxtGRP1     ds 1    ; Pre-computed GRP1 for next line
NxtBL       ds 1    ; Pre-computed ball enable for next line
LineY       ds 1    ; Current play-area scanline (0-159)
Temp        ds 1    ; General temp

;;; ============================================================
;;; Constants
;;; ============================================================

;;; Paddle geometry
PAD_HEIGHT  = 24    ; Paddle height in play-area scanlines
PAD_SPRITE  = $FF   ; All 8 bits = full-width paddle

;;; Ball size
BALL_HEIGHT = 2

;;; Initial positions
INIT_P0Y    = 68
INIT_P1Y    = 68
INIT_BALLX  = 76    ; near center
INIT_BALLY  = 68
INIT_BALLDX = 0     ; STEP1: frozen (will add movement later)
INIT_BALLDY = 0

;;; Play area bottom (max BallY / P0Y+PAD_HEIGHT)
PLAY_BOT    = 159

;;; Colors (NTSC)
COL_BG      = $00   ; Black
COL_PAD     = $0F   ; White paddles
COL_SCORE   = $0F   ; White score

;;; Joystick bits in SWCHA (active low)
JOY0_UP     = $10
JOY0_DOWN   = $20
JOY1_UP     = $01
JOY1_DOWN   = $02

;;; Paddle speed
PAD_SPEED   = 2

;;; Win score
WIN_SCORE   = 9

;;; ============================================================
;;; ROM: $F000 - $FFFF
;;; ============================================================
    SEG code
    ORG $F000

;;; ============================================================
;;; Digit lookup table - DIGIT-MAJOR order
;;; Each digit = 5 bytes (rows 0-4, top to bottom)
;;; Index: Score*5 + row
;;; Bits: used in GRP0/GRP1 (bit 7 = leftmost pixel)
;;; ============================================================
Digits:
;;; Digit 0
    BYTE %01110000  ; row0:  _###_
    BYTE %10010000  ; row1: #__#_
    BYTE %10010000  ; row2: #__#_
    BYTE %10010000  ; row3: #__#_
    BYTE %01110000  ; row4:  _###_
;;; Digit 1
    BYTE %01100000  ; row0:  ##__
    BYTE %00100000  ; row1:  _#__
    BYTE %00100000  ; row2:  _#__
    BYTE %00100000  ; row3:  _#__
    BYTE %01110000  ; row4:  ###_
;;; Digit 2
    BYTE %11100000  ; row0: ###__
    BYTE %00010000  ; row1: ___#_
    BYTE %01110000  ; row2:  ###_
    BYTE %10000000  ; row3: #____
    BYTE %11110000  ; row4: ####_
;;; Digit 3
    BYTE %11100000  ; row0: ###__
    BYTE %00010000  ; row1: ___#_
    BYTE %01110000  ; row2:  ###_
    BYTE %00010000  ; row3: ___#_
    BYTE %11100000  ; row4: ###__
;;; Digit 4
    BYTE %10010000  ; row0: #__#_
    BYTE %10010000  ; row1: #__#_
    BYTE %11110000  ; row2: ####_
    BYTE %00010000  ; row3: ___#_
    BYTE %00010000  ; row4: ___#_
;;; Digit 5
    BYTE %11110000  ; row0: ####_
    BYTE %10000000  ; row1: #____
    BYTE %11100000  ; row2: ###__
    BYTE %00010000  ; row3: ___#_
    BYTE %11100000  ; row4: ###__
;;; Digit 6
    BYTE %01110000  ; row0:  ###_
    BYTE %10000000  ; row1: #____
    BYTE %11100000  ; row2: ###__
    BYTE %10010000  ; row3: #__#_
    BYTE %01110000  ; row4:  ###_
;;; Digit 7
    BYTE %11110000  ; row0: ####_
    BYTE %00010000  ; row1: ___#_
    BYTE %00100000  ; row2: __#__
    BYTE %01000000  ; row3:  #___
    BYTE %01000000  ; row4:  #___
;;; Digit 8
    BYTE %01110000  ; row0:  ###_
    BYTE %10010000  ; row1: #__#_
    BYTE %01110000  ; row2:  ###_
    BYTE %10010000  ; row3: #__#_
    BYTE %01110000  ; row4:  ###_
;;; Digit 9
    BYTE %01110000  ; row0:  ###_
    BYTE %10010000  ; row1: #__#_
    BYTE %01110000  ; row2:  ###_
    BYTE %00010000  ; row3: ___#_
    BYTE %01110000  ; row4:  ###_

;;; ============================================================
;;; DigitBase - lookup table: digit N -> offset into Digits
;;; ============================================================
DigitBase:
    BYTE 0, 5, 10, 15, 20, 25, 30, 35, 40, 45

;;; ============================================================
;;; Reset / Startup
;;; ============================================================
Reset:
    SEI             ; Disable interrupts
    CLD             ; Clear decimal mode
    LDX #$FF
    TXS             ; Stack -> $FF

    ; Zero all RAM and TIA registers
    LDA #0
ClearLoop:
    STA 0,X
    DEX
    BNE ClearLoop

    ; Initialize game
    JSR InitGame

;;; ============================================================
;;; Main Frame Loop
;;; ============================================================
Frame:
    ;;; ---- VSYNC: 3 lines ----
    LDA #%00000010
    STA VSYNC
    STA WSYNC           ; VSYNC line 1
    STA WSYNC           ; VSYNC line 2
    STA WSYNC           ; VSYNC line 3
    LDA #0
    STA VSYNC

    ;;; ---- VBLANK: 37 lines ----
    LDA #%00000010
    STA VBLANK
    LDA #43         ; 43*64 = 2752 cycles ~ 36 lines, close enough
    STA TIM64T

    ; --- Game Logic During VBLANK ---
    JSR ReadJoy
    ; STEP1: MoveBall and CheckCollisions disabled - ball is frozen
    ;JSR MoveBall
    ;JSR CheckCollisions
    JSR UpdateSound

VBWait:
    LDA INTIM
    BNE VBWait

    STA WSYNC
    LDA #0
    STA VBLANK

    ;;; ---- Visible Screen: 192 lines ----
    JSR DrawScreen

    ;;; ---- Overscan: 30 lines ----
    LDA #%00000010
    STA VBLANK
    LDA #35         ; 35*64=2240 cycles ≈ 29.5 lines + STA WSYNC = 30 lines
    STA TIM64T

OSWait:
    LDA INTIM
    BNE OSWait

    STA WSYNC           ; sync to line boundary before restarting VSYNC
    JMP Frame

;;; ============================================================
;;; InitGame
;;; ============================================================
InitGame:
    LDA #INIT_P0Y
    STA P0Y
    STA P1Y
    LDA #INIT_BALLX
    STA BallX
    LDA #INIT_BALLY
    STA BallY
    LDA #INIT_BALLDX
    STA BallDX
    LDA #INIT_BALLDY
    STA BallDY
    LDA #0
    STA Score0
    STA Score1
    STA SndTimer
    RTS

;;; ============================================================
;;; ReadJoy - Move paddles based on joystick
;;; ============================================================
ReadJoy:
    LDA SWCHA

    ; --- Player 0 (bits 7-4) ---
    PHA
    AND #JOY0_UP        ; Bit 4: up direction (active low)
    BNE P0NoUp
    LDA P0Y
    BEQ P0NoUp          ; Already at top
    SEC
    SBC #PAD_SPEED
    BCC P0AtTop         ; Underflow
    STA P0Y
    JMP P0NoUp
P0AtTop:
    LDA #0
    STA P0Y
P0NoUp:

    PLA
    PHA
    AND #JOY0_DOWN
    BNE P0NoDn
    LDA P0Y
    CMP #(PLAY_BOT - PAD_HEIGHT)
    BCS P0NoDn          ; Already at bottom
    CLC
    ADC #PAD_SPEED
    STA P0Y
P0NoDn:

    ; --- Player 1 (bits 3-0) ---
    PLA
    PHA
    AND #JOY1_UP
    BNE P1NoUp
    LDA P1Y
    BEQ P1NoUp
    SEC
    SBC #PAD_SPEED
    BCC P1AtTop
    STA P1Y
    JMP P1NoUp
P1AtTop:
    LDA #0
    STA P1Y
P1NoUp:

    PLA
    AND #JOY1_DOWN
    BNE P1NoDn
    LDA P1Y
    CMP #(PLAY_BOT - PAD_HEIGHT)
    BCS P1NoDn
    CLC
    ADC #PAD_SPEED
    STA P1Y
P1NoDn:
    RTS

;;; ============================================================
;;; MoveBall - Move ball by its DX/DY
;;; ============================================================
MoveBall:
    ; Move Y (signed)
    LDA BallY
    CLC
    ADC BallDY
    STA BallY

    ; Move X (signed)
    LDA BallX
    CLC
    ADC BallDX
    STA BallX
    RTS

;;; ============================================================
;;; CheckCollisions
;;;
;;; Coordinate spaces:
;;;   BallX: 0-159 screen pixels
;;;   BallY: 0-159 play-area pixels
;;;   Left  paddle visual: x=4..11  (8px wide after positioning)
;;;   Right paddle visual: x=148..155
;;;   Left  goal: BallX < 4
;;;   Right goal: BallX > 151
;;; ============================================================
CheckCollisions:
    ; ---- Top wall: BallY == 0 -> bounce down ----
    LDA BallY
    BNE NotTop
    LDA #1
    STA BallDY
    JSR SndWall
    JMP CheckXEdges

NotTop:
    ; ---- Bottom wall: BallY >= PLAY_BOT-BALL_HEIGHT+1 -> bounce up ----
    CMP #(PLAY_BOT - BALL_HEIGHT + 1)
    BCC CheckXEdges     ; BallY < threshold: no bounce
    LDA #$FF            ; -1: move up
    STA BallDY
    JSR SndWall

CheckXEdges:
    ; ---- Left goal: BallX < 4 ----
    LDA BallX
    CMP #4
    BCS CheckRightGoal
    ; Right player scores
    INC Score1
    LDA Score1
    CMP #WIN_SCORE
    BNE .noWin1
    LDA #0
    STA Score0
    STA Score1
.noWin1:
    JSR SndScore
    JSR ResetBall
    RTS

CheckRightGoal:
    ; ---- Right goal: BallX >= 156 (past paddle zone 148-155) ----
    CMP #156
    BCC CheckLeftPaddle
    ; Left player scores
    INC Score0
    LDA Score0
    CMP #WIN_SCORE
    BNE .noWin0
    LDA #0
    STA Score0
    STA Score1
.noWin0:
    JSR SndScore
    JSR ResetBall
    RTS

CheckLeftPaddle:
    ; Left paddle: x=4..11, y=P0Y..P0Y+PAD_HEIGHT-1
    LDA BallX
    CMP #4
    BCC DoneCollide     ; BallX < 4: already went to goal (handled above), shouldn't reach here
    CMP #12
    BCS CheckRightPaddle ; BallX >= 12: not hitting left paddle
    ; Check Y range
    LDA BallY
    SEC
    SBC P0Y
    BCC CheckRightPaddle ; BallY < P0Y
    CMP #PAD_HEIGHT
    BCS CheckRightPaddle ; BallY >= P0Y+PAD_HEIGHT
    ; Hit left paddle: deflect right, adjust angle
    ; A = hit offset (BallY - P0Y), 0..PAD_HEIGHT-1
    STA Temp            ; Save hit offset before clobbering A
    LDA #2
    STA BallDX          ; Move right
    LDA Temp            ; Restore hit offset for CalcAngle
    JSR CalcAngle       ; sets BallDY based on hit position
    JSR SndPaddle
    JMP DoneCollide

CheckRightPaddle:
    ; Right paddle: x=148..155
    LDA BallX
    CMP #148
    BCC DoneCollide
    CMP #156
    BCS DoneCollide
    ; Check Y range
    LDA BallY
    SEC
    SBC P1Y
    BCC DoneCollide
    CMP #PAD_HEIGHT
    BCS DoneCollide
    ; Hit right paddle: deflect left
    ; A = hit offset (BallY - P1Y), 0..PAD_HEIGHT-1
    STA Temp            ; Save hit offset
    LDA #$FE            ; -2: move left
    STA BallDX
    LDA Temp            ; Restore hit offset for CalcAngle
    JSR CalcAngle
    JSR SndPaddle

DoneCollide:
    RTS

;;; ============================================================
;;; CalcAngle
;;; Input:  A = hit offset (BallY - PaddleY), 0..PAD_HEIGHT-1
;;; Output: BallDY adjusted based on hit position
;;; ============================================================
CalcAngle:
    ; Top third -> steep up, middle -> same, bottom third -> steep down
    CMP #8
    BCC .angUp
    CMP #16
    BCS .angDown
    ; Middle: keep existing direction (or use 1/-1 for slight bounce)
    RTS
.angUp:
    LDA #$FF
    STA BallDY
    RTS
.angDown:
    LDA #1
    STA BallDY
    RTS

;;; ============================================================
;;; ResetBall - Center ball, toggle direction
;;; ============================================================
ResetBall:
    LDA #INIT_BALLX
    STA BallX
    LDA #INIT_BALLY
    STA BallY
    ; Toggle X direction
    LDA BallDX
    EOR #$FF
    CLC
    ADC #1              ; negate: 2 -> $FE(-2), $FE -> 2
    STA BallDX
    LDA #1
    STA BallDY
    RTS

;;; ============================================================
;;; Sound routines
;;; ============================================================
SndPaddle:
    LDA #8
    STA SndTimer
    LDA #$04
    STA SndFreq
    LDA #$08
    STA SndVol
    RTS

SndWall:
    LDA #5
    STA SndTimer
    LDA #$08
    STA SndFreq
    LDA #$06
    STA SndVol
    RTS

SndScore:
    LDA #20
    STA SndTimer
    LDA #$06
    STA SndFreq
    LDA #$0F
    STA SndVol
    RTS

UpdateSound:
    LDA SndTimer
    BEQ .sndOff
    DEC SndTimer
    LDA SndFreq
    STA AUDC0
    STA AUDF0
    LDA SndVol
    STA AUDV0
    RTS
.sndOff:
    LDA #0
    STA AUDV0
    RTS

;;; ============================================================
;;; DrawScreen - Full display kernel (192 scanlines)
;;;
;;; Layout:
;;;   Lines   0-6  : Score display (5 digit rows + 2 blank)
;;;   Lines   7-15 : Blank separator
;;;   Lines  16-175: Play area (160 lines)
;;;   Lines 176-191: Bottom blank (16 lines)
;;;
;;; Horizontal positions (set via cycle-counted strobe):
;;;   P0: x=4   (left paddle / left  score digit)
;;;   P1: x=148 (right paddle / right score digit)
;;;   BL: x=BallX
;;; ============================================================
DrawScreen:

    ;;; === OBJECT POSITIONING ===
    ;;; Line 1 of 3: Position P0 (left) and P1 (right)
    ;;;
    ;;; After STA WSYNC, HBlank = 22 CPU cycles.
    ;;; Fire RESP0 early (during HBlank) -> x near 0, then HMP0 fine-tunes to x=4
    ;;; Fire RESP1 at cycle ~71 after WSYNC -> x ≈ (71-22)*3 = 147, HMP1 adds 1 -> x=148

    ; Set fine adjustments BEFORE the positioning line
    LDA #$40            ; HMP0: move right 4 color clocks
    STA HMP0
    LDA #$10            ; HMP1: move right 1 color clock
    STA HMP1

    STA WSYNC           ; Wait for HBlank start

    ; --- Fire RESP0 early (x near left edge) ---
    ; 0 cycles consumed; STA RESP0 at cycle 4 (abs) -> fires during HBlank -> x≈0
    STA RESP0           ; fires at x≈0 (4 cycles used)

    ; --- Delay 44 cycles, then fire RESP1 at cycle 51 -> x≈(51-22)*3=87 ---
    ; Actually target RESP1 at cycle 22+49=71 for x=147
    ; After RESP0 (4 cycles), need 67 more cycles before RESP1:
    ; 67 cycles = 33 NOPs (66 cycles) + adjust
    NOP                 ; 6
    NOP                 ; 8
    NOP                 ; 10
    NOP                 ; 12
    NOP                 ; 14
    NOP                 ; 16
    NOP                 ; 18
    NOP                 ; 20
    NOP                 ; 22
    NOP                 ; 24
    NOP                 ; 26
    NOP                 ; 28
    NOP                 ; 30
    NOP                 ; 32
    NOP                 ; 34
    NOP                 ; 36
    NOP                 ; 38
    NOP                 ; 40
    NOP                 ; 42
    NOP                 ; 44
    NOP                 ; 46
    NOP                 ; 48
    NOP                 ; 50
    NOP                 ; 52
    NOP                 ; 54
    NOP                 ; 56
    NOP                 ; 58
    NOP                 ; 60
    NOP                 ; 62
    NOP                 ; 64
    NOP                 ; 66
    NOP                 ; 68
    STA RESP1           ; cycle 71 (3-cycle zp STA), x≈(71-22)*3=147

    ; Apply HMOVE on next line to fine-tune positions
    STA WSYNC
    STA HMOVE           ; Apply HMP0, HMP1
    STA HMCLR           ; Clear HM regs to prevent drift

    ;;; Line 3: Position ball (RESBL)
    ;;; After STA WSYNC, delay BallX/16 * 5 cycles then fire RESBL
    ;;; Each 5-cycle loop iteration ≈ 15 color clocks of position
    ;;; Overhead = 9 cycles: LDA(3) + LSR(2)*2 + TAX(2) = 9, padded to get right offset

    ; Clear HMBL (no fine adjust for ball in this implementation)
    LDA #0
    STA HMBL

    STA WSYNC           ; Start positioning line for ball

    ; Overhead: 9 cycles before loop
    LDA BallX           ; 3 cycles (total: 3)
    LSR                 ; 2 (5)  A = BallX/2
    LSR                 ; 2 (7)  A = BallX/4
    LSR                 ; 2 (9)  A = BallX/8
    LSR                 ; 2 (11) A = BallX/16
    ; Pad to 22 cycles total overhead (so loop starts when HBlank ends):
    ; 11 cycles used + 11 more needed:
    NOP                 ; 13
    NOP                 ; 15
    NOP                 ; 17
    NOP                 ; 19
    NOP                 ; 21
    TAX                 ; 23 - X = BallX/16, loop starts just as visible area begins

    ; If X==0, skip loop entirely
    BEQ .blDone

    ; Loop: each iteration = 5 cycles = 15 color clocks of position advance
.blLoop:
    DEX                 ; 2
    BNE .blLoop         ; 3 (taken) / 2 (not taken)

.blDone:
    STA RESBL           ; Position ball here (3 cycles)

    STA WSYNC
    STA HMOVE           ; Apply HMBL (= 0, no effect but good practice)
    STA HMCLR

    ;;; Set colors and disable ball during score display
    LDA #COL_BG
    STA COLUBK
    LDA #COL_PAD
    STA COLUP0
    STA COLUP1
    STA COLUPF          ; Fix: ball color (COLUPF was never set -> ball was black on black)
    LDA #0
    STA ENABL           ; Ball off during score/separator

    ;;; ======================================================
    ;;; Score Display (lines 0-6: 5 digit rows + 2 blank)
    ;;; Use GRP0 for left score, GRP1 for right score
    ;;; Objects are currently at x=4 (P0) and x=148 (P1)
    ;;; ======================================================

    ; Compute index into Digits table for each score
    LDX Score0
    LDA DigitBase,X     ; offset for Score0
    TAX                 ; X = base offset for left digit

    LDY Score1
    LDA DigitBase,Y     ; offset for Score1
    TAY                 ; Y = base offset for right digit

    ; Draw 5 digit rows
    LDA Digits,X
    STA NxtGRP0
    LDA Digits,Y
    STA NxtGRP1

    ; Row 0
    STA WSYNC
    LDA NxtGRP0
    STA GRP0
    LDA NxtGRP1
    STA GRP1

    INX
    INY
    LDA Digits,X
    STA NxtGRP0
    LDA Digits,Y
    STA NxtGRP1

    ; Row 1
    STA WSYNC
    LDA NxtGRP0
    STA GRP0
    LDA NxtGRP1
    STA GRP1

    INX
    INY
    LDA Digits,X
    STA NxtGRP0
    LDA Digits,Y
    STA NxtGRP1

    ; Row 2
    STA WSYNC
    LDA NxtGRP0
    STA GRP0
    LDA NxtGRP1
    STA GRP1

    INX
    INY
    LDA Digits,X
    STA NxtGRP0
    LDA Digits,Y
    STA NxtGRP1

    ; Row 3
    STA WSYNC
    LDA NxtGRP0
    STA GRP0
    LDA NxtGRP1
    STA GRP1

    INX
    INY
    LDA Digits,X
    STA NxtGRP0
    LDA Digits,Y
    STA NxtGRP1

    ; Row 4
    STA WSYNC
    LDA NxtGRP0
    STA GRP0
    LDA NxtGRP1
    STA GRP1

    ; 2 blank lines after score (clear sprites)
    LDA #0
    STA WSYNC
    STA GRP0
    STA GRP1
    STA WSYNC

    ;;; ======================================================
    ;;; Separator: 8 blank lines (lines 7-14)
    ;;; Reposition P0 and P1 for play area (already there from init)
    ;;; ======================================================
    LDX #8
.sepLoop:
    STA WSYNC
    DEX
    BNE .sepLoop

    ;;; ======================================================
    ;;; Play Area Kernel: 160 lines (lines 15-174)
    ;;;
    ;;; Pre-compute GRP0/GRP1/ENABL for line N during line N-1,
    ;;; then write the pre-computed values immediately after WSYNC.
    ;;; This way we have a full visible line (~53 cycles) to compute.
    ;;; ======================================================
    LDX #0          ; X = play-area line counter (0..159)

    ; Pre-compute for line 0 before the loop
    STX LineY
    JSR ComputeGfx  ; Sets NxtGRP0, NxtGRP1, NxtBL

PlayLoop:
    STA WSYNC       ; Wait for HBlank

    ; Write pre-computed values immediately (during HBlank = fast write)
    LDA NxtGRP0     ; 3 cycles
    STA GRP0        ; 3 cycles (zp)
    LDA NxtGRP1     ; 3 cycles
    STA GRP1        ; 3 cycles
    LDA NxtBL       ; 3 cycles
    STA ENABL       ; 3 cycles

    ; Advance line counter
    INX             ; 2 cycles
    CPX #160        ; 2 cycles
    BEQ PlayDone    ; 2/3 cycles

    ; Compute graphics for NEXT line (during visible time of current line)
    STX LineY
    JSR ComputeGfx

    JMP PlayLoop

PlayDone:
    ; Turn everything off
    LDA #0
    STA GRP0
    STA GRP1
    STA ENABL

    ;;; ======================================================
    ;;; Bottom blank: 17 remaining lines (16 + 1 for PlayDone)
    ;;; We've done 3 positioning lines + 7 score+sep lines + 160 play lines
    ;;; = 170 lines. Need 192 total -> 22 more lines.
    ;;; Wait, let's count:
    ;;;   Pos lines: 3 (WSYNC+HMOVE pairs)
    ;;;   Pos: 4, Score+blank: 7, Sep: 8, Play: 160 = 179
    ;;;   Need 192 -> 13 more bottom blank lines
    ;;; ======================================================
    LDX #13
.botLoop:
    STA WSYNC
    DEX
    BNE .botLoop

    RTS

;;; ============================================================
;;; ComputeGfx
;;; Input:  LineY = current play-area scanline (0-159)
;;; Output: NxtGRP0, NxtGRP1, NxtBL
;;; ============================================================
ComputeGfx:
    ; --- Paddle 0 (left) ---
    LDA LineY
    SEC
    SBC P0Y
    BCC .p0Off          ; LineY < P0Y -> off
    CMP #PAD_HEIGHT
    BCS .p0Off          ; LineY >= P0Y + PAD_HEIGHT -> off
    LDA #PAD_SPRITE
    STA NxtGRP0
    JMP .p0Done
.p0Off:
    LDA #0
    STA NxtGRP0
.p0Done:

    ; --- Paddle 1 (right) ---
    LDA LineY
    SEC
    SBC P1Y
    BCC .p1Off
    CMP #PAD_HEIGHT
    BCS .p1Off
    LDA #PAD_SPRITE
    STA NxtGRP1
    JMP .p1Done
.p1Off:
    LDA #0
    STA NxtGRP1
.p1Done:

    ; --- Ball ---
    LDA LineY
    SEC
    SBC BallY
    BCC .blOff          ; LineY < BallY -> off
    CMP #BALL_HEIGHT
    BCS .blOff          ; LineY >= BallY + BALL_HEIGHT -> off
    LDA #%00000010
    STA NxtBL
    RTS
.blOff:
    LDA #0
    STA NxtBL
    RTS

;;; ============================================================
;;; Padding to align vectors at $FFFA
;;; ============================================================
    ORG $FFFA

;;; ============================================================
;;; Interrupt Vectors
;;; ============================================================
    WORD Reset      ; NMI  ($FFFA)
    WORD Reset      ; RESET ($FFFC)
    WORD Reset      ; IRQ  ($FFFE)
