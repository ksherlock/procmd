********************************
*                              *
*   RENUMBER   BASIC COMMAND   *
*                              *
*    Glen Bredon   12/22/84    *
*                              *
********************************

         DATE

         EXP   OFF
         TR
         REL              ;Generate a LNK file

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/RENUMBER.CMD
         FIN

* ProDOS BASIC interp locations:

STATE    =     $BE42      ;0 if immediate mode
XTRNADDR =     $BE50      ;External command vector
XLEN     =     $BE52      ;Length of cmd -1 put here
XCNUM    =     $BE53      ;Put 0 here for ext cmd
PBITS    =     $BE54      ;Parameters, 0 = none (2 bytes)
XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)
MONRTS   =     $FFCB      ;Has RTS (for & linking)

         AST   50

CHARAC   =     $D
FROM     =     $3C        ;A1L
FLAG     =     $3E
MFLAG    =     $3F
DEST     =     $42        ;A4L
LINNUM   =     $50
INDEX    =     $5E
TXTTAB   =     $67
VARTAB   =     $69
ARYTAB   =     $6B
STREND   =     $6D
FRETOP   =     $6F
MEMTOP   =     $73
PRGEND   =     $AF
HIGHDS   =     $94
HIGHTR   =     $96
LOWTR    =     $9B
FAC      =     $9D
CHRGET   =     $B1
CHRGOT   =     $B7
TXTPTR   =     $B8
IN       =     $200
RDKEY    =     $FD0C
COUT     =     $FDED
BLTU2    =     $D39A
MEMERR   =     $D410
FINDLINE =     $D61A
SYNERR   =     $DEC9
OVERFLOW =     $E8D5

* Our usage:

STARTL   =     $E0        ;S parm value
INCREM   =     $E2        ;I parm value
FIRSTL   =     $E4        ;F parm value, 1st old line #
LASTL    =     $E6        ;L parm value, last "
REPTR    =     $E8
LCOUNT   =     $EA
DIGCNT   =     $EC
YSAV     =     $ED
STKPNT   =     $EE

* Applesoft tokens that take line #s:

del      =     133
goto     =     171
run      =     172
gosub    =     176
list     =     188
then     =     196

         AST   50

COMPR    MAC
         LDA   ]1
         CMP   ]2
         LDA   ]1+1
         SBC   ]2+1
         <<<

INCD     MAC
         INC   ]1
         BNE   NC
         INC   ]1+1
NC       <<<

STADR    MAC
         LDA   #]1
         STA   ]2
         LDA   #>]1
         STA   ]2+1
         <<<

MOV      MAC
         LDA   ]1
         STA   ]2
         <<<

MOVD     MAC
         MOV   ]1;]2
         MOV   ]1+1;]2+1
         <<<

LINK     MAC
         LDY   #0
         LDA   (]1),Y
         TAX
         INY
         LDA   (]1),Y
         STA   ]1+1
         STX   ]1
         <<<

MOVLN    MAC
         LDY   #-1
NY       INY
         LDA   ]1,Y
         STA   ]2,Y
         BNE   NY
         CPY   #4
         BLT   NY
         <<<

SENDM    MAC
         LDY   #]1-AMPNAME
         JSR   SENDMSG
         <<<

         AST   50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   PARSE      ;These two jumps permit RELOC
DOSEXIT  JMP   XRETURN    ; to daisy chain commands
AMPEXIT  JMP   MONRTS     ;This one to daisy chain & cmds
AMPENTRY BNE   AMPEXIT    ;Other & cmds to next routine
         SENDM AMPNAME
         JSR   CHRGOT     ;Reestablish A and status
         BEQ   AMPEXIT    ;Go to next routine (always)

LOWAD    DFB   CMDNAME-1,HNAME-1,MNAME-1

LEN      DFB   8,5,6      ;Check CR for HOLD, MERGE
DPARMS   DA    10,10,0,$FFFF ;Default parameters
DPARMEND

INITIALS ASC   "RHM"
INITEND

SENDIT   JSR   COUT
         INY
SENDMSG  LDA   AMPNAME,Y
         BNE   SENDIT
         RTS

PARSE    LDA   IN
         AND   #%11011111
         LDY   #INITEND-INITIALS-1
:CI      CMP   INITIALS,Y
         BEQ   :GOTIN
         DEY
         BPL   :CI
         INY              ;Force error
:GOTIN   LDA   LOWAD,Y
         STA   :EORN+1
         LDX   LEN,Y
:ISIT    LDA   IN-1,X
         AND   #%11011111
:EORN    EOR   CMDNAME-1,X
         SEC              ;In case mismatch here
         BNE   DOSEXIT
         DEX              ;Carry is set
         BNE   :ISIT
         LDY   STATE
         BNE   DOSEXIT    ;Must be immediate mode
         STX   XCNUM      ;Signal external cmd
         STX   PBITS      ; and no parms
         STX   PBITS+1
         STADR START;XTRNADDR
         DEX
:NX      STX   XLEN
         INX
         LDA   IN,X
         AND   #%01111111
         STA   IN+$80,X
         EOR   #$D
         BNE   :NX
         STA   IN+$80,X
         CLC              ;Tell interpreter we
         RTS              ; accepted command

AMPNAME
CMDNAME  ASC   "RENUMBER"
CMDEND   ASC   " [Start#,Incr#,First#,Last#]"8D
HNAME    ASC   "HOLD"8D
MNAME    ASC   "MERGE"8D00
CONFLCT  HEX   8D
         ASC   "LINE # CONFLICT"8D00
SORTMSG  HEX   8D
         ASC   "SORTING"8D00
BADPRG   HEX   8D
         ASC   "PROGRAM INVALID"8D00
OK       HEX   8D
         ASC   "OK?"8D00

PARAM    ASC   'SIFL'

TOKENS   DFB   del,run,list,gosub,then,goto
TOKEND

START    PLA              ;Pull ProDOS rtn addr
         TAX
         PLA
         TAY
         LDA   #>CONT-1
         PHA
         LDA   #CONT-1
         PHA              ;Set up rtn address so that
         TYA              ;ProDOS will hand it back.
         PHA
         TXA
         PHA
         CLC              ;Tell ProDOS we accept and
         RTS              ; please get out of the way

CONT     TSX
         STX   STKPNT
         LDA   IN
         AND   #%11011111
         CMP   #"H"
         BNE   MERGE
HOLD     JSR   CHKDUP     ;May do premature exit
         JSR   MRG        ;Do merge
         JSR   FINDEND
         BCS   JS
         MOVD  DEST;TXTTAB
JS       JMP   SETPNT

MERGE    CMP   #"M"
         BNE   RENUMBER
         JSR   CHKDUP
MRG      STADR $801;TXTTAB
         BVC   JS         ;If no hold, prog, or nat order
         JMP   SORT

RENUMBER LDY   #DPARMEND-DPARMS-1
:SDP     LDA   DPARMS,Y
         STA   STARTL,Y
         DEY
         BPL   :SDP
         STADR IN+CMDEND-CMDNAME+$7F;TXTPTR
:NXP     JSR   CHRGET
         BEQ   GOTPARMS
         LDX   #3
         INY
         CMP   #','
         BEQ   :NXP
         CPY   #4
         BGE   :JSYN
         AND   #%01011111
:PAR     CMP   PARAM,X
         BEQ   :GOTP
         DEX
         BPL   :PAR
         TYA
         TAX
         DEC   TXTPTR
:GOTP    TXA
         ASL
         TAX
         JSR   GETLIN
         PHA
         LDA   LINNUM
         STA   STARTL,X
         LDA   LINNUM+1
         STA   STARTL+1,X
         PLA              ;Eol?
         BEQ   GOTPARMS
         CMP   #','
         BEQ   :NXP
:JSYN    JMP   SYNERR

BADRNG   SENDM CONFLCT
EXIT     JMP   SETPNT0

GOTPARMS LDA   INCREM     ;Check for I0 error
         ORA   INCREM+1
         BEQ   BADRNG
         LDY   #1
         LDA   (TXTTAB),Y ;Is there a program
         BEQ   EXIT
         JSR   FINDRNG
         LDA   INDEX+1
         BMI   EXIT       ;Branch if no lines in range
         MOVD  LOWTR;HIGHTR
         MOVD  STARTL;LINNUM
         JSR   FINDLINE   ;Start line adrs to HIGHDS
         ROR   FLAG       ;- if start line exists
         MOVD  LOWTR;HIGHDS
         JSR   COMPUTE

* Here STARTL = 1st line # in new range
* LINNUM = last line # in new range
*
* Adrs range of lines to be renumbered: FROM....^HIGHTR
*   (HIGHTR is then next line)
* Adrs of lines corr. to new #s is: HIGHDS...LOWTR (incl)
* FLAG is - if start line of new range exists.
* C is set (by next JSR) if end line of new range exists.

:GOTLAST JSR   FINDLINE   ;End line adrs to LOWTR
         BCS   :LINEFND   ;If line found then must
         BIT   FLAG       ; check it is a renumber line
         BMI   :CHKRNG
         LDA   HIGHDS     ;If neither line found and
         CMP   LOWTR      ; address of next line =
         BNE   :CHKRNG    ; then can do renumber
         LDA   HIGHDS+1
         CMP   LOWTR+1
         BNE   :LINEFND
         JSR   :RNGCHK
:RNGOK   LDA   #3
         ROR   MFLAG
         ADC   PRGEND+1
         CMP   MEMTOP+1
         BLT   :DOREN
         JMP   MEMERR
:LINEFND LDA   LOWTR
         CMP   HIGHTR
         BNE   :CHKRNG
         LDA   LOWTR+1
         CMP   HIGHTR+1
         BEQ   BADRNG
:CHKRNG  JSR   :RNGCHK
         BLT   BADRNG
         BGE   :RNGOK

:RNGCHK  COMPR HIGHTR;LOWTR
         BLT   :RET
         COMPR HIGHDS;FROM
:RET     RTS

*---------------------------
*  Main renumber routine:
*---------------------------

:DOREN
         JSR   RENUMBOD   ;Fix line # refs
         JSR   RENUMLIN   ;Fix line #s
         BIT   MFLAG
         BPL   SORT
         JMP   SETPNT     ;Done if sort not needed
SORT     SENDM SORTMSG
         LDX   TXTTAB
         LDA   TXTTAB+1
         STX   LOWTR      ;Points to line above stuff
         STA   LOWTR+1    ; already selected.
:SLUP    STX   HIGHDS     ;Ptr to find smallest line #
         STA   HIGHDS+1
:NOTMIN  MOVD  HIGHDS;HIGHTR ;Current candidate in HIGHTR
:NXDS    LINK  HIGHDS     ;Look at next line
         BEQ   SETPNT     ;EOP can happen only if all done
         LDA   (HIGHDS),Y
         BEQ   :GOTMIN    ;Branch if none < HIGHTR
         LDY   #3
         LDA   (HIGHTR),Y ;Get current min candidate
         CMP   (HIGHDS),Y ;Compare with all above
         BLT   :NXDS      ;Move ptr if still min
         BNE   :NOTMIN    ;Found new candidate if >
         DEY
         LDA   (HIGHTR),Y ;Same for low bytes
         CMP   (HIGHDS),Y
         BLT   :NXDS
         BGE   :NOTMIN
:GOTMIN  LDA   HIGHTR     ;Found smallest line
         CMP   LOWTR
         BNE   :DOMOVE    ;Move if not already at bottom
         LDA   HIGHTR+1
         CMP   LOWTR+1
         BEQ   :NXLOW     ;Bump bottom ptr if now ok
:DOMOVE  MOVLN (HIGHTR);IN ;Save min line in IN
         TYA
         SEC
         ADC   HIGHTR
         STA   HIGHDS
         LDA   HIGHTR+1
         ADC   #0
         STA   HIGHDS+1
         JSR   BLTU2      ;Make room for it at bottom
         MOVLN IN;(LOWTR) ;Insert in proper place
         JSR   LINKSET0   ;Fix the links
         LDA   #"."
         JSR   COUT
:NXLOW   LINK  LOWTR      ;Keep on trucking
         BNE   :SLUP      ;Always?
                          ;Fall into SETPNT0

SETPNT0  LDX   STKPNT
         TXS
SETPNT   LDX   #2
:LUP     LDA   MEMTOP-1,X
         STA   FRETOP-1,X
         LDA   PRGEND-1,X
         STA   VARTAB-1,X
         STA   ARYTAB-1,X
         STA   STREND-1,X
         DEX
         BNE   :LUP
         LDA   #$8D
         STA   IN
         RTS

*----------------------------------------
* ASCII # at TXTPTR to address in LINNUM:
*----------------------------------------

GETLIN   MOV   TXTPTR;DIGCNT
         LDA   #0         ;This used instead of LINGET
         STA   LINNUM+1   ; to handle big line #s
:DIG     STA   LINNUM
         JSR   CHRGET
         BCS   RET        ;TXTPTR -> next char on exit
         EOR   #'0'       ;Convert ascii digit to hex
         STA   CHARAC     ;Save it
         LDA   LINNUM     ;Will x10 overflow?
         CMP   #$FFFF/10+1
         LDA   LINNUM+1
         STA   INDEX
         SBC   #>$FFFF/10+1
         BGE   OVFLO      ;Error if so
         LDA   LINNUM
         ASL
         ROL   INDEX
         ASL
         ROL   INDEX      ;Current # x 4
         ADC   LINNUM     ; + current = current x 5
         STA   LINNUM
         LDA   LINNUM+1
         ADC   INDEX
         ASL   LINNUM     ; x 2 = current x 10
         ROL
         STA   LINNUM+1
         LDA   LINNUM
         ADC   CHARAC     ; + new digit
         BCC   :DIG       ;Loop if no overflow
         INC   LINNUM+1
         BNE   :DIG
OVFLO    JMP   OVERFLOW

*------------------------------------------
* INDEX times INCREM plus STARTL to LINNUM:
*------------------------------------------

COMPUTE  LDA   #0
         STA   LINNUM
         LDY   #$11
:MLUP    LSR   LINNUM
         ROR
         ROR   INDEX+1
         ROR   INDEX
         BCC   :SKP
         CLC
         ADC   INCREM
         TAX
         LDA   INCREM+1
         ADC   LINNUM
         STA   LINNUM
         TXA
:SKP     DEY
         BNE   :MLUP
         ORA   LINNUM
         BNE   OVFLO
         LDA   INDEX
         ADC   STARTL
         STA   LINNUM
         LDA   INDEX+1
         ADC   STARTL+1
         STA   LINNUM+1
         BCS   OVFLO
RET      RTS

*-------------------------------
* LINNUM to ascii string in FAC:
*-------------------------------

HEXASC   LDX   #0         ;All 5 digits are put in FAC
:LOAD0   LDY   #'0'
         LDA   LINNUM
:MKD     CMP   :NUMLOW,X
         LDA   LINNUM+1
         SBC   :NUMHI,X
         BCC   :GOTDIG
         STA   LINNUM+1
         LDA   LINNUM
         SBC   :NUMLOW,X
         STA   LINNUM
         INY
         BNE   :MKD
:GOTDIG  STY   FAC,X
         INX
         CPX   #5
         BLT   :LOAD0
         LDY   #0         ;Look for 1st nonzero digit
:LEN     LDA   FAC,Y
         CMP   #'0'
         BNE   :RET
         INY
         DEX              ;Dec X if a leading 0
         BNE   :LEN
         INX              ;Correct for line # = 0
:RET     RTS              ;X = #digits on exit

:NUMLOW  DFB   10000,1000,100,10,1
:NUMHI   DFB   >10000,>1000,>100,>10,>1

*------------------------------------
* Routine to find range to renumber.
* Returns FROM  -> 1st line in range.
*         LOWTR -> line after range.
*         INDEX = # lines in range.
*------------------------------------

FINDRNG  MOVD  FIRSTL;LINNUM
         JSR   FINDLINE
         MOVD  LOWTR;FROM
         LDY   #-1
         STY   INDEX
         STY   INDEX+1
         LDY   #1
:FH      LDA   (LOWTR),Y  ;Link high
         BEQ   :RET
         LDY   #3
         LDA   (LOWTR),Y  ;Line # high
         CMP   LASTL+1
         BLT   :OV
         BNE   :RET
         DEY
         LDA   (LOWTR),Y  ;Line # low
         CMP   LASTL
         BLT   :OV
         BNE   :RET
:OV      INCD  INDEX
         LINK  LOWTR
         BNE   :FH        ;Always
:RET     RTS

*----------------------------
* Routine to set link fields:
*----------------------------

LINKSET0 LDX   LOWTR
         LDA   LOWTR+1
         BNE   LY         ;Always
LINKSET  LDA   REPTR+1
         LDX   REPTR
LY       LDY   #1
:NXLNK   STA   INDEX+1
         STX   INDEX
         CPX   PRGEND
         SBC   PRGEND+1
         BGE   :BADPRG
         LDA   (INDEX),Y
         BEQ   :RET
         LDY   #4
:FNDEOL  INY
         BEQ   :BADPRG
         LDA   (INDEX),Y
         BNE   :FNDEOL
         TYA
         SEC
         ADC   INDEX
         TAX
         LDY   #0
         STA   (INDEX),Y
         TYA
         ADC   INDEX+1
         INY
         STA   (INDEX),Y
         BCC   :NXLNK     ;Always
:RET     RTS

:BADPRG  SENDM BADPRG
         JMP   SETPNT0

*-------------------------------------------------------
* Routine to renumber body of program (all but line #s):
*-------------------------------------------------------

RENUMBOD MOVD  TXTTAB;REPTR
:NXLNK   LDY   #3
:FNDTOK  INY
         LDA   (REPTR),Y
         BEQ   :NXLIN
         BPL   :FNDTOK
         LDX   #TOKEND-TOKENS-1
:ISTOK   CMP   TOKENS,X
         BEQ   :DOIT
         DEX
         BPL   :ISTOK
         BMI   :FNDTOK

:NXLIN   LINK  REPTR
         LDA   (REPTR),Y
         BNE   :NXLNK
         RTS

:DOIT    STY   YSAV
         TYA
         CLC
         ADC   REPTR
         STA   TXTPTR     ;-> token
         STA   LOWTR
         LDA   REPTR+1
         ADC   #0
         STA   TXTPTR+1
         STA   LOWTR+1
         INCD  LOWTR      ;-> 1st digit
         JSR   GETLIN     ;Current refnce to LINNUM
         LDA   TXTPTR     ;Now -> char past refnce #
         CLC
         SBC   DIGCNT
         STA   DIGCNT     ;Has length of refnce #
         BEQ   :JNO       ;Can happen for THEN, LIST...
         COMPR LINNUM;FIRSTL
         BLT   :JNO
         COMPR LASTL;LINNUM
         BLT   :JNO       ;Now FIRSTL <= LINNUM <= LASTL
         LDX   #-1
         STX   INDEX
         STX   INDEX+1
         MOVD  FROM;DEST
:LUP     INCD  INDEX
         LDY   #3
         LDA   (DEST),Y   ;Is this the refncd line?
         CMP   LINNUM+1
         BGE   :TSTLO
:LNKD    LINK  DEST
         BNE   :LUP
:JNO     JMP   :NO

:TSTLO   BNE   :USIT      ;Use next line if not found!
         DEY
         LDA   (DEST),Y
         CMP   LINNUM
         BLT   :LNKD
:USIT    JSR   COMPUTE
         JSR   HEXASC     ;Make replacement #
         TXA
         SEC
         SBC   DIGCNT     ;A now = diffnce of lengths
         STX   DIGCNT     ;= length of replacement
         BEQ   :PUTNEW    ;Branch if same length
         BLT   :MOVDWN    ;Branch if new < old
         PHA              ;Old < new here
         CLC
         ADC   PRGEND
         STA   HIGHDS     ;-> end of dest
         TAX
         LDA   PRGEND+1
         STA   HIGHTR+1   ;-> end of curr prog
         ADC   #0
         STA   HIGHDS+1
         STA   PRGEND+1
         MOV   PRGEND;HIGHTR
         STX   PRGEND
         COMPR FROM;LOWTR
         PLA
         BLT   :MOVUP
         CLC
         ADC   FROM
         STA   FROM
         BCC   :MOVUP
         INC   FROM+1
:MOVUP
         JSR   BLTU2      ;Make room
         BEQ   :PUTNEWC   ;Always
:MOVDWN
         EOR   #-1
         TAY
         INY
         STY   CHARAC     ;Has ABS diffnc of lengths
         COMPR FROM;LOWTR
         BLT   :M
         LDA   FROM
         SBC   CHARAC
         STA   FROM
         BCS   :FXP
         DEC   FROM+1
:M       SEC
:FXP     LDA   PRGEND
         SBC   CHARAC
         STA   PRGEND     ;Fix prg end ptr
         BCS   :ND
         DEC   PRGEND+1
:ND      MOVD  LOWTR;HIGHTR ;-> 1st digit
         LDX   #0
:MV      LDA   (HIGHTR),Y ;Move down by diff of len
         STA   (HIGHTR,X)
         INC   HIGHTR
         BNE   :MV        ;Full pages moved
         INC   HIGHTR+1
         COMPR HIGHTR;PRGEND
         BLT   :MV
:PUTNEWC CLC
:PUTNEW  PHP
         LDX   #4         ;-> last digit of new #
         LDY   DIGCNT     ;Length of new #
:PUTN    LDA   FAC,X
         DEX
         DEY
         STA   (LOWTR),Y
         BNE   :PUTN      ;Status of Y!
         PLP
         BCS   :DOT
         JSR   LINKSET    ;Reset links
:DOT     LDA   #"."
         JSR   COUT
:NO      LDY   DIGCNT
         LDA   (LOWTR),Y
         LDY   YSAV
         CMP   #','
         BEQ   :JDOIT
         CMP   #$C9       ;'-' in LIST
         BEQ   :JDOIT
         JMP   :FNDTOK

:JDOIT   TYA
         ADC   DIGCNT     ;Carry is set
         TAY
         JMP   :DOIT      ;Check next refnc

*-------------------------------------------------------
* Routine to renumber just the line #s of changed range:
*-------------------------------------------------------

RENUMLIN JSR   FINDRNG
         LDA   STARTL+1
         STA   LCOUNT+1
         LDA   STARTL
:RN      LDY   #2
         STA   (FROM),Y
         CLC
         ADC   INCREM
         STA   LCOUNT
         INY
         LDA   LCOUNT+1
         STA   (FROM),Y
         ADC   INCREM+1
         STA   LCOUNT+1
         LINK  FROM
         CPX   LOWTR
         SBC   LOWTR+1
         LDA   LCOUNT
         BLT   :RN
         RTS

*-----------------------------------------------------
* Routine to find last line (FROM) & EOProgram (DEST):
*-----------------------------------------------------

FINDEND  MOVD  TXTTAB;DEST
         SEC              ;Signal no program
:L       MOVD  DEST;FROM
         LDY   #0
         LDA   (FROM),Y
         STA   DEST
         INY
         LDA   (FROM),Y
         STA   DEST+1
         BEQ   RTN
         LDA   (DEST),Y
         BNE   :L
         CLC
CLRV     CLV
RTN      RTS

*----------------------------------------------------
* Routine (used with hold file) to check that current
* program and hold program do not intermix.
* Does not return if there is intermix.
* On return: V is clear if no hold file or prog, or
*   already in natural order.
*----------------------------------------------------

CHKDUP   LDY   #1         ;Is there a program?
         LDA   (TXTTAB),Y
         BEQ   CLRV       ;Exit if not
         LDA   #8
         CPY   TXTTAB     ;Is there a hold file?
         BNE   :ONH
         CMP   TXTTAB+1
         BEQ   CLRV       ;Return if not
:ONH     STY   FROM       ;Point to hold file
:ATE     DEY              ;=0
         STA   FROM+1     ;Find end line of hold file
         LDA   (FROM),Y
         CMP   TXTTAB
         BNE   :NXF
         INY
         LDA   (FROM),Y
         CMP   TXTTAB+1
         BEQ   :CL        ;Got it
         DEY
:NXF     LDA   (FROM),Y
         TAX
         INY
         LDA   (FROM),Y
         STX   FROM
         BNE   :ATE
:CL      INY
         LDA   (FROM),Y   ;Get last line in hold
         CMP   (TXTTAB),Y ;Compare 1st line in current
         INY
         LDA   (FROM),Y
         SBC   (TXTTAB),Y
         BLT   CLRV       ;Ok if in natural order
         JSR   FINDEND    ;Find last line of current
         BCS   CLRV       ;Branch if no program
         INY
         LDA   (FROM),Y   ;Compare last line # of current
         CMP   $803       ;With 1st on hold
         INY
         LDA   (FROM),Y
         SBC   $804
:BR      BIT   RTN        ;Set V flag
         BLT   RTN        ;Ok if all current < hold
         SENDM CONFLCT
         SENDM OK
:KY      JSR   RDKEY
         AND   #%11011111
         CMP   #"N"
         BEQ   :NO
         CMP   #"Y"
         BNE   :KY
         CLC
         BCC   :BR
:NO      JMP   SETPNT0
