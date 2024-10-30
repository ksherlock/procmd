******************************
*                            *
*       TYPE BASIC CMD       *
*----------------------------*
*  Glen E. Bredon   7/17/85  *
******************************

         DATE

         REL              ;Generate a LNK file

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/TYPE.CMD
         FIN

         EXP   OFF
         TR
         TR    ADR

CHARS    =     $D0        ;Character count
HIFLAG   =     $E1
PRFLAG   =     $EA
PRFLAG2  =     $EB
HIMEM    =     $73
CHRGOT   =     $B7
IN       =     $200
KEY      =     $C000
STROBE   =     $C010
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
         DOS   read
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
CMDEND   ASC   " pathname"8D
AMPEND

DOTYPE   LDA   FBITS
         LSR              ;Found file name?
         BCS   :T1        ;Branch if so
         LDA   #6         ;Path not found error
         HEX   2C
:FMM     LDA   #13        ;FILE MISMATCH
:ERROR   SEC
:MLIERR  RTS

:T1      LDA   #10        ;# of parms for GETINFO
         STA   INFPARMS
         DOS   getinfo
         BCS   :MLIERR
         LDA   FILETYPE
         CMP   #4         ;Text file?
         BNE   :FMM       ;File mismatch if not
         LDA   HIMEM+1    ;Address high of system buffer
         STA   OSYSBUF+1
         DOS   open       ;Open the file
         BCS   :MLIERR
         LDA   OREFNUM    ;Get file's ref #
         STA   RWREFNUM   ; READ,
         STA   CFREFNUM   ; and CLOSE.
         LDX   #0
         STX   HIFLAG
         STX   PRFLAG
         STX   PRFLAG2
         STX   CHARS      ;Init character count
         STX   RWCOUNT+1  ;Set to read 1 byte at a time
         INX
         STX   RWCOUNT
         INX
         STX   RWDATA+1   ;Set data buffer to IN+$80
         LDA   #$80
         STA   RWDATA
         BNE   :TLOOP

:PRINT   JSR   :GETBUF
:TLOOP   READ             ;Read a byte
         BCC   :PRINT
:ERR     BIT   STROBE     ;Clear strobe if error
         CMP   #5         ;End of file?
         SEC              ;Exit with error if not
         BNE   :RET
         LDA   #$C
         JSR   CHROUT
:CLOSE   DOS   close      ;Close file
:RET     RTS

:GETBUF  LDA   IN+$80     ;Get byte read
         AND   #$7F
:ORD     CMP   #$20
         BLT   :ISCNT     ;Don't count if control
         INC   CHARS
:ISCNT   CMP   #$C
         BEQ   :ZC
         CMP   #$D
         BNE   :NOTCR
:ZC      LDX   #0
         STX   CHARS
         BEQ   :JC        ;Always

:DOHEAD  LDA   #$D        ;Do another CR
:NOTCR   CMP   #'C'&$1F
         BNE   :ISI
         ROR   HIFLAG
         RTS

:ISI     CMP   #'I'&$1F
         BNE   :JC
         LDA   CHARS
         ADC   #7         ;Carry is set
         AND   #$F8       ;Tab to nearest mult of 8
         PHA
         SEC
         SBC   CHARS      ;= number of spaces to tab
         TAX
         DEX
         BEQ   :ONESP     ;Branch if only 1
:DOTAB   LDA   #' '
         JSR   CHROUT
         DEX
         BNE   :DOTAB
:ONESP   PLA
         STA   CHARS
         LDA   #' '
:JC      JSR   CHROUT     ;Print it
:CONT    LDA   KEY        ;Key down?
         BPL   :JTLOOP    ;Loop if not
         BIT   STROBE
         CMP   #"C"&$9F
         BNE   :ISSP
         PLA              ;Must pop stack
         PLA
         BCS   :CLOSE

:ISSP    CMP   #" "
         BNE   :JTLOOP    ;Loop if not space
:WAIT    LDA   KEY        ;Wait for another key
         BPL   :WAIT
:JTLOOP  RTS              ;Don't clear strobe yet

CHROUT   AND   #$7F
         CMP   #'L'&$1F
         BEQ   :FLG2
         CMP   #'S'&$1F
         BNE   :CFLG
         LDA   PRFLAG2
         EOR   #$80
         STA   PRFLAG2
         RTS

:FLG2    LDA   PRFLAG
         EOR   #$80
         STA   PRFLAG
         LDA   #'L'&$1F
:CFLG    LSR   HIFLAG
         BIT   PRFLAG
         BMI   RETURN
         BIT   PRFLAG2
         BMI   RETURN
         BIT   HIFLAG
         BVC   :OUT
         ORA   #$80
:OUT     JMP   COUT       ; and print digit

RETURN   RTS
