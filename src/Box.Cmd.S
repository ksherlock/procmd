********************************
*                              *
*  BOX  (DOUBLE HGR BOX FILL)  *
*                              *
*   Glen E. Bredon   4/26/86   *
*                              *
********************************

         DATE

         REL              ;Generate a LNK file
         TR
         EXP   OFF

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/BOX.CMD
         FIN

SOLID    =     $2E0       ;Address of solid color tbl
         ERR   SOLID+$20&$FF

* Tokens:

color    =     160
to       =     193
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
X1       =     $D4
Y1       =     $D5
X0       =     $E0
Y0       =     $E2
XRUN     =     $E3
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
         LDY   #3
:LOOK    DEY
         BMI   YES
         LDA   (TXTPTR),Y
         CMP   FILLCMD,Y
         BEQ   :LOOK
         BNE   NO

         DFB   $F0        ;Signature

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
         RTS

FILLCMD  ASC   'BOX'

XTBL     DFB   1,2,3,$82,5,6,$80

NO       JSR   CHRGOT
         BNE   AMPEXIT    ;Always

COLOR    JSR   GETBYTC
         TXA
         JSR   COLOR2
         JMP   CHRGOT

YES      LDA   TXTPTR
         ADC   #1         ;Carry is set
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
         STA   X0
         LDY   $9D        ;Pick up Y coor
         STY   Y0
         LDA   #to
         JSR   SYNCHR
         JSR   ROMHFNS
         TYA
         LSR
         TXA
         ROR
         TAX
         LDY   $9D
         LDA   #>CHRGOT-1
         PHA
         STA   IN
         LDA   #CHRGOT-1
         PHA
FILL     STX   X1
         CPX   X0
         BGE   :OK
         LDA   X0
         STX   X0
         STA   X1
:OK      INY
         STY   Y1
         CPY   Y0
         BGE   :ST
         LDA   Y0
         STY   Y0
         STA   Y1
:ST      STA   STORE80
         LDA   X0
         STA   XRUN
         LDY   Y0
:MAINLUP STY   Y0
         JSR   POSN       ;Set GBAS and get nibble
         BCC   :SCAN      ;Always
:NXDOT   INC   XRUN
         LDA   XTBL,X
         BPL   :TX
         ASL
         INC   HNDX
:TX      TAX
:SCAN    LDA   Y0
         AND   #%111
         CPX   #3
         ROL
         ASL              ;(Y mod 8)*4 + (X mod 4)*2
         TAY              ; = aux index to table
         LDA   (TBLPNT),Y
         AND   MASKA,X
         PHA
         INY
         CPX   #3
         BNE   :NM
         DEY
         DEY              ;main index to table
:NM      LDA   (TBLPNT),Y
         LDY   HNDX
         AND   MASKM,X
         STA   COLA
         LDA   MASKMX,X
         AND   (GBASL),Y
         ORA   COLA
         ORA   #$80
         STA   (GBASL),Y
         CPX   #3
         BNE   :NI0
         INY
:NI0     STY   HNDXA
         PLA
         STA   COLA
         LDA   MASKAX,X
         BIT   PAGE2
         AND   (GBASL),Y
         ORA   COLA
         ORA   #$80
         STA   (GBASL),Y
         BIT   PAGE1
:NXH     LDA   XRUN
         CMP   X1
         BLT   :NXDOT
         LDA   X0
         STA   XRUN
         LDY   Y0
         INY
         CPY   Y1
         BLT   :MAINLUP
         RTS

POSN     TYA
         STA   TEMP
         AND   #%11000000
         STA   HNDX       ;Temp
         LSR
         LSR
         ORA   HNDX
         STA   GBASL
         TYA
         ASL
         ASL
         ASL
         ROL   TEMP
         ASL
         ROL   TEMP
         ASL
         ROR   GBASL
         LDA   TEMP
         AND   #$1F
         ORA   #$20       ;Always at $2000-
         STA   GBASH
         LDA   XRUN
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
         RTS

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

MASKAX   DFB   %00001111!$FF
         DFB   %01110000!$FF
         DFB   %00000000!$FF
         DFB   %00000011!$FF
         DFB   %00111100!$FF
         DFB   %01000000!$FF
                          ;Last byte = 1st of:
MASKMX   DFB   %00000000!$FF
         DFB   %00000001!$FF
         DFB   %00011110!$FF
         DFB   %01100000!$FF
         DFB   %00000000!$FF
         DFB   %00000111!$FF
         DFB   %01111000!$FF
