********************************
*                              *
* FILL (DOUBLE HGR COLOR FILL) *
*                              *
*   Glen E. Bredon   1/29/85   *
*                              *
********************************

         DATE

         REL              ;Generate a LNK file
         TR
         EXP   OFF

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/FILL.CMD
         FIN

SOLID    =     $2E0       ;Address of solid color tbl
         ERR   SOLID+$20&$FF

* Tokens:

color    =     160
at       =     197

* Switches:

STORE80  =     $C001
PAGE1    =     $C054
PAGE2    =     $C055

* Applesoft stuff:

GBASL    =     $3E        ;Also used is +- 2
GBASH    =     $3F        ; from here
LINNUM   =     $50
CHRGET   =     $B1
CHRGOT   =     $B7
TXTPTR   =     $B8
TEMP     =     $D0
HNDXA    =     $D1
COLA     =     $D2
UFLAG    =     $D4        ;Flags up mode for stacking
DFLAG    =     $D5        ;Flags down mode for stacking
X0       =     $E0
Y0       =     $E2
HNDX     =     $E5
TBLPNT   =     $EE        ;Pointer to color table
IN       =     $200
FRMNUM   =     $DD67
SYNCHR   =     $DEC0
GETBYTC  =     $E6F5
GETADRS  =     $E752
ROMHFNS  =     $F6B9
MONRTS   =     $FFCB      ;Has RTS (for & linking)

* ProDOS BASIC interp location:

XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)

MOVD     MAC
         LDA   ]1
         STA   ]2
         LDA   ]1+1
         STA   ]2+1
         <<<

         AST   50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   DOSEXIT
DOSEXIT  JMP   XRETURN    ;To daisy chain commands
AMPEXIT  JMP   MONRTS     ;This one to daisy chain & cmds
AMPENTRY BEQ   AMPEXIT    ;Other & cmds to next routine
         CMP   #color
         BEQ   COLOR
         LDY   #4
:LOOK    DEY
         BMI   YES
         LDA   (TXTPTR),Y
         CMP   FILLCMD,Y
         BEQ   :LOOK
         BNE   NO

         DFB   17         ;Signature

         JMP   FILL
COLOR2   LDY   #>SOLID    ;Set pointer to solid
         STY   TBLPNT+1   ; color table
         LDY   #SOLID
         STY   TBLPNT
         AND   #$F
         LSR
         BCC   :OV
         ORA   #8
:OV      STA   TEMP
         ASL
         ASL
         ASL
         ASL
         ORA   TEMP
         BNE   :SS
:RL      PHA
         ASL
         PLA
         ROL
:SS      STA   SOLID&$FF00,Y ;Construct solid color tbl
         INY
         BNE   :RL
EXIT     RTS

FILLCMD  ASC   'FILL'

XTBL     DFB   1,2,3,$82,5,6,$80

NO       JSR   CHRGOT
         BNE   AMPEXIT    ;Always

COLOR    JSR   GETBYTC
         TXA
         JSR   COLOR2
         JMP   CHRGOT

YES      LDA   TXTPTR
         ADC   #2         ;Carry is set
         STA   TXTPTR
         BCC   :GETP
         INC   TXTPTR+1
:GETP    JSR   CHRGET
         CMP   #at
         BEQ   :NOADR
         JSR   FRMNUM
         JSR   GETADRS
         MOVD  LINNUM;TBLPNT
         LDA   #at
:NOADR   JSR   SYNCHR
         JSR   ROMHFNS    ;Get coors
         TYA              ;Divide X coor by 2
         LSR
         TXA
         ROR
         TAX
         LDY   $9D        ;Pick up Y coor
         LDA   #>CHRGOT-1
         PHA
         STA   IN
         LDA   #CHRGOT-1
         PHA
FILL     STX   X0
         STY   Y0
         STA   STORE80
         JSR   SCRN       ;Set GBAS and get nibble
         BNE   EXIT       ;Exit if dot not black
         LDA   #-1
         PHA
:LEFT    LDA   #$80
         STA   UFLAG
         STA   DFLAG
         LDA   X0         ;Move to left border
         BEQ   :SCAN
         DEC   X0
:MAINLUP JSR   SCRN
         BEQ   :LEFT      ;Keep looking if black
:NXDOT   INC   X0
         LDA   XTBL,X
         BPL   :TX
         ASL
         INC   HNDX
:TX      TAX
:JSC     JSR   GETSCR
         BNE   :LDON      ;May branch if from eol
:SCAN    JSR   HPLOT      ;Plot a dot on line
         LDA   MASKM,X    ;Look above
         AND   (GBASL-2),Y
         BNE   :NZ        ;Carry is set here
         BIT   PAGE2
         LDY   HNDXA
         LDA   (GBASL-2),Y
         BIT   PAGE1
         AND   MASKA,X
:NZ      CMP   #1
         BIT   UFLAG
         BPL   :RU        ;Branch if was on color
         BGE   :DWN       ;Branch if color above
         LDY   Y0
         BEQ   :DWN
         TXA
         TSX              ;Check room on stack
         CPX   #$10
         TAX              ;Must preserve X
         BLT   :RIGHT     ;Skip up/down check if no room
         CLC
         DEY              ;Push next seed on stack
         TYA
         PHA
         LDA   X0
         PHA
:RU      ROR   UFLAG      ; then clear flag
:DWN     LDY   HNDX
         LDA   MASKM,X
         AND   (GBASL+2),Y
         BNE   :NZ2
         BIT   PAGE2
         LDY   HNDXA
         LDA   (GBASL+2),Y
         BIT   PAGE1
         AND   MASKA,X
:NZ2     CMP   #1
         BIT   DFLAG
         BPL   :RLF       ;Branch if were on color
         BGE   :RIGHT     ;Branch if color below
         TXA
         TSX              ;Check room on stack
         CPX   #$10
         TAX              ;Must preserve X
         BLT   :RIGHT     ;Skip up/down check if no room
         LDY   Y0
         CPY   #$BF
         BGE   :RIGHT
         INY              ;Push next seed on stack
         TYA
         PHA
         LDA   X0
         PHA
:RLF     ROR   DFLAG
:RIGHT   LDA   X0
         CMP   #139
         BLT   :NXDOT
:LDON    PLA              ;Get next seed
         CMP   #-1
         BEQ   RET        ;Exit if stack empty
         STA   X0
         PLA
         STA   Y0
         JMP   :MAINLUP   ; and loop

SCRN     LDY   Y0
         LDX   #4
         INY
:NX      TYA
         STA   TEMP
         AND   #%11000000
         STA   HNDX       ;Temp
         LSR
         LSR
         ORA   HNDX
         STA   GBASL-2,X
         TYA
         ASL
         ASL
         ASL
         ROL   TEMP
         ASL
         ROL   TEMP
         ASL
         ROR   GBASL-2,X
         LDA   TEMP
         AND   #$1F
         ORA   #$20       ;Always at $2000-
         STA   GBASH-2,X
         DEY
         DEX
         DEX
         BPL   :NX
         LDA   X0
         LDY   #-1
         SEC
:HP1     INY              ;Quotient
         SBC   #7
         BCS   :HP1
         ADC   #7
         TAX
         TYA
         ASL
         CPX   #4
         ADC   #0
         STA   HNDX
GETSCR   LDY   HNDX
         LDA   MASKM,X
         AND   (GBASL),Y
         BNE   RET
         BIT   PAGE2
         CPX   #3
         BNE   :NI
         INY
:NI      LDA   (GBASL),Y
         BIT   PAGE1
         AND   MASKA,X
RET      RTS              ;Z set if dot not black

HPLOT    LDA   Y0
         AND   #%111
         CPX   #3
         ROL
         ASL              ;(Y mod 8)*4 + (X mod 4)*2
         TAY              ; = aux index to table
         LDA   (TBLPNT),Y
         STA   COLA
         INY
         CPX   #3
         BNE   :NM
         DEY
         DEY              ;main index to table
:NM      LDA   (TBLPNT),Y
:AGN     LDY   HNDX
         AND   MASKM,X
         STA   TEMP
         ORA   (GBASL),Y
         ORA   #$80
         STA   (GBASL),Y
         CPX   #3
         BNE   :NI
         INY
:NI      STY   HNDXA
         LDA   COLA
         AND   MASKA,X
         BEQ   :BLK
:P2      BIT   PAGE2
         ORA   (GBASL),Y
         ORA   #$80
         STA   (GBASL),Y
         BIT   PAGE1
:LYH     LDY   HNDX
         RTS

:BLK     LDA   TEMP
         BNE   :LYH
         LDA   #$11       ;Avoid black dots
         AND   MASKA,X
         BNE   :P2
         LDA   #$11
         BNE   :AGN

MASKA    DFB   %00001111
         DFB   %01110000
         DFB   %00000000
         DFB   %00000011
         DFB   %00111100
         DFB   %01000000
                          ;Last byte = 1st of:
MASKM    DFB   %00000000
         DFB   %00000001
         DFB   %00011110
         DFB   %01100000
         DFB   %00000000
         DFB   %00000111
         DFB   %01111000
