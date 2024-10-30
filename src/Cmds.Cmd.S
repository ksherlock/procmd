******************************
*                            *
*       CMDS BASIC CMD       *
*----------------------------*
*  Glen E. Bredon   1/15/87  *
******************************

         DATE

         REL              ;Generate a LNK file

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/CMDS.CMD
         FIN

         EXP   OFF
         TR
         TR    ADR

PROMPT   =     $33
STREND   =     $6D
FRETOP   =     $6F
HIMEM    =     $73
CHRGOT   =     $B7
PATHPNT  =     $D0        ;Safe HGR scratch
LEN      =     $D2        ; locations
IN       =     $200
BASWRDS  =     $D0D0
COUT     =     $FDED

* ProDOS MLI call codes:

getinfo  =     $C4
open     =     $C8
read     =     $CA
close    =     $CC
geteof   =     $D1

* ProDOS BASIC interp locations:

XTRNCMD  =     $BE06
XTRNADDR =     $BE50      ;External command vector
XLEN     =     $BE52      ;Length of cmd -1 put here
XCNUM    =     $BE53      ;Put 0 here for ext cmd
PBITS    =     $BE54      ;Parameters
FBITS    =     $BE56      ;Parameter bits found
VPATH1   =     $BE6C      ;Pointer to pathname
XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)
MONRTS   =     $FFCB      ;Has RTS (for & linking)

MOVD     MAC
         LDA   ]1
         STA   ]2
         LDA   ]1+1
         STA   ]2+1
         <<<

MLI      MAC
         JSR   $BF00
         DFB   ]1
         DA    ]2
         <<<

         AST   50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   PARSE      ;These two jumps permit RELOC
DOSEXIT  JMP   XRETURN    ; to daisy chain commands
AMPEXIT  JMP   MONRTS     ;This one to daisy chain & cmds
AMPENTRY BNE   AMPEXIT    ;Other & cmds to next routine
         LDY   #0
:SN      LDA   CMDNAME,Y  ;Show our "list" of dos cmds
         BEQ   :PNTD
         JSR   COUT       ;If all modules have this
         INY              ; routine then &<RTN> will
         BNE   :SN        ; give list of all dos cmds.
:PNTD    JSR   CHRGOT     ;Reestablish A and status
         BEQ   AMPEXIT    ;Go to next routine (always)

         DFB   28         ;Signature

PARSE    LDX   #CMDEND-CMDNAME-1
         STX   XLEN
         INX
:ISIT    LDA   IN-1,X
         AND   #%11011111
         EOR   CMDNAME-1,X
         BNE   GETIT
         DEX
         BNE   :ISIT
         LDA   #DOCMDS
ACCEPT   LDX   #>DOCMDS
         STA   XTRNADDR
         STX   XTRNADDR+1
         LDX   #1
         STX   PBITS      ;File name expected
         DEX
         STX   PBITS+1
         STX   XCNUM
         CLC              ;Say we accept the cmd
         RTS

DOCMDS   LDA   FBITS
         LSR              ;Found file name?
         BCS   T1         ;Branch if so
PNF      LDA   #6         ;Path not found error
         SEC
         RTS

OOMEM    LDA   #14
         SEC
         RTS

T1       MOVD  VPATH1;PATHPNT
         LDY   #0
         LDA   (PATHPNT),Y
         BEQ   PNF
         CMP   #DIRLEN-CMDDIR-2
         BGE   PNF
         STA   LEN
:SETP    INY
         LDA   (PATHPNT),Y
         ORA   #$80
:STIT    CPY   LEN
         STA   CMDDIR-1,Y
         BLT   :SETP
         EOR   #"/"
         BEQ   :CC
         LDA   #"/"
         INY
         BNE   :STIT
:CC      STA   CMDDIR+1,Y
         LDA   #$8D
         STA   CMDDIR,Y
         STY   DIRLEN
         CLC
         RTS

NO       PLP
:BM      BMI   HAVNXT
         INY
         LDA   (PATHPNT),Y
         BNE   :BM
ON       LDA   STREND+1
         CMP   #>$3800
         BGE   :ERR
         LDA   #>$5800
         CMP   FRETOP+1
         BLT   MEMOK
:ERR     LDA   #OOMEM
         BNE   ACCEPT

GETIT    LDA   PROMPT
         CMP   #"*"
         BEQ   BJDOS
         LDX   #-1
         LDA   HIMEM+1
         STA   MLIBUF+1
         LDY   #BASWRDS
         STY   PATHPNT+1
         DEY
         STY   PATHPNT
:PARSE   INX
         CPX   #$10
         BGE   BJDOS
         LDA   IN,X
         AND   #%11011111
         SBC   #"A"-1
         CMP   #"Z"-"A"+1
         BLT   :PARSE
         TXA
         BEQ   BJDOS
         STA   LEN
         LDY   #0
HAVNXT   INY
:NXT2    CLC
         TYA
         LDY   #0
         ADC   PATHPNT
         STA   PATHPNT
         BCC   :NXT
         INC   PATHPNT+1
:NXT     LDA   (PATHPNT),Y
         BEQ   ON
         PHP
         EOR   IN,Y
         AND   #%01011111
         BNE   NO
         INY
         PLP
         BPL   :NXT
         CPY   LEN
         BNE   :NXT2
BJDOS    BGE   JDOS

MEMOK    TXA
         CLC
         ADC   DIRLEN
         STA   IN+$80
         LDX   DIRLEN
         TXA
         TAY
:MVDIR   LDA   CMDDIR-1,X
         STA   IN+$80,X
         DEX
         BNE   :MVDIR
:IY      INY
         LDA   IN,X
         STA   IN+$80,Y
         CPY   IN+$80
         INX
         BLT   :IY
         LDY   #$1F
:MVCMD   LDA   IN,Y
         STA   IN+$E0,Y
         DEY
         BPL   :MVCMD
         MLI   getinfo;INFPARMS
         BCS   MLIERR
         LDA   INFTYPE
         CMP   #6         ;BIN
         BEQ   OK
         CMP   #$F0
         BEQ   OK
MLIERR   MLI   close;CLSPARMS
HERE     JSR   CMDBAK
JDOS     SEC
         JMP   DOSEXIT

OK       MLI   open;OPARMS
         BCS   MLIERR
         LDA   OREF
         STA   EOFREF
         STA   RWREF
         MLI   geteof;EOFPARMS
         ORA   EOF+2
         BNE   MLIERR
         LDA   EOF+1
         CMP   #$10
         BGE   MLIERR
         STA   RWCOUNT+1
         LDA   EOF
         STA   RWCOUNT
         MLI   read;RWPARMS
         BCS   MLIERR
         MLI   close;CLSPARMS
         BCS   MLIERR
         LDA   $411D      ;Signature
         CMP   LASTSIG
         BEQ   HERE
         STA   LASTSIG
         LDA   HIMEM+1
         PHA
         JSR   $4000
         PLA
         CMP   HIMEM+1
         BEQ   HERE
         JSR   CMDBAK
         JMP   XTRNCMD

CMDBAK   LDY   #$1F
:CMDBAK  LDA   IN+$E0,Y
         STA   IN,Y
         DEY
         BPL   :CMDBAK
         RTS

INFPARMS DFB   10
         DA    IN+$80
         DFB   0
INFTYPE  DFB   0
         DA    0
         DFB   0
         DA    0
         DA    0,0
         DA    0,0

OPARMS   DFB   3
         DA    IN+$80
MLIBUF   DA    0
OREF     DFB   0

CLSPARMS DFB   1
         DFB   0

EOFPARMS DFB   2
EOFREF   DFB   0
EOF      DFB   0,0,0

RWPARMS  DFB   4
RWREF    DFB   0
         DA    $4000
RWCOUNT  DA    0
         DA    0

         DS    1          ;filler to keep adrs of:

CMDNAME  ASC   "CMDS"
CMDEND   ASC   " "
CMDDIR   ASC   "/PROCMD/COMMANDS/"8D
ZERO     DS    $2A-*+CMDDIR
DIRLEN   DFB   ZERO-CMDDIR-1

LASTSIG  DFB   28         ;Start with our sign

         ERR   *-$8200
