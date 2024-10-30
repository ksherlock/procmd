********************************
*                              *
* PRINT (DOUBLE HIRES CHR GEN) *
*                              *
*   Glen E. Bredon    2/3/85   *
*                              *
********************************

         DATE

         REL              ;Generate a LNK file
         TR
         EXP   OFF

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/PRINT.CMD
         FIN

* Tokens:

print    =     186
at       =     197

* Switches:

STORE80  =     $C001
PAGE1    =     $C054
PAGE2    =     $C055

* Applesoft stuff:

PIXCNT   =     $1A        ;Horizontal pixel count
VERT     =     $1B        ;Vertical size of char
GBASL    =     $26
GBASH    =     $27
XSAV1    =     $3C
XSAV     =     $3E
YSAV     =     $3F
LINNUM   =     $50
INDEX    =     $5E
CHRGET   =     $B1
CHRGOT   =     $B7
TEMP     =     $D0
FONTPNT  =     $D4        ;Font table pointer (local)
X0       =     $E0
REMR     =     $E1
Y0       =     $E2
HSAV     =     $E3        ;Save for HNDX (for next line)
HCOLORZ  =     $E4
HNDX     =     $E5
HPAG     =     $E6
IN       =     $200
FRMNUM   =     $DD67
CHKSTR   =     $DD6C
FRMEVL   =     $DD7B
SYNCHR   =     $DEC0
FREFAC   =     $E600
GETADRS  =     $E752
DOWN     =     $F504
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

INCD     MAC
         INC   ]1
         BNE   NI
         INC   ]1+1
NI       <<<

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

         DFB   19         ;Signature

         JMP   PRCHR      ;ML access

NO       JSR   CHRGOT
         BNE   AMPEXIT

ISADR    JSR   FRMNUM
         JSR   GETADRS
         MOVD  LINNUM;FONTADR
         LDA   #at
NOADR    JSR   SYNCHR
         JSR   ROMHFNS
         TYA              ;Divide X coor by 2
         LSR
         TXA
         ROR
         LDY   $9D
         STA   X0
         STY   Y0
PRINT    LDA   #>CHRGOT-1
         PHA
         STA   IN
         LDA   #CHRGOT-1
         PHA
         LDA   #$20
         STA   HPAG       ;Safety
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

PRCHR    STX   XSAV
         STY   YSAV
         STA   TEMP       ;Save chr to print
         STA   STORE80
         MOVD  FONTADR;FONTPNT
:FIND    LDY   #0
         LDA   (FONTPNT),Y ;Find font for char
         BEQ   :NOTFND    ;Branch if not found
         CMP   TEMP
         BEQ   :GOTFONT   ;This is it
         INY
         LDA   (FONTPNT),Y ;Get size this chr
         CLC
         ADC   FONTPNT    ;Bump table pointer
         STA   FONTPNT
         BCC   :FIND
         INC   FONTPNT+1
         BCS   :FIND      ; and look again
:GOTFONT LDY   #2
         LDA   (FONTPNT),Y ;Size in pixels
         STA   PIXCNT
         INY
         LDA   (FONTPNT),Y ;Vertical size
         STA   VERT
         LDA   FONTPNT
         ADC   #3         ;Carry is set
         STA   FONTPNT    ;Point to 1st byte of char
         BCC   :LA
         INC   FONTPNT+1
:LA      LDA   Y0
         JSR   HPOSN      ;Set GBAS, HNDX
:LOOP    LDA   PIXCNT
         STA   TEMP       ;Set horiz count
:LINE    LDY   #0
         LDA   (FONTPNT),Y
         AND   #$F        ;First nibble
         JSR   HCOLOR     ;Set up color
         JSR   HPLOT      ;And plot dot
         DEC   TEMP
         BEQ   :HORDON    ;Exit if horiz done
         LDY   #0
         LDA   (FONTPNT),Y
         LSR              ;Get 2nd nibble
         LSR
         LSR
         LSR
         JSR   HCOLOR     ;Set color
         JSR   RIGHT      ;Point to next dot
         JSR   HPLOT      ; and plot it
         DEC   TEMP
         JSR   RIGHT
:HORDON  INCD  FONTPNT
         LDA   TEMP
         BNE   :LINE      ;Loop if line not done
         JSR   DOWN       ;Point GBAS to next line
         LDX   REMR       ;Replace X for left dot
         LDA   HSAV       ; and HNDX
         STA   HNDX
         DEC   VERT
         BNE   :LOOP      ;Loop till done
         LDA   PIXCNT
         CLC
         ADC   X0         ;Set X0 to point to next
         CMP   #140       ; horiz position
         BLT   :XOK       ; with 140 wrap around
         SBC   #140
:XOK     STA   X0
:NOTFND  LDX   XSAV       ;Must exit with original
         LDY   YSAV       ; X, Y registers.
         RTS

RIGHT    INX              ;Point to next dot
         CPX   #7
         BLT   :CX4       ;X is mod 7
         LDX   #0
         LDA   HNDX
         CMP   #39
         BLT   :IH        ;Branch if no wrap needed
         STX   HNDX       ;Wrap to left edge
         RTS
:CX4     CPX   #4         ;Place where HNDX changes?
         BNE   :RET       ;Branch if not
:IH      INC   HNDX
:RET     RTS

HPLOT    LDY   HNDX
         BIT   HCOLORZ    ;Plot mode
         BPL   :EOR       ;Do XOR plot if HCOLOR = 0-3
         LDA   (GBASL),Y
         BVS   :OR        ;If overstrike (HCOLOR 6,7)
         AND   MASKM,X    ;Dominant mode (HCOLOR 4,5)
:OR      ORA   COLM,X
         AND   #$7F
         STA   (GBASL),Y
         CPX   #3
         BNE   :OV
         INY
:OV      LDA   PAGE2
         LDA   (GBASL),Y
         BVS   :OR2
         AND   MASKA,X
:OR2     ORA   COLA,X
         AND   #$7F
         STA   (GBASL),Y
         BIT   PAGE1
         RTS

:EOR     LDA   (GBASL),Y
         EOR   COLM,X
         STA   (GBASL),Y
         BIT   PAGE2
         CPX   #3
         BNE   :OV2
         INY
:OV2     LDA   (GBASL),Y
         EOR   COLA,X
         STA   (GBASL),Y
         BIT   PAGE1
         RTS

HPOSN    STA   GBASH      ;First part of this
         AND   #%11000000 ; copies ROM
         STA   GBASL
         LSR
         LSR
         ORA   GBASL
         STA   GBASL
         LDA   GBASH
         ASL
         ASL
         ASL
         ROL   GBASH
         ASL
         ROL   GBASH
         ASL
         ROR   GBASL
         LDA   GBASH
         AND   #$1F
         ORA   #$20       ;Always at $2000-
         STA   GBASH
         LDA   X0
         LDY   #-1
         SEC
:HP1     INY              ;Quotient
         SBC   #7
         BCS   :HP1
         ADC   #7         ;Departs here from ROM
         TAX
         TYA
         ASL
         CPX   #4
         ADC   #0
         STA   HNDX
         STA   HSAV       ;Save for next line
         STX   REMR       ; "
         RTS

HCOLOR   STX   XSAV1      ;Must preserve X
         PHA
         LDX   #6         ;Set color table according
:CLUP    LDY   INDX,X     ; to accumulator (<$10)
         STA   COLA,Y
         ASL
         DEX
         BPL   :CLUP
         PLA
         LSR
         STA   COLM+5
         LSR
         STA   COLA+3
         LSR
         STA   COLM+1
         LDX   XSAV1
         RTS

INDX     DFB   5,9,1,12,4,8,0

COLA     DFB   %00001111
         DFB   %01110000
         DFB   %00000000
         DFB   %00000011
         DFB   %00111100
         DFB   %01000000
                          ;Last byte = first of:
COLM     DFB   %00000000
         DFB   %00000001
         DFB   %00011110
         DFB   %01100000
         DFB   %00000000
         DFB   %00000111
         DFB   %01111000

MASKA    DFB   %11110000
         DFB   %10001111
         DFB   %11111111
         DFB   %11111100
         DFB   %11000011
         DFB   %10111111
                          ;Last byte = first of:
MASKM    DFB   %11111111
         DFB   %11111110
         DFB   %11100001
         DFB   %10011111
         DFB   %11111111
         DFB   %11111000
         DFB   %10000111
