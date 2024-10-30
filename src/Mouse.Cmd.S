********************************
*                              *
*   MOUSE (HIRES CONTROLLER)   *
*                              *
*   Glen E. Bredon   6/13/85   *
*                              *
********************************

         DATE

         REL              ;Generate a LNK file
         TR
         EXP   OFF

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/MOUSE.CMD
         FIN

* Tokens:

end      =     128
store    =     168
let      =     170
wait     =     181
at       =     197
int      =     211
pos      =     217

* Switches:

STORE80  =     $C001
VBL      =     $C019
PAGE1    =     $C054
PAGE2    =     $C055

* Applesoft stuff:

VALTYP   =     $11
INTFLG   =     $12
TEMP     =     $1E
GBASL    =     $26
GBASH    =     $27
MEMTOP   =     $73
VARPNT   =     $83
CHRGET   =     $B1
CHRGOT   =     $B7
X0       =     $E0
REMR     =     $E1
Y0       =     $E2
HSAV     =     $E3        ;Save for HNDX (for next line)
HNDX     =     $E5
PIXCNT   =     $FA        ;Horizontal pixel count
VERT     =     $FB        ;Vertical size of char
LOGNUM   =     $FC
FONTPNT  =     $FD        ;Font table pointer (local)
XSAV     =     $FF
MOUSE    =     $C400      ;Address corrected
FRMNUM   =     $DD67
FRMEVL   =     $DD7B
CHKCOM   =     $DEBE
SYNCHR   =     $DEC0
SYNERR   =     $DEC9
PTRGET   =     $DFE3
IQERR    =     $E199
SNGFLT   =     $E301
ASC      =     $E6E5
GETBYTC  =     $E6F5
CONINT   =     $E6FB
GETADR   =     $E752
MOVMF    =     $EB2B
ROMHFNS  =     $F6B9
IDBYTE   =     $FBB3
IDBYTE2  =     $FBC0
MONRTS   =     $FFCB      ;Has RTS (for & linking)

* ProDOS BASIC interp location:

INTPATCH =     $BDDA      ;Patch address
XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)
MLI      =     $BF00

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
AMPENTRY CMP   #pos
         BEQ   POS
         CMP   #let
         BEQ   LET
         CMP   #store
         BNE   ISINIT
         BEQ   STORE

BASV     DS    2          ;Save for GBAS
ISC      BRK              ;0 if //c
MCOUNT   DFB   4          ;Count for //c intpts

FONTADR  DA    $4000      ;To be set up

         DFB   25         ;Signature

* Machine language entry points:

         JMP   INIT1      ;Standard init
         JMP   INIT       ;Set font adrs A=hi, Y=lo
         JMP   LETCHR     ;X=log #, A=chr
         JMP   ERASE      ;X=log # (remove chr)
         STX   LOGNUM     ;X=log #
         JMP   STORIT     ; put chr on screen

LET      JSR   BYTLOG     ;Get logical obj #
         JSR   CHKCOM
         JSR   FRMEVL     ;Chr to assign to it
         JSR   ASC        ;VAL of chr in FAC
         LDX   LOGNUM
         LDA   CHRS,X     ;Is it assigned
         BMI   :GETCHR    ;Branch if not
         PHP
         SEI              ;This should not be needed
         JSR   PRTEXI     ;Erase char if there
         PLP
:GETCHR  JSR   CONINT     ;Chr to X
         TXA
         LDX   LOGNUM
LETCHR   STA   CHRS,X     ;Put chr in table
         RTS

POS      JSR   BYTLOG     ;Get logical #
         JSR   GETPNT     ;Get ptr to X
         LDX   LOGNUM
         PHP
         SEI              ;Don't allow to change
         LDY   XCOOR,X
         JSR   :FLT       ;Float X coor
         JSR   GETPNT     ;Get ptr to Y
         LDX   LOGNUM
         LDY   YCOOR,X
         JSR   :FLT
         JSR   GETPNT     ;Get ptr to S
         LDX   LREG+1     ;Get offset to status
         LDA   $778-$C0,X
         AND   #%11100000
         TAY              ;Status to third var
         PLP              ;Now its ok
:FLT     JSR   SNGFLT     ;Float Y coor
         LDX   VARPNT
         LDY   VARPNT+1
         JMP   MOVMF      ;Put value in var

ISINIT   CMP   #int
         BEQ   MOUSON     ;Do mouse init
         CMP   #wait
         BEQ   WAIT
         CMP   #end
         BEQ   END
         JSR   CHRGOT     ;Retrieve entry status
         JMP   AMPEXIT    ; and reject command

STORE    JSR   BYTLOG     ;Get logical # in X
         BNE   ISADR      ;Branch if AT X,Y given
         LDA   CHRS,X     ;Is it assigned
         BMI   JIQ        ;Error if not
ERASE    STX   LOGNUM
         PHP
         SEI
         LDA   XCOOR,X    ;Is it on screen?
         CMP   #$FF
         BEQ   CLIN       ;Ignore if not
         STA   X0
         LDA   YCOOR,X
         STA   Y0
         LDA   #$FF       ;To remove from screen
         TAY
         BNE   SETCOOR1   ;Always

ISADR    LDA   CHRS,X
         BMI   JIQ        ;Error if not assigned
         LDA   #at
         JSR   SYNCHR
         JSR   ROMHFNS
         TYA              ;Divide X coor by 2
         LSR
         TXA
         ROR
         LDY   $9D
STORIT   STA   X0
         STY   Y0
         PHP
         SEI
SETCOOR1 JSR   COORPRT    ;Set new coor in A,Y and
CLIN     PLP              ; draw at old ones X0,Y0
         RTS

WAIT     SEI
         JSR   GETBYTC
         BNE   SYN
         DEX
         BEQ   RET
         CLI
RET      RTS

END      JMP   MOUSOFF

BYTLOG   JSR   GETBYTC    ;Get log #
         PHP              ;Z set if eol
         TXA
         BMI   JIQ        ;Error if > 127
         PLP              ;Recall if eol
         STX   LOGNUM
         RTS

GETPNT   JSR   CHKCOM
         JSR   PTRGET
         LDA   VALTYP     ;Demand a real var
         ORA   INTFLG
         BEQ   RET        ;Branch if it is
SYN      CLI
         JMP   SYNERR

JIQ      CLI
         JMP   IQERR

MOUSON   JSR   CHRGET
         BEQ   INIT1      ;Branch if no font adrs
         JSR   FRMNUM     ;Get new font address
         JSR   GETADR
INIT     STY   FONTADR    ;Keep it
         STA   FONTADR+1
INIT1    LDA   IDBYTE     ;Make sure machine
         EOR   #6         ; is supported
         BNE   :JSYN
         LDA   IDBYTE2
         STA   ISC        ;Remember if //c
         AND   #%00011111
         BNE   :JSYN      ;Error if not supported
         SEI
         LDX   #7         ;Look for mouse, starting
         STA   TEMP       ; with slot 7
         LDA   #$C7
         STA   TEMP+1
:LP      LDY   #$C
         LDA   (TEMP),Y   ;Mouse id #1
         CMP   #$20
         BNE   :NO
         LDY   #$FB
         LDA   (TEMP),Y   ;Mouse id #2
         CMP   #$D6
         BEQ   :FOUND     ;Found the mouse
:NO      DEC   TEMP+1
         DEX
         BNE   :LP        ;Loop through all cards >0
         CLI
:JSYN    JMP   SYNERR
:FOUND   LDA   AIPARMS+1
         BNE   :SA        ;Branch if already allocated
         JSR   MLI
         DFB   $40        ;Allocate interrupt
         DA    AIPARMS
:SA      LDY   #PATCHEND-INTPATCH
:MP      LDA   PATCH,Y    ;Set handler front end
         STA   INTPATCH,Y
         DEY
         BPL   :MP
         TYA
         LDY   #$7F
]LOOP    STA   XCOOR,Y    ;Init all coors & chrs
         STA   YCOOR,Y
         STA   CHRS,Y
         DEY
         BPL   ]LOOP
         LDA   TEMP+1     ;Holds slot of mouse
         STA   JIM+2      ; in form CN
         STA   JMOUSE+2
         STA   ABORT+2
         STA   GOM+2
         STA   LREG+1
         ASL
         ASL
         ASL
         ASL
         STA   LREG+3     ;N0
         LDY   #$12
         LDA   (TEMP),Y
         STA   JMOUSE+1   ;Point to SETMOUSE
         INY
         LDA   (TEMP),Y
         STA   ABORT+1    ;Point to SERVEMOUSE
         LDA   AIPARMS+1
         STA   DIPARMS+1  ;Set parms for dealloc
         LDY   #$19       ; in case of problems
         JSR   GOM        ;INITMOUSE
         LDY   #$12
         JSR   GOM        ;SETMOUSE
         CLI
         RTS

MOUSOFF  LDA   AIPARMS+1  ;Connected?
         BEQ   :BAK       ;Ignore if not
         SEI
         LDA   #0
         STA   AIPARMS+1  ;Allow reconnect
         JSR   ABORT
         CLI
:BAK     JMP   CHRGET

GOM      LDA   MOUSE,Y    ;Get offset to routine (Y)
         STA   JIM+1      ;Set jump address
         LDX   LREG+1     ;Get CN
         LDY   LREG+3     ; and N0
         LDA   #%0111     ;Button & movmnt ints
JIM      JMP   $FFCB      ;Address changed

AIPARMS  DFB   2
         BRK
         DA    INTPATCH

PATCH    ORG   INTPATCH
         CLD              ;Well, they say to do it
         LDA   AIPARMS
         CMP   #2         ;Check some things ok
         BNE   ABORT      ;Scram if not
         ADC   MEMTOP+1   ;Were buffers deallocated?
         CMP   #>DOSENTRY
         BGE   ABORT      ;Gadzooks
         JMP   INTUPT     ;Looks ok, go handle it
ABORT    JSR   MOUSE      ;Changed to SERVEMOUSE
         LDA   #0         ;Command turn off
LREG     LDX   #>MOUSE
         LDY   #>MOUSE*16
JMOUSE   JSR   MOUSE      ;Kill the mouse
         JSR   MLI        ;Deallocate ourselves
         DFB   $41
         DA    DIPARMS
         RTS

DIPARMS  DFB   1
PATCHEND BRK

         ERR   *-$BE00

         ORG

PRTEXI   LDA   XCOOR,X
         CMP   #$FF
         BEQ   BACK       ;Ignore if not on screen
         STA   X0
         LDA   YCOOR,X
         STA   Y0
         BCC   PRCHR      ;Always
NOTFND   LDA   #$FF       ;If chr not in font then
         STA   CHRS,X     ; wipe out our data for it
         STA   XCOOR,X
         STA   YCOOR,X
BACK     RTS
COORPRT  LDX   LOGNUM
         STA   XCOOR,X    ;Set up pos of chr X
         TYA
         STA   YCOOR,X
PRCHR    STA   STORE80    ;Make sure in double hires
         MOVD  FONTADR;FONTPNT
:FIND    LDY   #0
         LDA   (FONTPNT),Y ;Find font for char
         BEQ   NOTFND     ;Branch if not found
         CMP   CHRS,X
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
         LDA   ISC        ;Must avoid VBL check for //c
         BEQ   LOOP       ; as it would hang up
:WT0     BIT   VBL        ;Wait for leading edge
         BPL   :WT0       ; of VBL
:WT      BIT   VBL
         BMI   :WT
LOOP     LDA   PIXCNT
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
         CLC
         LDA   GBASH      ;Copy of the down routine
         ADC   #4
EQ4      =     *-1
         BIT   EQ1C
         BNE   :OV
         ASL   GBASL
         BCC   :D1
         ADC   #$E0
         CLC
         BIT   EQ4
         BEQ   :D2
         LDA   GBASL
         ADC   #$50
         EOR   #$F0
         BEQ   :D3
         EOR   #$F0
:D3      STA   GBASL
         LDA   #$20
         BCC   :D2
:D1      ADC   #$E0
:D2      ROR   GBASL
:OV      STA   GBASH
         LDX   REMR       ;Replace X for left dot
         LDA   HSAV       ; and HNDX
         STA   HNDX
         DEC   VERT
         BNE   LOOP       ;Loop till done
         CLC              ;Final exit, signal
         RTS              ; plot was done.

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
         LDA   (GBASL),Y
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

HCOLOR   STX   XSAV       ;Must preserve X
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
         LDX   XSAV
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



*----------------------
* Interrupt routine:
*----------------------


INTUPT   LDY   #$13       ;Point to SERVEMOUSE
         JSR   GOM        ;Do it
         LDA   ISC
         BNE   :SERVE     ;Branch if //e
         LDA   $C063      ;Check button on //c
         BPL   :DC        ;Branch if pressed
         LDA   LATCH
         BNE   :SERVE     ;Handle if letting obj go
:DC      DEC   COUNT
         BEQ   :DOIT      ;Handle only 1/4 of calls
         CLC              ;Say we accept it
         RTS

:DOIT    LDA   MCOUNT     ;Set next countdown
         STA   COUNT
:SERVE   LDX   #5
:SVZ     LDA   $E0,X      ;Save some zp
         STA   ZPSAV,X
         DEX
         BPL   :SVZ
         MOVD  GBASL;BASV
         MOVD  TEMP;TEMPSV
         LDY   #$14
         JSR   GOM        ;Do READMOUSE
         LDX   LREG+1     ;Get CN
         LDA   #%10000000 ;Button down?
         AND   $778-$C0,X
         BEQ   :MOVCUR    ;Just move cursor if not
         LDX   LATCH      ;Anything latched?
         BEQ   :GETCHR    ;Branch if not
:SLN     STX   LOGNUM     ;Xdraw it
         JSR   PRTEXI
         BCS   INTDONE    ;Exit if cant find
         JSR   GETCOOR
         LDA   X0
         JSR   COORPRT    ;Draw it at new coor
         LDX   LOGNUM
         BEQ   INTDONE    ;Done if it is cursor
         LDX   #0         ;Else point to cursor
         BEQ   :SLN       ; and move it too

:GETCHR  JSR   GETCOOR
         LDX   #$7F
:GL      LDA   X0         ;Check if near an object
         SEC
         SBC   XCOOR,X
         CMP   #5
         BGE   :NXT
         LDA   Y0
         SEC
         SBC   YCOOR,X
         CMP   #8
         BLT   :GOTCHR    ;Branch if on one
:NXT     DEX
         BNE   :GL        ;X=0 if not on a chr
:GOTCHR  TXA
:MOVCUR  STA   LATCH      ;Latch chr (or unlatch)
         TAX
         JMP   :SLN       ;Go to draw routine

INTDONE  MOVD  BASV;GBASL ;Replace zp used
         MOVD  TEMPSV;TEMP
         LDX   #5
:RZ      LDA   ZPSAV,X
         STA   $E0,X
         DEX
         BPL   :RZ
         CLC              ;Tell ProDOS we accept
         RTS

GETCOOR  LDX   LREG+1
         LDA   $478-$C0,X ;X low
         STA   X0
         LDA   $578-$C0,X ;X high
         LSR
         ROR   X0
         LDY   ISC        ;Compensate for wider
         BEQ   :1         ; range on //c
         LSR
         ROR   X0
:1       LDA   X0
         CMP   #140
         BLT   :YLOC
         LDA   #139
         STA   X0
:YLOC    LDA   $4F8-$C0,X ;Y low
         STA   Y0
         LDA   $5F8-$C0,X ;Y high
         CPY   #0
         BEQ   :2         ;Branch if //c
         LSR
         ROR   Y0
:2       LSR
         BCS   :MAX
         LDY   Y0
         CPY   #192
         BLT   :RET
:MAX     LDY   #191
         STY   Y0
:RET     RTS

LATCH    BRK              ;Logical object latched

CHRS     DS    $80,$FF    ;Characters indexed by log #

XCOOR    DS    $80,$FF    ;X-coor indexed by log #

YCOOR    DS    $80,$FF    ;Y-coor indexed by log #

ZPSAV    DS    6          ;Save for zp $FA-$FF
COUNT    DFB   4          ;Countdown for //c intps
EQ1C     DFB   $1C        ;For bit test
TEMPSV   DS    2          ;Save for TEMP, TEMP+1
