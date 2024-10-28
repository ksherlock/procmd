********************************
*                              *
* SHR   (SUPER HIRES ROUTINES) *
*                              *
*   Glen E. Bredon   5/14/89   *
*                              *
********************************

         DATE

         REL                                      ;Generate a LNK file
         TR
         TR             ADR
         XC
         XC
         EXP            OFF

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/SHR.CMD
         FIN

* Tokens:

text     =              $89
plot     =              $8D
hgr2     =              $90
hgr      =              $91
hcolor   =              $92
hplot    =              $93
draw     =              $94
xdraw    =              $95
rot      =              $98
color    =              $A0
to       =              $C1
at       =              $C5

* Switches:

NEWVIDEO =              $C029
SHADOW   =              $C035

* Applesoft stuff:

SHAPEL   =              $1A
SHAPEH   =              $1B
COUNTL   =              $1C
COUNTH   =              $1D
SHAPE    =              COUNTL
GBASL    =              $2D
MASKMAIN =              $30
LINNUM   =              $50
FAC      =              $9D
CHRGET   =              $B1
CHRGOT   =              $B7
DX       =              $D0
DY       =              $D2
QDRNT    =              $D3
EL       =              $D4
EH       =              $D5
X0       =              $E0
Y0       =              $E2
REMR     =              $E3
HCOLORZ  =              $E4
HNDX     =              $E5
SCALEZ   =              $E7
SHAPEPNT =              $E8
COLCNT   =              $EA
XFLG     =              $EB
MASK     =              $ED
ROTZ     =              $F9
IN       =              $200
FRMNUM   =              $DD67
SYNCHR   =              $DEC0
IQERR    =              $E199
QINT     =              $EBF2
COSTBL   =              $F5BA
GETBYT   =              $E6F8
GETADR   =              $E752
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
         BEQ            GOTIT
         INX
         CMP            #text!hgr2
         BRA            OVER

         BRK

         DFB            36                        ;Signature

         BRL            HPLOT0                    ;ML entry points
         BRL            HGLIN
         BRL            HCOLOR1
         BRL            HGR

OVER     BEQ            GOTIT
         INX
         CMP            #color!hgr2
         BEQ            GOTIT
         INX
         CMP            #rot!hgr2
         BEQ            GOTIT
         JSR            CHRGOT
         BRA            AMPEXIT                   ;Always

HGR      LDA            #$E1
         STA            GBASL+2
         DO             0
         LDA            #$1E
         STA            SHADOW                    ;Shadowing off
         FIN
         LDA            #%01000000
         TSB            NEWVIDEO
         CLC
         XCE
         REP            %00110000
         LDX            #200*$A0-2
         LDA            #0
]LUP     STAL           $E12000,X
         DEX
         DEX
         BPL            ]LUP
         LDX            #$C6
]LUP     LDAL           $E19D00,X
         AND            #%00010000_00010000
         STAL           $E19D00,X
         DEX
         DEX
         BPL            ]LUP
         LDX            #$1E
]LUP     LDA            PALLET,X
         STAL           $E19E00,X
         DEX
         DEX
         BPL            ]LUP
         SEC
         XCE
         STZ            PINDEX
         LDA            #$FF
         STA            HCOLORZ
         LDA            #%11000000
         TSB            NEWVIDEO
         RTS

YES      TAX                                      ;Use as index to adrs tbl
GOTIT    LDA            #>CHRGOT-1                ;Set to exit through CHRGOT
         PHA
         STA            IN
         LDA            #CHRGOT-1
         PHA
         LDA            :ADRSHI,X
         PHA                                      ;All & entries on one page!
         LDA            :ADRS,X
         PHA                                      ;Low address
         JMP            CHRGET                    ;Go to routine through CHRGET

:ADRS    DFB            HGR-1,HGR-1,HCOLOR-1,HPLOT-1
         DFB            DRAW-1,XDRAW-1,PLOT-1,TEXT-1
         DFB            COLOR-1,ROT-1

:ADRSHI  DFB            >HGR-1,>HGR-1,>HCOLOR-1,>HPLOT-1
         DFB            >DRAW-1,>XDRAW-1,>PLOT-1,>TEXT-1
         DFB            >COLOR-1,>ROT-1

TEXT     LDA            #%11111110
         TRB            NEWVIDEO
         DO             0
         LDA            #8
         STA            SHADOW
         FIN
         RTS

ROT      JSR            GETBYT
         TXA
         ASL
         AND            #$1F
         BEQ            :RET
         TAY
         DEY
         DEY
]LUP     LDA            $C019
         BMI            ]LUP
]LUP     LDA            $C019
         BPL            ]LUP
         CLC
         XCE
         REP            %00100000
         LDX            #$1E
]LUP     LDAL           $E19E00,X
         STA            TP,Y
         DEY
         DEY
         BPL            :OK
         LDY            #$1E
:OK      DEX
         DEX
         BPL            ]LUP
         LDX            #$1E
         TXY
]LUP     LDA            TP,Y
         BEQ            :DY
         STA            PALLET,X
         STAL           $E19E00,X
         DEX
         DEX
:DY      DEY
         DEY
         BPL            ]LUP
         SEC
         XCE
:RET     RTS

HCOLOR   JSR            GETBYT
         TXA
HCOLOR1  AND            #$F
         STA            HCOLORZ
         STA            COLM+1
         ASL
         ASL
         ASL
         ASL
         STA            COLM
         TSB            HCOLORZ
RET      RTS

PLOT     SEC
         BCC            *
         DS             -1
HPLOT    CLC
         ROR            XFLG
         CMP            #to
         BEQ            :P3
         JSR            HFNS
         BCS            :ERR
         JSR            HPLOT0
         SEC
         XCE
:P2      JSR            CHRGOT
         CMP            #to
         BNE            RET
:P3      JSR            SYNFNS
         BCS            :ERR
         JSR            HGLIN
         SEC
         XCE
         BRA            :P2

]LUP     JSR            SYNFNS
:ERR     JSR            CHRGOT
         CMP            #to
         BEQ            ]LUP
         RTS

NEXTC    LDA            #','
         JSR            SYNCHR
COLOR    JSR            GETBYT
         TXY
         CPX            #16
         BGE            ERR
         LDA            #%11110000
         STA            MASK
         LDA            PINDEX
         LSR
         TAX
         ROL
         AND            #%11
         BEQ            :HI
         BIT            #%10
         BEQ            :LO
         INC            PINDEX
         BRA            :LO

:HI      LDA            #%00001111
         STA            MASK
         TYA
         ASL
         ASL
         ASL
         ASL
         TAY
:LO      LDA            MASK
         AND            PALLET,X
         STA            PALLET,X
         TYA
         ORA            PALLET,X
         STA            PALLET,X
         STAL           $E19E00,X
         LDA            PINDEX
         INC
         AND            #$3F
         STA            PINDEX
         AND            #%11
         BNE            NEXTC
         RTS

ERR      JMP            IQERR

ROMHFNS  JSR            FRMNUM
         JSR            GETADR
         LDY            LINNUM+1
         LDX            LINNUM
         CPY            #>320
         BLT            :OV
         BNE            :ERR
         CPX            #320
         BGE            :ERR
:OV      PHX
         PHY
         LDA            #','
         JSR            SYNCHR
         JSR            FRMNUM
         JSR            QINT
         SEC
         LDX            FAC+3
         BNE            :PY
         LDX            FAC+4
         CPX            #200
         TXA
:PY      PLY
         PLX
:RET     RTS

:ERR     JSR            :OV
         SEC
         RTS

SYNFNS   JSR            SYNCHR
HFNS     JSR            ROMHFNS                   ;Get coors
         BCS            HRET
         STA            $9D
         STX            $9C
         TYA
         XBA
         LDA            $9C
         CLC
         XCE
         REP            %00110001
         TAX
         LDA            $9D                       ;Pick up Y coor
         AND            #$FF
         TAY
HRET     RTS

         MX             %11

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
         BCS            HRET
         JSR            HPOSN                     ; ROM routine
         SEC
         XCE
:DODRAW  LDA            ROTZ
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
         STZ            COLCNT
:GS      LDA            (SHAPEL)
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
         RTS

* Left right move for DRAW:

LFTRT    BPL            :RIGHT
         LDA            MASK
         BPL            :OK
         TYA
         BNE            :DY
         LDY            #160
:DY      DEY
:NC      LDA            #%00001111
         BRA            :SMASK

:RIGHT   LDA            MASK
         BMI            :NC
         INY
         CPY            #160
         BLT            :OK
         LDY            #0
:OK      LDA            #%11110000
:SMASK   STA            MASK
         STY            HNDX
         RTS

* Plot pixel then move
* left/right/up/down (for DRAW):

LRUD1    CLC
LRUD2    LDA            SHAPE
         BIT            #4
         BEQ            LRUD4                     ;Branch if move only
         BIT            XFLG
         BPL            :LG                       ;Branch if DRAW
         LDA            MASK                      ;This is for XDRAW
         AND            [GBASL],Y
         BNE            :EO
         LDA            MASK
         BRA            :IC

:LG      LDA            [GBASL],Y
         EOR            HCOLORZ                   ;Assumes this is 0 or FF
         AND            MASK
         BNE            :EO
:IC      INC            COLCNT
:EO      EOR            [GBASL],Y
         AND            HCOLORZ
         STA            [GBASL],Y
         LDA            SHAPE
LRUD4    ADC            QDRNT
         AND            #3
         CMP            #2
         ROR
         BCS            LFTRT
UPDOWN   XCE                                      ;Carry is clear
         REP            %00100001
         BMI            DOWN
         LDA            GBASL
         SBC            #159
         CMP            #$2000
         BGE            UDFIN
         ADC            #200*160
         BRA            UDFIN

DOWN     LDA            GBASL
         ADC            #160
         CMP            #200*160+$2000
         BLT            UDFIN
         SBC            #200*160
UDFIN    STA            GBASL
         SEC
         XCE
         RTS

         MX             %00

HPLOT0   STX            X0                        ;Here X,Y = x,y coor
         STY            Y0
         JSR            HPOSN                     ;Here A= x coor, Y = y coor
         MX             %11
HPLOT2   LDY            HNDX
         LDA            [GBASL],Y
         AND            MASKMAIN
         STA            COLCNT
         EOR            COLM,X
         BIT            XFLG
         BPL            :S
         EOR            [GBASL],Y
         ORA            COLCNT
:S       STA            [GBASL],Y
         RTS

* Enter HPOSN with X coor in X, Y coor in Y

         MX             %00

HPOSN    TYA
         ASL
         ASL
         ASL
         ASL
         ASL
         STA            GBASL
         ASL
         ASL
         ADC            GBASL
         ADC            #$2000
         STA            GBASL
         TXA
         LSR
         SEP            %00110000
         STA            HNDX
         LDA            #0
         ROL
         STA            REMR
         TAX
GETMASK  LDA            MASKS,X
:STMSK   STA            MASKMAIN
         LDA            DRAWMSKS,X
         STA            MASK
         RTS

* Enter HGLIN with X,Y = x,y coor of dest.
* Source in X0,Y0.

         MX             %00

HGLIN    TXA                                      ;Similar to ROM
         SEP            %00110001
         XBA
         TAX
         XBA
         PHA
         SBC            X0
         PHA
         TXA
         SBC            X0+1
         STA            QDRNT
         BCS            :SD
         PLA
         EOR            #$FF
         ADC            #1
         PHA
         LDA            #0
         SBC            QDRNT
:SD      STA            DX+1
         STA            EH
         PLA
         STA            DX
         STA            EL
         PLA
         STA            X0
         STX            X0+1
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
         LDA            #-1
         SBC            DX+1
         STA            COUNTH
         LDX            REMR
         BRA            :MOVEX2                   ;Always

:MOVEX   ASL
         JSR            LFTRT
         EOR            #%11111111
         STA            MASKMAIN                  ;For HGLIN
         TXA
         EOR            #1
         TAX
:MOVEX2  SEC
         LDA            EL
         ADC            DY
         STA            EL
         LDA            EH
         SBC            #0
:HCOUNT  STA            EH
         JSR            HPLOT2
         INC            COUNTL
         BNE            :OV
         INC            COUNTH
         BEQ            :RET
:OV      LDA            QDRNT
         BCS            :MOVEX
         JSR            UPDOWN
         CLC
         LDA            EL
         ADC            DX
         STA            EL
         LDA            EH
         ADC            DX+1
         BRA            :HCOUNT

:RET     STX            REMR
         RTS

PINDEX   DFB            0

DRAWMSKS DFB            %11110000
         DFB            %00001111

MASKS    DFB            %00001111
         DFB            %11110000

COLM     DFB            %11110000
         DFB            %00001111

PALLET   DFB            %00000000,%00000000
         DFB            %11010000,%00001111
         DFB            %10100000,%00001111
         DFB            %01110000,%00001111
         DFB            %00000000,%00001111
         DFB            %00001000,%00001111
         DFB            %00001111,%00001111
         DFB            %00001111,%00001011
         DFB            %00001111,%00000110
         DFB            %00001111,%00000000
         DFB            %10001111,%00000000
         DFB            %11111111,%00000000
         DFB            %11111000,%00000100
         DFB            %11110000,%00001000
         DFB            %11110000,%00001100
         DFB            %11110000,%00001111

TP       DS             $20
