********************************
*                              *
* DHGR (DOUBLE HIRES ROUTINES) *
*                              *
*   Glen E. Bredon   2/21/85   *
*                              *
********************************

         DATE

         REL                                      ;Generate a LNK file
         EXP            OFF
         TR

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/DHGR.CMD
         FIN

* Tokens:

plot     =              $8D
hgr2     =              $90
hgr      =              $91
hcolor   =              $92
hplot    =              $93
amp      =              $AF
to       =              $C1

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
COUNTL   =              $1C
COUNTH   =              $1D
GBASL    =              $26
GBASH    =              $27
LINNUM   =              $50
CHRGET   =              $B1
CHRGOT   =              $B7
DXL      =              $D0
DXH      =              $D1
DY       =              $D2
QDRNT    =              $D3
EL       =              $D4
EH       =              $D5
X0L      =              $E0
X0H      =              $E1
Y0       =              $E2
REMR     =              $E3
HCOLORZ  =              $E4
HNDX     =              $E5
HPAG     =              $E6
XFLG     =              $EB
CURPAG   =              $EC
IN       =              $200
FRMNUM   =              $DD67
SYNCHR   =              $DEC0
IQERR    =              $E199
GETADR   =              $E752
UP       =              $F4DD
DOWN     =              $F50E
COL      =              $F5B2
EQ1C     =              $F5B9
HFNS1    =              $F6CD
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

* ProDOS BASIC interp location:

XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)

DOPLOT   MAC
         LDA            XFLG
DOPLOT1  MAC                                      ;Must preserve carry
         BMI            AC
         LDA            (GBASL),Y
         EOR            HCOLORZ
AC       AND            COL,X
         EOR            (GBASL),Y
         STA            (GBASL),Y
         <<<

         AST            50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP            DOSEXIT
DOSEXIT  JMP            XRETURN                   ;To daisy chain commands
AMPEXIT  JMP            MONRTS                    ;This one to daisy chain & cmds
AMPENTRY BEQ            AMPEXIT                   ;Other & cmds to next routine
         CMP            #amp
         BNE            NO
         JSR            CHRGET
         EOR            #hgr2
         CMP            #hplot!hgr2+1
         BLT            YES
         LDX            #4
         BGE            CONT

         BRK                                      ;Filler

         DFB            18                        ;Signature

         JMP            HPLOT0                    ;ML entry points
         JMP            HGLIN
         JMP            XRETURN
HGR      LDA            FULL,X                    ;Enter here with X=0 (HGR2)
         STA            STORE80                   ; or X=1 (HGR)
         BIT            $C05E                     ;Hit annunciator (double hires)
         STA            $C00D                     ;Turn on "80 col"
         BIT            HIRES
         LDY            #-1
         STY            HCOLORZ
         INY
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
RET      RTS

CONT     CMP            #plot!hgr2
         BEQ            ISPLOT
NO       JSR            CHRGOT
         BNE            AMPEXIT                   ;Always

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

:ADRS    DFB            HGR-1,HGR-1,RET-1,HPLOT-1,PLOT-1

PLOT     SEC
         BCC            *
         DS             -1
HPLOT    CLC
         ROR            XFLG                      ;Minus for xplot
         CMP            #to
         BEQ            :P3
         JSR            HFNS
         JSR            HPLOT0
:P2      JSR            CHRGOT
         CMP            #to
         BNE            RET
:P3      JSR            SYNFNS
         STY            $9D
         TAY
         TXA
         LDX            $9D
         JSR            HGLIN
         JMP            :P2

SYNFNS   JSR            SYNCHR
HFNS     JSR            FRMNUM
         JSR            GETADR
         LDY            LINNUM+1
         LDX            LINNUM
         CPY            #>560
         BLT            :H1
         BNE            ERR
         CPX            #560
         BGE            ERR
:H1      JMP            HFNS1

ERR      JMP            IQERR

HPLOT0   STA            Y0
         STX            X0L
         STY            X0H
         STA            GBASH                     ;First part of this
         AND            #%11000000                ; copies ROM HPOSN
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
         LDX            X0H                       ;Departs here from ROM
         LDY            #-1
:HP0     SEC
:HP1     INY                                      ;Quotient
         SBC            #7
         BCS            :HP1
         DEX
         BPL            :HP0
         ADC            #7
         STA            REMR                      ;Remainder
         TAX
         TYA
         LSR
         STA            HNDX
         TAY
         ROR            CURPAG
         BMI            :LX
         BIT            PAGE2
:LX      LDA            XFLG
         ORA            #$7F
         STA            XFLG
         DOPLOT1
         BIT            PAGE1
         RTS

* Enter HGLIN with A=XL, X=XH, Y=Y coor.
* Source in X0,Y0.

HGLIN    PHA                                      ;Similar to ROM
         SEC
         SBC            X0L
         PHA
         TXA
         SBC            X0H
         STA            QDRNT
         BCS            :HL2
         PLA
         EOR            #$FF
         ADC            #1
         PHA
         LDA            #0
         SBC            QDRNT
:HL2     STA            DXH
         STA            EH
         PLA
         STA            DXL
         STA            EL
         PLA
         STA            X0L
         STX            X0H
         TYA
         CLC
         SBC            Y0
         BCC            :HL3
         EOR            #-1
         ADC            #-2
:HL3     STA            DY
         STY            Y0
         ROR            QDRNT
         SEC
         SBC            DXL
         STA            COUNTL
         LDA            #-1
         SBC            DXH
         STA            COUNTH
         BIT            CURPAG
         BMI            :LH
         BIT            PAGE2
:LH      LDY            HNDX                      ;Y always has horiz byte offset
         LDX            REMR                      ;X always has bit position
         BCS            :MOVEX2                   ;Always taken
:MOVEX   BVC            :RIGHT
         DEX
         BPL            :DOPLOT
         DEY                                      ;Will increase if -> page 2
         LDX            #6
         BPL            :TOGG
:RIGHT   INX
         CPX            #7
         BLT            :DOPLOT
         LDX            #0
:TOGG    BIT            PAGE1
         LDA            CURPAG                    ;Toggle plotting page
         EOR            #$80
         STA            CURPAG
         BMI            :DOPLOT
         BIT            PAGE2
         INY
:DOPLOT  DOPLOT
         SEC
:MOVEX2  LDA            EL
         ADC            DY
         STA            EL
         LDA            EH
         SBC            #0
:HCOUNT  STA            EH
         INC            COUNTL
         BEQ            :OV
:BQ      BIT            QDRNT
         BCS            :MOVEX
         BMI            :DOWN
         LDA            GBASH
         BIT            EQ1C
         BNE            :SUB4
         JSR            UP
         CLC
         BCC            :DP
:DOWN    LDA            GBASH
         ADC            #4
         BIT            EQ1C
         BNE            :SGB
         JSR            DOWN
         CLC
         BCC            :DP
:SUB4    ADC            #-4
         CLC
:SGB     STA            GBASH
:DP      DOPLOT
         LDA            EL                        ;Carry is clear
         ADC            DXL
         STA            EL
         LDA            EH
         ADC            DXH
         BVC            :HCOUNT                   ;Always
:OV      INC            COUNTH
         BNE            :BQ
         BIT            PAGE1
         STX            REMR                      ;Save horiz pointers in
         STY            HNDX                      ; case of a continuation
         RTS
