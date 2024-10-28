********************************
*                              *
* HGR  (DOUBLE HIRES ROUTINES) *
*                              *
*   Glen E. Bredon   2/21/85   *
*                              *
********************************

         DATE

         REL                                      ;Generate a LNK file
         TR
         EXP            OFF

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/HGR.CMD
         FIN

* Tokens:

plot     =              141
hgr2     =              $90
hgr      =              $91
hcolor   =              $92
hplot    =              $93
draw     =              $94
xdraw    =              $95
to       =              $C1
at       =              $C5

* Switches:

STORE80  =              $C001
GR       =              $C050
FULL     =              $C052
PAGE1    =              $C054
PAGE2    =              $C055
HIRES    =              $C057

* Applesoft stuff:

SHAPEL   =              $1A
SHAPEH   =              $1B
COUNTH   =              $1D
GBASL    =              $26
GBASH    =              $27
MASKAUX  =              $30
MASKMAIN =              $31
CHRGET   =              $B1
CHRGOT   =              $B7
DX       =              $D0
COUNTL   =              $D1
SHAPE    =              COUNTL
DY       =              $D2
QDRNT    =              $D3
EL       =              $D4
EH       =              $D5
X0       =              $E0
Y0       =              $E2
REMR     =              $E3
HCOLORZ  =              $E4
HNDX     =              $E5
HPAG     =              $E6
SCALEZ   =              $E7
SHAPEPNT =              $E8
COLCNT   =              $EA
XFLG     =              $EB
CURPAG   =              $EC
MASK     =              $ED
ROTZ     =              $F9
IN       =              $200
SYNCHR   =              $DEC0
IQERR    =              $E199
COSTBL   =              $F5BA
GETBYT   =              $E6F8
UPDOWN   =              $F4D3
ROMHFNS  =              $F6B9
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

* ProDOS BASIC interp location:

XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)

MOVD     MAC
         LDA            ]1
         STA            ]2
         LDA            ]1+1
         STA            ]2+1
         <<<

         AST            50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP            DOSEXIT
DOSEXIT  JMP            XRETURN                   ;To daisy chain commands
AMPEXIT  JMP            MONRTS                    ;This one to daisy chain & cmds
AMPENTRY BEQ            AMPEXIT                   ;Other & cmds to next routine
         EOR            #hgr2
         CMP            #xdraw!hgr2+1
         BLT            YES
         LDX            #6
         CMP            #plot!hgr2
         BEQ            ISPLOT
         JSR            CHRGOT
         BNE            AMPEXIT                   ;Always

         BRK                                      ;Filler

         DFB            14                        ;Signature

         JMP            HPLOT0                    ;ML entry points
         JMP            HGLIN
         JMP            HCOLOR1
HGR      LDA            FULL,X                    ;Enter here with X=0 (HGR2)
         STA            STORE80                   ; or X=1 (HGR)
         BIT            $C05E                     ;Hit annunciator (double hires)
         STA            $C00D                     ;Turn on "80 col"
         BIT            HIRES
         LDY            #0
         STY            SHAPEL
         BIT            PAGE2
         JSR            :CLRPAG
         BIT            PAGE1
         BIT            GR
:CLRPAG  LDX            #$20
         STX            HPAG
         STX            SHAPEH
         TYA
:CLRLUP  STA            (SHAPEL),Y
         INY
         BNE            :CLRLUP
         INC            SHAPEH
         DEX
         BNE            :CLRLUP
         RTS

YES      TAX                                      ;Use as index to adrs tbl
ISPLOT   LDA            #>CHRGOT-1                ;Set to exit through CHRGOT
         PHA
         STA            IN
         LDA            #CHRGOT-1
         PHA
         LDA            #>AMPENTRY-1
         PHA                                      ;All & entries on one page!
         LDA            :ADRS,X
         PHA                                      ;Low address
         JMP            CHRGET                    ;Go to routine through CHRGET

:ADRS    DFB            HGR-1,HGR-1,HCOLOR-1,HPLOT-1
         DFB            DRAW-1,XDRAW-1,PLOT-1

HCOLOR   JSR            GETBYT
         TXA
HCOLOR1  AND            #$F
         LSR
         BCC            :SC
         ORA            #%1000
:SC      PHA
         LDX            #6
:CLUP    LDY            INDEX,X
         STA            COLA,Y
         ASL
         DEX
         BPL            :CLUP
         PLA
         LSR
         STA            COLM+5
         LSR
         STA            COLA+3
         LSR
         STA            COLM+1
RET      RTS

INDEX    DFB            5,9,1,12,4,8,0

PLOT     SEC
         BCC            *
         DS             -1
HPLOT    CLC
         ROR            XFLG
         CMP            #to
         BEQ            :P3
         JSR            HFNS
         JSR            HPLOT0
:P2      JSR            CHRGOT
         CMP            #to
         BNE            RET
:P3      JSR            SYNFNS
         JSR            HGLIN
         JMP            :P2

SYNFNS   JSR            SYNCHR
HFNS     JSR            ROMHFNS                   ;Get coors
         TYA                                      ;Divide X coor by 2
         LSR
         TXA
         ROR
         TAX                                      ;Need it in both A and X
         LDY            $9D                       ;Pick up Y coor
         RTS

ERR      JMP            IQERR

XDRAW    SEC
         BCC            *
         DS             -1
DRAW     CLC
         ROR            XFLG
         JSR            GETBYT                    ;Copy of part of ROM rtn
         MOVD           SHAPEPNT;SHAPEL
         TXA
         LDX            #0
         CMP            (SHAPEL,X)
         BEQ            :D0
         BGE            ERR
:D0      ASL
         BCC            :D1
         INC            SHAPEH
         CLC
:D1      TAY
         LDA            (SHAPEL),Y
         ADC            SHAPEL
         TAX
         INY
         LDA            (SHAPEL),Y
         ADC            SHAPEPNT+1
         STA            SHAPEH
         STX            SHAPEL
         JSR            CHRGOT
         CMP            #at
         BNE            :DODRAW
         JSR            SYNFNS                    ;Departs here from
         JSR            HPOSN                     ; ROM routine
         LDA            DRAWMSK,X
         STA            MASK                      ;Has just one bit set
         TXA                                      ;Compute page for
         LSR                                      ; this pixel
         LSR
         ROR            CURPAG                    ;Fall into :DODRAW
:DODRAW  BIT            CURPAG
         BMI            :LR
         BIT            PAGE2
:LR      LDA            ROTZ
         LUP            4
         LSR
         --^
         STA            QDRNT
         LDA            ROTZ
         AND            #$F
         TAX
         LDY            COSTBL,X
         STY            DX
         EOR            #$F
         TAX
         LDY            COSTBL+1,X
         INY
         STY            DY
         LDY            HNDX
         LDX            #0
         STX            COLCNT
:GS      LDA            (SHAPEL,X)
         BEQ            :RET
:D2      STA            SHAPE
         LDX            #$80
         STX            EL
         STX            EH
         LDX            SCALEZ
:D3      LDA            EL
         SEC
         ADC            DX
         STA            EL
         BCC            :D4
         JSR            LRUD1
         CLC
:D4      LDA            EH
         ADC            DY
         STA            EH
         BCC            :D5
         JSR            LRUD2
:D5      DEX
         BNE            :D3
         LDA            SHAPE
         LSR
         LSR
         LSR
         BNE            :D2
         INC            SHAPEL
         BNE            :GS
         INC            SHAPEH
         BNE            :GS
:RET     STY            HNDX
         BIT            PAGE1
         RTS

         ERR            DRAW!AMPENTRY&$FF00

* Left right move for DRAW:

LFTRT    BPL            :RIGHT
         LSR            MASK
         BCC            :RET
         BIT            PAGE2
         ROR
         EOR            CURPAG
         STA            CURPAG
         BPL            :NC
         BIT            PAGE1
         DEY
         BPL            :NC
         LDY            #39
:NC      LDA            #%01000000
         STA            MASK
         RTS
:RIGHT   ASL            MASK
         BPL            :RET
         BIT            PAGE1
         LDA            CURPAG
         EOR            #$80
         STA            CURPAG
         BMI            :OK
         BIT            PAGE2
         INY
         CPY            #40
         BLT            :OK
         LDY            #0
:OK      LDA            #1
         STA            MASK
:RET     RTS

* Plot pixel then move
* left/right/up/down (for DRAW):

LRUD1    CLC
LRUD2    LDA            SHAPE
         AND            #4
         BEQ            LRUD4                     ;Branch if move only
         BIT            XFLG
         BPL            :LG                       ;Branch if DRAW
         LDA            MASK                      ;This is for XDRAW
         AND            (GBASL),Y
         BNE            :EO
         LDA            MASK
         BPL            :IC
:LG      LDA            (GBASL),Y
         EOR            HCOLORZ                   ;Assumes this is 0 or 7F,FF
         AND            MASK
         BNE            :EO
:IC      INC            COLCNT
:EO      EOR            (GBASL),Y
         STA            (GBASL),Y
LRUD4    LDA            SHAPE
         ADC            QDRNT
         AND            #3
         CMP            #2
         ROR
         BCS            LFTRT
         JMP            UPDOWN                    ;Use ROM up/down routine

HPLOT0   STX            X0                        ;Here X,Y = x,y coor
         STY            Y0
         JSR            HPOSN                     ;Here A= x coor, Y = y coor
HPLOT2   LDY            HNDX
         LDA            (GBASL),Y
         AND            MASKMAIN
         EOR            COLM,X
         STA            (GBASL),Y
         BIT            PAGE2
         CPX            #3                        ;Horiz loc 3 (mod 7)
         BNE            :ND                       ; crosses byte bndry
         INY
:ND      LDA            (GBASL),Y
         AND            MASKAUX
         EOR            COLA,X
         STA            (GBASL),Y
         BIT            PAGE1
         RTS

* Enter HPOSN with X coor in X, Y coor in Y

HPOSN    TYA
         STA            GBASH                     ;First part of this
         AND            #%11000000                ; copies ROM
         STA            GBASL
         LSR
         LSR
         ORA            GBASL
         STA            GBASL
         LDA            GBASH
         ASL
         ASL
         ASL
         ROL            GBASH
         ASL
         ROL            GBASH
         ASL
         ROR            GBASL
         LDA            GBASH
         AND            #$1F
         ORA            #$20                      ;Always at $2000-
         STA            GBASH
         TXA
         LDY            #-1
         SEC
:HP1     INY                                      ;Quotient
         SBC            #7
         BCS            :HP1
         ADC            #7                        ;Departs here from ROM
         STA            REMR                      ;Remainder
         TAX
         TYA
         ASL
         CPX            #4
         ADC            #0
         STA            HNDX
GETMASK  LDY            #$7F                      ;Prepare to set masks
         TYA                                      ; to $7F for XPLOT
         BIT            XFLG
         BMI            :STMSK                    ;Branch if XPLOT
         LDA            MASKA,X
         LDY            MASKM,X
:STMSK   STA            MASKAUX
         STY            MASKMAIN
         RTS

* Enter HGLIN with A,Y = x,y coor of dest.
* Source in X0,Y0.

HGLIN    TAX                                      ;Similar to ROM except
         SEC                                      ; that X high is 0
         SBC            X0
         STX            X0
         ROR            QDRNT
         BMI            :SD
         EOR            #-1
         CLC
         ADC            #1
:SD      STA            DX
         STA            EL
         TYA
         CLC
         SBC            Y0
         BCC            :HL2
         EOR            #-1
         ADC            #-2
:HL2     STA            DY
         STY            Y0
         ROR            QDRNT
         SEC
         SBC            DX
         STA            COUNTL
         LDA            #0
         STA            EH
         SBC            #1
         STA            COUNTH
         LDX            REMR
         BCC            :MOVEX2                   ;Always
:MOVEX   BVS            :RIGHT
         DEX
         BPL            :CX3
         LDX            #6
:DH      DEC            HNDX
         BPL            :GM                       ;Always
:CX3     CPX            #3
         BNE            :GM
         BEQ            :DH
:RIGHT   INX
         CPX            #7
         BLT            :CX4
         LDX            #0
         BEQ            :IH
:CX4     CPX            #4
         BNE            :GM
:IH      INC            HNDX
:GM      JSR            GETMASK
         JSR            HPLOT2
:MOVEX2  SEC
         LDA            EL
         ADC            DY
         STA            EL
         LDA            #-1
:HCOUNT  ADC            EH
         STA            EH
         INC            COUNTL
         BEQ            :OV
:LQ      BIT            QDRNT
         BCS            :MOVEX
         JSR            UPDOWN
         JSR            HPLOT2
         CLC
         LDA            EL
         ADC            DX
         STA            EL
         LDA            #0
         BEQ            :HCOUNT
:OV      INC            COUNTH
         BNE            :LQ
:RET     STX            REMR
         RTS

MASKA    DFB            %01110000
         DFB            %00001111
         DFB            %01111111
         DFB            %01111100
         DFB            %01000011
         DFB            %00111111
                                                  ;Last byte = 1st of:
MASKM    DFB            %01111111
         DFB            %01111110
         DFB            %01100001
         DFB            %00011111
         DFB            %01111111
         DFB            %01111000
         DFB            %00000111

COLA     DFB            %10001111
         DFB            %11110000
         DFB            %10000000
         DFB            %10000011
         DFB            %10111100
         DFB            %11000000
                                                  ;Last byte = 1st of:
COLM     DFB            %10000000
         DFB            %10000001
         DFB            %10011110
         DFB            %11100000
         DFB            %10000000
         DFB            %10000111
         DFB            %11111000

DRAWMSK  DFB            %00000001
         DFB            %00010000
         DFB            %00000010
         DFB            %00100000
         DFB            %00000100
         DFB            %01000000
         DFB            %00001000
