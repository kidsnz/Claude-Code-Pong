;;; ============================================================
;;; Atari 2600 Pong - Step 2: パドルを上下に動かす
;;;
;;; ジョイスティック0 (上下) -> 左パドル
;;; ジョイスティック1 (上下) -> 右パドル
;;; ============================================================

    processor 6502

;;; ============================================================
;;; TIA Write Registers
;;; ============================================================
VSYNC   = $00
VBLANK  = $01
WSYNC   = $02
COLUP0  = $06
COLUP1  = $07
COLUBK  = $09
RESP0   = $10
RESP1   = $11
GRP0    = $1B
GRP1    = $1C
HMP0    = $20
HMP1    = $21
HMOVE   = $2A
HMCLR   = $2B

;;; ============================================================
;;; RIOT Registers
;;; ============================================================
SWCHA   = $280          ; ジョイスティック入力 (アクティブLOW)
INSTAT  = $285
TIM64T  = $296

;;; ジョイスティックビット (SWCHA, アクティブLOW)
JOY0_UP   = %00010000  ; bit4
JOY0_DOWN = %00100000  ; bit5
JOY1_UP   = %00000001  ; bit0
JOY1_DOWN = %00000010  ; bit1

;;; ============================================================
;;; RAM - Zero Page ($80-$FF)
;;; ============================================================
    SEG.U ram
    ORG $80

P0Y     ds 1    ; 左パドル上端Y (0-167)
P1Y     ds 1    ; 右パドル上端Y (0-167)
NxtGRP0 ds 1    ; 次ライン用 GRP0 値
NxtGRP1 ds 1    ; 次ライン用 GRP1 値

;;; ============================================================
;;; Constants
;;; ============================================================
PAD_HEIGHT  = 24        ; パドルの高さ (スキャンライン数)
PAD_SPRITE  = $FF       ; 全8ビット = フル幅パドル
PAD_INIT_Y  = 83        ; 初期Y位置 (中央: 190/2 - 24/2 = 83)
PAD_BOT     = 166       ; パドル上端の最大値 (190 - 24 = 166)
PAD_SPEED   = 2         ; 1フレームあたりの移動量

COL_BG      = $00       ; 背景: 黒
COL_PAD     = $0F       ; パドル: 白

;;; ============================================================
;;; ROM: $F000 - $FFFF
;;; ============================================================
    SEG code
    ORG $F000

;;; ============================================================
;;; Reset / Startup
;;; ============================================================
Reset:
    SEI             ; 割り込み禁止
    CLD             ; 10進モード無効
    LDX #$FF
    TXS             ; スタック初期化

    ; RAM と TIA レジスタを全ゼロクリア
    LDA #0
ClearLoop:
    STA 0,X
    DEX
    BNE ClearLoop

    ; VBLANK を有効にしてから開始
    LDA #%00000010
    STA VBLANK

    ; パドル初期位置を設定
    LDA #PAD_INIT_Y
    STA P0Y
    STA P1Y

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

    ;;; ---- VBLANK: 37 lines (タイマー待ち) ----
    LDA #%00000010
    STA VBLANK
    LDA #43             ; 43*64 = 2752 cycles ≈ 37 lines
    STA TIM64T

    ; --- VBLANK中のゲームロジック ---
    JSR ReadJoy         ; ジョイスティック読み込み & パドル移動

VBWait:
    LDA INSTAT          ; bit7 = タイマー満了
    BPL VBWait

    STA WSYNC
    LDA #0
    STA VBLANK

    ;;; ---- Visible Screen: 192 lines ----
    JSR DrawScreen

    ;;; ---- Overscan: 30 lines ----
    LDA #%00000010
    STA VBLANK
    LDA #35
    STA TIM64T

OSWait:
    LDA INSTAT
    BPL OSWait

    STA WSYNC
    JMP Frame

;;; ============================================================
;;; ReadJoy - ジョイスティック入力を読んでパドルを動かす
;;;
;;; SWCHA ビット: アクティブLOW (0 = 押されている)
;;;   Player0: bit4=UP, bit5=DOWN
;;;   Player1: bit0=UP, bit1=DOWN
;;; ============================================================
ReadJoy:
    LDA SWCHA

    ; --- Player0 UP (bit4) ---
    PHA                 ; A を保存
    AND #JOY0_UP
    BNE .p0NoUp         ; bit4 が 1 (押されていない) -> スキップ
    LDA P0Y
    BEQ .p0NoUp         ; P0Y == 0 -> 上端なのでスキップ
    SEC
    SBC #PAD_SPEED
    BCC .p0Top          ; アンダーフロー -> 上端にクランプ
    STA P0Y
    JMP .p0NoUp
.p0Top:
    LDA #0
    STA P0Y
.p0NoUp:

    ; --- Player0 DOWN (bit5) ---
    PLA
    PHA
    AND #JOY0_DOWN
    BNE .p0NoDn         ; bit5 が 1 -> スキップ
    LDA P0Y
    CMP #PAD_BOT
    BCS .p0NoDn         ; P0Y >= PAD_BOT -> 下端なのでスキップ
    CLC
    ADC #PAD_SPEED
    CMP #PAD_BOT
    BCS .p0AtBot
    STA P0Y
    JMP .p0NoDn
.p0AtBot:
    LDA #PAD_BOT
    STA P0Y
.p0NoDn:

    ; --- Player1 UP (bit0) ---
    PLA
    PHA
    AND #JOY1_UP
    BNE .p1NoUp
    LDA P1Y
    BEQ .p1NoUp
    SEC
    SBC #PAD_SPEED
    BCC .p1Top
    STA P1Y
    JMP .p1NoUp
.p1Top:
    LDA #0
    STA P1Y
.p1NoUp:

    ; --- Player1 DOWN (bit1) ---
    PLA
    AND #JOY1_DOWN
    BNE .p1NoDn
    LDA P1Y
    CMP #PAD_BOT
    BCS .p1NoDn
    CLC
    ADC #PAD_SPEED
    CMP #PAD_BOT
    BCS .p1AtBot
    STA P1Y
    JMP .p1NoDn
.p1AtBot:
    LDA #PAD_BOT
    STA P1Y
.p1NoDn:
    RTS

;;; ============================================================
;;; DrawScreen - 192スキャンライン描画
;;;
;;; ライン構成:
;;;   Line  0   : P0/P1 水平位置決め (RESP0, RESP1)
;;;   Line  1   : HMOVE 適用
;;;   Line 2-191: パドル描画 (190ライン)
;;;
;;; 水平位置 (目標):
;;;   P0: x=4   (左パドル) ... RESP0 早期発火 + HMP0=$40
;;;   P1: x=148 (右パドル) ... RESP1 サイクル71 + HMP1=$10
;;; ============================================================
DrawScreen:

    ; HMP0/HMP1 を事前設定
    LDA #$40            ; HMP0: 右に4カラークロック
    STA HMP0
    LDA #$10            ; HMP1: 右に1カラークロック
    STA HMP1

    ; --- Line 0: RESP0 を早期発火、遅延後 RESP1 ---
    STA WSYNC
    STA RESP0           ; x≈0 に P0 を配置 (4サイクル目)

    ; RESP1 を約71サイクル目に発火 -> x=(71-22)*3=147, +HMP1=1 -> x=148
    ; STA RESP0 で4サイクル消費済み、残り67サイクル = 33 NOPs + 1 NOP = 68サイクル
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
    STA RESP1           ; cycle≈71

    ; --- Line 1: HMOVE で微調整を適用 ---
    STA WSYNC
    STA HMOVE
    STA HMCLR

    ; 色設定
    LDA #COL_BG
    STA COLUBK
    LDA #COL_PAD
    STA COLUP0
    STA COLUP1

    ; --- Lines 2-191: パドル描画 (190ライン) ---
    ; 構造: 各ラインで NxtGRP0/NxtGRP1 を計算してから WSYNC → 書き込み
    LDX #0              ; X = 描画ライン番号 (0-189)

DrawLoop:
    ; P0 (左パドル) のスプライトを計算 -> NxtGRP0 に保存
    TXA
    SEC
    SBC P0Y             ; A = X - P0Y
    BCC .p0Off          ; X < P0Y -> パドル範囲外
    CMP #PAD_HEIGHT
    BCS .p0Off          ; X >= P0Y + PAD_HEIGHT -> 範囲外
    LDA #PAD_SPRITE
    JMP .p0Store
.p0Off:
    LDA #0
.p0Store:
    STA NxtGRP0

    ; P1 (右パドル) のスプライトを計算 -> NxtGRP1 に保存
    TXA
    SEC
    SBC P1Y             ; A = X - P1Y
    BCC .p1Off
    CMP #PAD_HEIGHT
    BCS .p1Off
    LDA #PAD_SPRITE
    JMP .p1Store
.p1Off:
    LDA #0
.p1Store:
    STA NxtGRP1

    ; WSYNC 後すぐに書き込む (HBlank 中に完了させる)
    STA WSYNC
    LDA NxtGRP0
    STA GRP0
    LDA NxtGRP1
    STA GRP1

    INX
    CPX #190
    BNE DrawLoop

    ; スプライトをオフ
    LDA #0
    STA GRP0
    STA GRP1
    RTS

;;; ============================================================
;;; Interrupt Vectors
;;; ============================================================
    ORG $FFFA
    WORD Reset      ; NMI
    WORD Reset      ; RESET
    WORD Reset      ; IRQ
