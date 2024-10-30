********************************
*                              *
* PRINTS (SUPER HIRES CHR GEN) *
*                              *
*   Glen E. Bredon   6/25/89   *
*                              *
********************************

         DATE

         REL              ;Generate a LNK file
         XC
         XC
         TR
         TR    ADR
         EXP   OFF

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/PRINTS.CMD
         FIN

* Tokens:

print    =     186
at       =     197

* Applesoft stuff:

PIXCNT   =     $1A        ;Horizontal pixel count
VERT     =     $1B        ;Vertical size of char
GBASL    =     $26
LINNUM   =     $50
INDEX    =     $5E
CHRGET   =     $B1
CHRGOT   =     $B7
TEMP     =     $D0
FONTPNT  =     $D4        ;Font table pointer (local)
X0       =     $E0
Y0       =     $E2
HCOLORZ  =     $E4
HNDX     =     $E5
REMR     =     $E6
HSAV     =     $E7        ;Save for HNDX (for next line)
IN       =     $200
FRMNUM   =     $DD67
CHKSTR   =     $DD6C
FRMEVL   =     $DD7B
SYNCHR   =     $DEC0
IQERR    =     $E199
FREFAC   =     $E600
GETBYT   =     $E6F8
GETADRS  =     $E752
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
         CMP   #print
         BNE   NO
         JSR   CHRGET
         BEQ   PRINT
         CMP   #at
         BEQ   NOADR
         BNE   ISADR

         BRK              ;Filler

FONTADR  DA    $4000      ;To be set up

         DFB   38         ;Signature

         JMP   PRCHR      ;ML access

NO       JSR   CHRGOT
         BNE   AMPEXIT

ISADR    JSR   FRMNUM
         JSR   GETADRS
         MOVD  LINNUM;FONTADR
         LDA   #at
NOADR    JSR   SYNCHR
         JSR   ROMHFNS
PRINT    LDA   #>CHRGOT-1
         PHA
         STA   IN
         LDA   #CHRGOT-1
         PHA
         LDA   #':'
         JSR   SYNCHR
:PRNT    JSR   FRMEVL
         JSR   CHKSTR
         JSR   STRPRT
         JSR   CHRGOT
         BEQ   :RET
         CMP   #';'
         BNE   :PRNT
         JSR   CHRGET
         BNE   :PRNT
:RET     RTS

ROMHFNS  JSR   FRMNUM
         JSR   GETADRS
         LDY   LINNUM+1
         LDX   LINNUM
         CPY   #>320
         BLT   :OV
         BNE   ERR
         CPX   #320
         BGE   ERR
:OV      STX   X0
         STY   X0+1
         LDA   #','
         JSR   SYNCHR
         JSR   GETBYT
         CPX   #200
         BGE   ERR
         STX   Y0
         STZ   Y0+1
         RTS

ERR      JMP   IQERR

STRPRT   JSR   FREFAC
         TAX              ;Length of string
         LDY   #0
         INX
:NXCHR   DEX
         BEQ   :RET
         LDA   (INDEX),Y
         JSR   PRCHR
         INY
         BNE   :NXCHR
:RET     RTS

PRCHR    PHX
         PHY
         STA   TEMP       ;Save chr to print
         CLC
         XCE
         REP   %00100000
         LDA   FONTADR
:FIND    STA   FONTPNT
         SEP   %00110000
         LDY   #1
         LDA   (FONTPNT)  ;Find font for char
         BEQ   :NOTFND    ;Branch if not found
         CMP   TEMP
         REP   %00110001
         BEQ   :GOTFONT   ;This is it
         LDA   (FONTPNT),Y ;Get size this chr
         AND   #$FF
         ADC   FONTPNT    ;Bump table pointer
         BRA   :FIND

:GOTFONT INY
         LDA   (FONTPNT),Y ;Size in pixels
         STA   PIXCNT     ;and VERT
         LDA   FONTPNT
         ADC   #4         ;Carry is clear
         STA   FONTPNT    ;Point to 1st byte of char
         LDX   X0
         LDY   Y0
         JSR   HPOSN      ;Set GBAS, HNDX
:LOOP    LDA   PIXCNT
         STA   TEMP       ;Set horiz count
:LINE    SEP   %00110000
         LDA   (FONTPNT)
         AND   #$F        ;First nibble
         JSR   HCOLOR     ;Set up color
         JSR   HPLOT      ;And plot dot
         DEC   TEMP
         BEQ   :HORDON    ;Exit if horiz done
         LDA   (FONTPNT)
         LSR              ;Get 2nd nibble
         LSR
         LSR
         LSR
         JSR   HCOLOR     ;Set color
         JSR   RIGHT      ;Point to next dot
         JSR   HPLOT      ; and plot it
         DEC   TEMP
         JSR   RIGHT
:HORDON  REP   %00100001
         INC   FONTPNT
         LDY   TEMP
         BNE   :LINE      ;Loop if line not done
         LDA   GBASL
         ADC   #160
         CMP   #160*200+$2000
         BLT   :SP
         SBC   #160*200
:SP      STA   GBASL
         SEP   %00110000
         LDX   REMR       ;Replace X for left dot
         LDA   HSAV       ; and HNDX
         STA   HNDX
         DEC   VERT
         BNE   :LOOP      ;Loop till done
         REP   %00100001
         LDY   PIXCNT
         TYA
         ADC   X0         ;Set X0 to point to next
         CMP   #320       ; horiz position
         BLT   :XOK       ; with 320 wrap around
         SBC   #320
:XOK     STA   X0
:NOTFND  SEC
         XCE
         PLY              ;Must exit with original
         PLX              ; X, Y registers.
         RTS

RIGHT    TXA              ;Point to next dot
         BEQ   :IX
         LDX   #0
         LDA   HNDX
         CMP   #159
         BLT   :IH        ;Branch if no wrap needed
         STZ   HNDX       ;Wrap to left edge
         RTS

:IX      INX
         RTS

:IH      INC   HNDX
:RET     RTS

HPLOT    LDY   HNDX
         BIT   HCOLORZ    ;Plot mode
         BPL   :EOR       ;Do XOR plot if HCOLOR = 0-3
         LDA   [GBASL],Y
         BVS   :OR        ;If overstrike (HCOLOR 6,7)
         AND   MASKS,X    ;Dominant mode (HCOLOR 4,5)
:OR      ORA   COL1,X
         STA   [GBASL],Y
         RTS

:EOR     LDA   [GBASL],Y
         EOR   COL1,X
         STA   [GBASL],Y
         RTS

* Enter HPOSN with X coor in X, Y coor in Y

         MX    %00

HPOSN    TYA
         ASL
         ASL
         ASL
         ASL
         ASL
         STA   GBASL
         ASL
         ASL
         ADC   GBASL
         ADC   #$2000
         STA   GBASL
         TXA
         LSR
         SEP   %00110000
         STA   HNDX
         STA   HSAV
         LDA   #$E1
         STA   GBASL+2
         LDA   #0
         ROL
         STA   REMR
         TAX
         RTS

HCOLOR   STA   COL2
         ASL
         ASL
         ASL
         ASL
         STA   COL1
         RTS

COL1     DFB   %11110000
COL2     DFB   %00001111

MASKS    DFB   %00001111
         DFB   %11110000
