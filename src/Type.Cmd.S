******************************
*                            *
*       TYPE BASIC CMD       *
*----------------------------*
*  Glen E. Bredon   7/17/85  *
******************************

         DATE

         REL              ;Generate a LNK file

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"
COMPACT  KBD   "Make compacting vers (0=no, 1=yes)?"

         DO    SAVOBJ
         DO    COMPACT
         DSK   OBJECT/TYPE.C.CMD
         ELSE
         DSK   OBJECT/TYPE.CMD
         FIN
         FIN

         EXP   OFF
         TR
         TR    ADR

CHARS    =     $D0        ;Character count
LINES    =     $D1        ;Line/page countdown
FLAG     =     $D2        ;For leading 0 suppression
FORMFLAG =     $D3        ;E parm flag
PAGLEFT  =     $D4        ;Tabbing of header
ATCOUNT  =     $D5        ;# lines to skip at CR
LINESPER =     $E0        ;Specified # lines/page
CHRSPER  =     $E1        ;Specified # chars/line
PAGE     =     $E2        ;Page number (2 bytes)
PATHPNT  =     $E4        ;Pointer to pathname
OURSTK   =     $E6
TEMP     =     $E7
BPNT     =     $E8
CSWH     =     $37
HIMEM    =     $73
CHRGOT   =     $B7
IN       =     $200
KEY      =     $C000
STROBE   =     $C010
CROUT    =     $FD8E
COUT     =     $FDED

* ProDOS MLI call codes:

getinfo  =     $C4
open     =     $C8
read     =     $CA
close    =     $CC

* ProDOS BASIC interp locations:

XTRNADDR =     $BE50      ;External command vector
XLEN     =     $BE52      ;Length of cmd -1 put here
XCNUM    =     $BE53      ;Put 0 here for ext cmd
PBITS    =     $BE54      ;Parameters
FBITS    =     $BE56      ;Parameter bits found
VENDA    =     $BE5D      ;E parameter value
VLNTH    =     $BE5F      ;L parameter value
VLINE    =     $BE68      ;@ parameter value
VPATH1   =     $BE6C      ;Pointer to pathname
GOSYSTEM =     $BE70      ;Call MLI routine
XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)
INFPARMS =     $BEB4      ;GETINFO parm list
FILETYPE =     $BEB8      ;File type put here
OSYSBUF  =     $BECE      ;Buffer ptr for OPEN
OREFNUM  =     $BED0      ;File ref # for OPEN
RWREFNUM =     $BED6      ;Ref # for read/write
RWDATA   =     $BED7      ;Buffer ptr for read/write
RWCOUNT  =     $BED9      ;# of bytes to read/write
CFREFNUM =     $BEDE      ;Ref # for CLOSE
MONRTS   =     $FFCB      ;Has RTS (for & linking)

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

READ     MAC
         DO    COMPACT
         JSR   READBYTE
         ELSE
         DOS   read
         FIN
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
         JSR   COUT       ;If all modules have this
         INY              ; routine then &<RTN> will
         CPY   #AMPEND-CMDNAME
         BLT   :SN        ; give list of all dos cmds.
         JSR   CHRGOT     ;Reestablish A and status
         BEQ   AMPEXIT    ;Go to next routine (always)

         DFB   1          ;Signature

PARSE    LDX   #CMDEND-CMDNAME-1
         STX   XLEN
         INX
         SEC              ;In case we exit here
:ISIT    LDA   IN-1,X
         AND   #%11011111
         EOR   CMDNAME-1,X
         BNE   DOSEXIT    ;Support daisy chain
         DEX
         BNE   :ISIT
         STX   XCNUM      ;Signal external cmd
         INX
         STX   PBITS      ;File name expected
         LDA   #%00111100 ;Allow E,L,@,S,D parameters
         STA   PBITS+1
         STADR DOTYPE;XTRNADDR
         CLC              ;Say we accept the cmd
         RTS

CMDNAME  ASC   "TYPE"
CMDEND   ASC   " pathname [,E ln/pg,L ch/ln,@ skip]"8D
AMPEND

PAGMSG   REV   " - Page "
PAGEND

DOTYPE   LDA   FBITS
         LSR              ;Found file name?
         BCS   :T1        ;Branch if so
         LDA   #6         ;Path not found error
         HEX   2C
:FMM     LDA   #13        ;FILE MISMATCH
:ERROR   SEC
:MLIERR  RTS

:T1      LDA   FBITS+1
         ASL
         ASL              ;E parm found to sign
         STA   FORMFLAG
         BPL   :NOF
         PHA
         LDA   VPATH1
         STA   PATHPNT
         LDA   VPATH1+1
         STA   PATHPNT+1
         LDA   VENDA
         STA   LINES      ;Set for 1st page
         SEC
         SBC   #3
         STA   LINESPER   ; and for succeding pages
         PLA
         ASL
         ASL              ;L para found to carry
         AND   #$80       ;Isolate @ bit
         BEQ   :NOAT      ;Branch if no @ parm
         LDA   VLINE      ;Get specified line skip
:NOAT    STA   ATCOUNT
         LDA   #80
         BCC   :NOL       ;Branch if no L parm
         LDA   VLNTH
:NOL     STA   CHRSPER
         LDY   #0
         SEC
         SBC   #9         ;Adjust for " - Page", etc
         SBC   (PATHPNT),Y
         LSR              ;/2
         STA   PAGLEFT
:NOF     LDA   #10        ;# of parms for GETINFO
         STA   INFPARMS
         DOS   getinfo
         BCS   :MLIERR
         LDA   FILETYPE
         DO    COMPACT
         CMP   #$BF
         ELSE
         CMP   #4         ;Text file?
         FIN
         BNE   :FMM       ;File mismatch if not
         LDA   HIMEM+1    ;Address high of system buffer
         STA   OSYSBUF+1
         DOS   open       ;Open the file
         BCS   :MLIERR
         LDA   OREFNUM    ;Get file's ref #
         STA   RWREFNUM   ; READ,
         STA   CFREFNUM   ; and CLOSE.
         LDX   #0
         STX   BPNT
         STX   CHARS      ;Init character count
         STX   PAGE+1     ; and page count
         STX   RWCOUNT+1  ;Set to read 1 byte at a time
         INX
         STX   PAGE
         STX   RWCOUNT
         INX
         STX   RWDATA+1   ;Set data buffer to IN+$80
         LDA   #$80
         STA   RWDATA
         BNE   :TLOOP

:PRINT   DO    COMPACT
         TSX
         STX   OURSTK
         FIN
         JSR   :GETBUF
:TLOOP   READ             ;Read a byte
         BCC   :PRINT
:ERR     BIT   STROBE     ;Clear strobe if error
         CMP   #5         ;End of file?
         SEC              ;Exit with error if not
         BNE   :RET
:CLOSE   DOS   close      ;Close file
:RET     RTS

:GETBUF  LDA   IN+$80     ;Get byte read
         DO    COMPACT
         BMI   :BF
         STA   IN+$7F
         READ
         BCS   :ERR
         LDA   IN+$7F
         LSR
         LSR
         BEQ   :SP1
         ORA   #%11100000
:SP1     ORA   #%10100000
         JSR   :BF
         LDA   IN+$80
         ASL
         ROL   IN+$7F
         ASL
         ROL   IN+$7F
         ASL
         ROL   IN+$7F
         LDA   IN+$7F
         AND   #%00011111
         BEQ   :SP2
         ORA   #%11100000
:SP2     ORA   #%10100000
         JSR   :BF
         LDA   IN+$80
         AND   #%00011111
         BEQ   :SP3
         ORA   #%11100000
:SP3     ORA   #%10100000
         ELSE
         ORA   #$80
         FIN
:BF      DO    COMPACT
         CMP   #$FE
         BLT   :A0
         PHA
         LDX   BPNT
         BEQ   :R
         LDA   IN+$81
         BCS   :AX        ;Always

:R       READ             ;Will leave BPNT=0
         BCS   :ERR
         LDA   IN+$80
         STA   IN+$81
         INC   BPNT
:AX      TAX
:PL      PLA
         CPX   #" "
         BEQ   :A0
         SEC
         SBC   #$FE-"-"
         PHA
         LDA   #5
         STA   TEMP
]LUP     PLA
         DEC   TEMP
         BEQ   :ORD
         PHA
         JSR   :ORD
         SEC
         BCS   ]LUP

:A0      CMP   #$A0
         BGE   :ORD
         CMP   #$90
         BLT   :ISITCR
         SBC   #$8E
         STA   TEMP
         CMP   #10
         BLT   :CRTAB
         SBC   #8
         STA   TEMP
]LUP     DEC   TEMP
         BEQ   :TAB
         JSR   :TAB
         SEC
         BCS   ]LUP

:ISITCR  CMP   #$8D
         BNE   :ORD
         LDY   #1
         STY   TEMP
:JO      JSR   :ORD
:CRTAB   LDA   #$8D
         DEC   TEMP
         BNE   :JO
:TAB     LDA   #$89
         FIN

:ORD     BIT   FORMFLAG
         BPL   :JC        ;Skip formating if no E parm
         CMP   #$A0
         BLT   :ISCNT     ;Don't count if control
         INC   CHARS
:ISCNT   CMP   #$8C
         BEQ   :DOHEAD
         CMP   #$8D
         BNE   :NOTCR
:ISCR    LDX   ATCOUNT    ;0 if single space
:DOCR    JSR   CROUT      ;Do the CR
         DEC   LINES
         BEQ   :DOHEAD    ;Exit loop if page done
         DEX
         BPL   :DOCR      ;Do line skip
         INX
         STX   CHARS
         BEQ   :CONT      ;Always

:DOHEAD  JSR   HEADER     ;Formfeed and print header
         LDA   LINESPER
         STA   LINES
         LDA   #$8D       ;Do another CR
:NOTCR   CMP   #"I"&$9F
         BNE   :NOTAB
         LDA   CHARS
         ADC   #7         ;Carry is set
         AND   #$F8       ;Tab to nearest mult of 8
         PHA
         SEC
         SBC   CHARS      ;= number of spaces to tab
         TAX
         DEX
         BEQ   :ONESP     ;Branch if only 1
:DOTAB   LDA   #" "
         JSR   COUT
         DEX
         BNE   :DOTAB
:ONESP   PLA
         STA   CHARS
         LDA   #" "
:NOTAB   PHA
         LDA   CHARS
         CMP   CHRSPER
         BLT   :PULL
         JSR   :ISCR      ;Do CR if past line length
:PULL    PLA
:JC      JSR   COUT       ;Print it
:CONT    LDA   KEY        ;Key down?
         BPL   :JTLOOP    ;Loop if not
         BIT   STROBE
         CMP   #"C"&$9F
         BNE   :ISSP
         DO    COMPACT
         LDX   OURSTK
         TXS
         JMP   :CLOSE

         ELSE
         PLA              ;Must pop stack
         PLA
         BCS   :CLOSE
         FIN

:ISSP    CMP   #" "
         BNE   :JTLOOP    ;Loop if not space
:WAIT    LDA   KEY        ;Wait for another key
         BPL   :WAIT
:JTLOOP  RTS              ;Don't clear strobe yet

         DO    COMPACT
READBYTE LDX   BPNT
         BEQ   :READ
         LDA   IN+$80,X
         STA   IN+$80
         DEC   BPNT
         CLC
         RTS

:READ    DOS   read
         RTS
         FIN

HEADER   LDA   CSWH
         EOR   #$C3
         BEQ   :ADD
         LDA   #1
:ADD     EOR   #$8D       ;Do formfeed
         JSR   COUT
         LDY   PAGLEFT
:TAB     LDA   #" "       ;Tab to center
         JSR   COUT
         DEY
         BNE   :TAB
         STY   CHARS
         LDA   (PATHPNT),Y
         TAX              ;# of chars in pathname
:PF      INY
         LDA   (PATHPNT),Y
         ORA   #$80
         JSR   COUT       ;Print pathname
         DEX
         BNE   :PF
         LDY   #PAGEND-PAGMSG
:PP      LDA   PAGMSG-1,Y ;Print " - Page "
         JSR   COUT
         DEY
         BNE   :PP
         SED
         TYA              ;Bump page count
         SEC
         ADC   PAGE
         STA   PAGE
         TAX
         TYA
         ADC   PAGE+1
         STA   PAGE+1
         CLD
         JSR   PRAX       ;Print page count
         JSR   CROUT      ; and end of header line
         JMP   CROUT      ; and extra CR

PRAX     LSR   FLAG       ;Set leading 0 flag
         JSR   PRBYT
         TXA
PRBYT    PHA
         LSR
         LSR
         LSR
         LSR
         JSR   PRNIB
         PLA
         AND   #$F
PRNIB    BNE   :PRIT      ;Print nibble if not zero
         BIT   FLAG       ; or if # started before
         BMI   :PRIT
         RTS              ; else don't

:PRIT    ORA   #"0"
         STA   FLAG       ;Clear leading 0 flag
         JMP   COUT
