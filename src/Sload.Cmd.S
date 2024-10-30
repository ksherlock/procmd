********************************
*                              *
*     SLOAD and SSAVE CMDS     *
*                              *
*   Glen E. Bredon   6/24/85   *
*                              *
********************************

         DATE

         REL              ;Generate a LNK file
         TR
         TR    ADR
         XC
         XC
         EXP   OFF

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"
         DO    SAVOBJ
         DSK   OBJECT/SLOAD.CMD
         FIN

* MLI call codes:

getinfo  =     $C4
open     =     $C8
read     =     $CA
write    =     $CB
close    =     $CC

NEWVIDEO =     $C029

* Applesoft stuff:

GBASL    =     $26
HIMEM    =     $73
CHRGOT   =     $B7
REMSTK   =     $F8
IN       =     $200
COUT     =     $FDED
MONRTS   =     $FFCB      ;Has RTS (for & linking)

* ProDOS BASIC interp location:

XTRNADDR =     $BE50
XLEN     =     $BE52
XCNUM    =     $BE53
PBITS    =     $BE54
FBITS    =     $BE56
GOSYSTEM =     $BE70
XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)
INFPARMS =     $BEB4
FILETYPE =     $BEB8
OSYSBUF  =     $BECE
OREFNUM  =     $BED0
RWREFNUM =     $BED6
RWDATA   =     $BED7
RWCOUNT  =     $BED9
CFREFNUM =     $BEDE

STADR    MAC
         LDA   #]1
         STA   ]2
         LDA   #>]1
         STA   ]2+1
         <<<

DOS      MAC
         LDA   #]1
         JSR   GOSYSTEM
         <<<

* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   PARSE
DOSEXIT  JMP   XRETURN    ;To daisy chain commands
AMPEXIT  JMP   MONRTS     ;This one to daisy chain & cmds
AMPENTRY BNE   AMPEXIT    ;Other & cmds to next routine
         LDY   #0
:LOOP    LDA   CMDNAME,Y
         JSR   COUT
         INY
         CPY   #AMPEND-CMDNAME+1
         BLT   :LOOP
         JSR   CHRGOT
         BEQ   AMPEXIT

         DFB   37         ;ID byte

MODE     BRK              ;SAVE/LOAD flag

CMDNAME  ASC   "SSAVE"
CMDEND   ASC   " or "
LDNAME   ASC   "SLOAD pathname"
AMPEND   HEX   8D

PARSE    LDY   #LDNAME-1
         LDA   IN+1
         AND   #%11011111
         EOR   #"L"
         STA   MODE
         BEQ   :ISL
         LDY   #CMDNAME-1
:ISL     STY   EO+1
         LDX   #CMDEND-CMDNAME-1
         STX   XLEN
         INX
ISIT     LDA   IN-1,X
         AND   #%11011111
EO       EOR   CMDNAME-1,X
         SEC
         BNE   DOSEXIT
         DEX
         BNE   ISIT
         STX   XCNUM
         INX
         STX   PBITS
         LDA   #%00000100 ;Allow S,D parms
         STA   PBITS+1
         STADR DOSL;XTRNADDR
         CLC
         RTS

DOSL     LDA   FBITS      ;File name given?
         LSR
         BCS   :GF
         LDA   #6         ;Syntax error if not
         SEC
         RTS

:GF      TSX
         STX   REMSTK
         LDA   NEWVIDEO
         STA   STATE
         CLC
         XCE
         REP   %00110000
         LDA   #$2000
         STA   GBASL
         STA   RWCOUNT
         STA   RWDATA
         XCE
         LDA   #10
         STA   INFPARMS
         DOS   getinfo
         BCS   MLIERR
         LDA   FILETYPE
         CMP   #$C1
         BEQ   :ST
         LDA   #13
         SEC
         BCS   MLIERR
:ST      LDA   HIMEM+1
         STA   OSYSBUF+1  ;Set up buffer
         DOS   open
         BCS   MLIERR
         LDA   OREFNUM
         STA   RWREFNUM   ;Set R/W ref
         STA   CFREFNUM   ; close ref
         LDA   NEWVIDEO
         AND   #1
         ORA   #%11000000
         STA   NEWVIDEO
BINLS    LDA   MODE
         BEQ   ISLOAD
MORES    CLC
         XCE
         REP   %00110000
         LDY   #$2000
         TYA
         DEC
         LDX   GBASL
         CPX   #$A000
         BGE   EXIT
         MVN   $E12000,0
         STX   GBASL
         SEC
         XCE
         LDA   #write
         JSR   GOSYSTEM   ;R/W aux screen
         BCS   MLIERR
         BRA   MORES

MLIERR   LDX   REMSTK
         TXS
         PHP
         PHA
         JSR   CLOSE
         LDA   #%11111110
         TRB   NEWVIDEO
         PLA
         PLP
         RTS

MORER    SEC
         XCE
ISLOAD   LDA   #read
         JSR   GOSYSTEM   ;R/W aux screen
         BCS   MLIERR
         XCE
         REP   %00110000
         LDX   #$2000
         TXA
         DEC
         LDY   GBASL
         MVN   0,$E12000
         PHK
         PLB
         STY   GBASL
         CPY   #$A000
         BLT   MORER
EXIT     XCE
         LDX   REMSTK
         TXS
CLOSE    DOS   close
         PHA              ;Replace machine state
         LDA   STATE
         STA   NEWVIDEO
         PLA
         RTS

STATE    DFB   1
