********************************
*                              *
*     EDIT   BASIC COMMAND     *
*                              *
*    Glen Bredon   12/25/84    *
*                              *
********************************

         DATE

*----------------------------------------
* Assemble, then use the RELOC utility to
* convert to a relocating CMD file.
*----------------------------------------

         EXP            OFF
         TR
         TR             ADR
         REL                                      ;Generate a LNK file
SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/EDIT.CMD
         FIN

* ProDOS BASIC interp locations:

DOSWRM   =              $3D0
STATE    =              $BE42                     ;0 if immediate mode
XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parms, 0 = none (2 bytes)
XRETURN  =              $BE9E                     ;RTS (for dos cmd linking)
MONRTS   =              $FFCB                     ;RTS (for & linking)

         AST            50

CHARAC   =              $D                        ;Misc use
INVFLG   =              $32
CSWL     =              $36
LINNUM   =              $50
MEMTOP   =              $73
FORPNT   =              $85
LOWTR    =              $9B
FAC      =              $9D
CHRGET   =              $B1
CHRGOT   =              $B7
TXTPTR   =              $B8
STACK    =              $100
IN       =              $200
KEY      =              $C000
STROBE   =              $C010
CROUT    =              $FD8E
COUT     =              $FDED
TOKTBL   =              $D0D0
MEMERR   =              $D410
NXLIN    =              $D45C
FINDLINE =              $D61A
LINGET   =              $DA0C
CHKCOM   =              $DEBE
SYNERR   =              $DEC9
FLO2     =              $EBA0
FOUT     =              $ED34
PRBL2    =              $F94A
BELL     =              $FF3A

* Our usage:

INPTR    =              $D0                       ;Points to IN always
REPTR    =              $D2                       ;Ptr to replacement string
NEWPTR   =              $D4                       ;-> line built w replacement
TOKPNT   =              $D6                       ;TOKTBL ptr, low byte = 0
STARTL   =              $E0                       ;Start of range & cur line
ENDLIN   =              $E2                       ;End of range
TEMP     =              $E4
DELIM    =              TEMP                      ;String delim for parsing
LINPNT   =              $E5                       ;-> line for list to IN
OLDPNT   =              $E6                       ;-> end of replaced string
STKPNT   =              $E7                       ;Stack ptr save
HOOKSV   =              $E8                       ;CSWL save
CURPNT   =              $EA                       ;Cursor pointer
MODE     =              $EB                       ;N=insrt V=find, both=zap
FZCHAR   =              $EC                       ;Find/zap character save
REFLAG   =              $ED                       ;Replace mode flag
STRPNT   =              $EE                       ;-> replace string in line
LEN      =              $EF                       ;Len of orig str for replc
STRSTRT  =              $FE                       ;Pnts to part after line #
AUTOFLG  =              $FF                       ;Minus if AUTO command

* Tokens:

data     =              131
rem      =              178
print    =              186

         AST            50

COMPR    MAC
         LDA            ]1
         CMP            ]2
         LDA            ]1+1
         SBC            ]2+1
         <<<

INCD     MAC
         INC            ]1
         BNE            NC
         INC            ]1+1
NC       <<<

STADR    MAC
         LDA            #]1
         STA            ]2
         LDA            #>]1
         STA            ]2+1
         <<<

MOV      MAC
         LDA            ]1
         STA            ]2
         <<<

MOVD     MAC
         MOV            ]1;]2
         MOV            ]1+1;]2+1
         <<<

MOVX     MAC
         LDX            ]1
         STX            ]2
         LDX            ]1+1
         STX            ]2+1
         <<<

         AST            50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP            PARSE                     ;These two jumps let RELOC
DOSEXIT  JMP            XRETURN                   ; daisy chain commands
AMPEXIT  JMP            MONRTS                    ;This to daisy chain & cmds
AMPENTRY BNE            AMPEXIT                   ;Other & cmds to next rout
         LDY            #0
:SN      LDA            CMDNAME,Y
         JSR            COUT
         INY
         CPY            #AMPEND-CMDNAME
         BLT            :SN
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine

         DFB            12                        ;Signature

KEYVEC   DA             KEYGET                    ;For use by macro module

CMDNAME  ASC            "EDIT"
CMDEND   ASC            ! [start,end]["str"][,"repl"]!8D
AUTNAME  ASC            "AUTO [start,incr]"8D
AMPEND

PARSE    LDX            #CMDEND-CMDNAME
         LDA            IN
         LDY            #CMDNAME-1
         EOR            #"E"
         AND            #%11011111
         BEQ            :SC
         LDY            #AUTNAME-1
:SC      STY            :EC+1
         ROR
         ROR
         ROR
         ROR            AUTOFLG                   ;Minus if auto
         SEC                                      ;In case mismatch here
:ISIT    LDA            IN-1,X
         AND            #%11011111
:EC      EOR            CMDNAME-1,X
         ORA            STATE
         BNE            DOSEXIT
         DEX                                      ;Carry is set
         BNE            :ISIT
         LDY            MEMTOP+1
         INY
         STY            REPTR+1                   ;Set REPTR = MEMTOP+$100
         INY                                      ; (Replacement string)
         STY            NEWPTR+1                  ;NEWPTR = MEMTOP+$200
         STX            REPTR                     ; (Line with replacement)
         STX            NEWPTR
         STX            REFLAG                    ;Flag not replace mode
         STX            INPTR
         STX            XCNUM                     ;Signal external cmd
         STX            PBITS                     ; and no parms
         STX            PBITS+1
         STA            (MEMTOP,X)                ;Signal no string
         STX            TOKPNT                    ;This is "lock" location
         STADR          START;XTRNADDR
         DEX
:NX      STX            XLEN
         INX
         LDA            IN,X
         AND            #$7F
         STA            IN+$80,X
         EOR            #$D
         BNE            :NX
         STA            IN+$80,X
         CLC                                      ;Tell interpreter we
         RTS                                      ; accepted command

START    PLA                                      ;Pull ProDOS rtn addr
         TAX
         PLA
         TAY
         LDA            #>CONT-1
         PHA
         LDA            #CONT-1
         PHA                                      ;Set up rtn address so that
         TYA                                      ;ProDOS will hand it back.
         PHA
         TXA
         PHA
         CLC                                      ;Tell ProDOS we accept and
         RTS                                      ; please get out of the way

CONT     LDX            #$80
         TXS                                      ;Keep out of way of NXLIN
         STADR          IN+$84;TXTPTR
         STA            INPTR+1                   ;Always points to IN
         JSR            CHRGOT
         PHP
         JSR            LINGET                    ;Get start line (dflt 0)
         MOVX           LINNUM;STARTL
         BIT            AUTOFLG
         BPL            :ISED
         JMP            :AUTOCMD
:ISED    PLP
         BEQ            :LX                       ;Branch if EDIT only
         TAY
         BEQ            :OK                       ;Branch if single line #
:LX      LDX            #-1                       ;Set max end range
         STX            LINNUM
         STX            LINNUM+1
         CMP            #','
         BNE            :CR
         JSR            CHRGET
         BCS            :CR                       ;Branch if no end range
         JSR            LINGET                    ;Get end of range
:CR      TAY
         BEQ            :OK                       ;Branch if no string
         STA            DELIM
         INC            TXTPTR
         LDY            #-1
:NY      INY
         LDA            (TXTPTR),Y                ;Get string to find
         BEQ            :SS                       ; or replace
         STA            (MEMTOP),Y                ;Put it at MEMTOP
         EOR            DELIM
         BNE            :NY
:SS      STA            (MEMTOP),Y
         LDA            (TXTPTR),Y
         BEQ            :OK                       ;Branch if just find,
         TYA                                      ; no end quote
         STA            LEN                       ;Save length for replace
         BEQ            :OK                       ;Skip if empty
         CLC
         ADC            TXTPTR
         STA            TXTPTR
         JSR            CHRGET
         BEQ            :OK                       ;Branch if no replacement
         CMP            #','
         BNE            :LYF                      ;Support syntax "BAD"GOOD"
         JSR            CHRGET
         CMP            DELIM
         BEQ            :IT
         JMP            SYNERR
:IT      INC            TXTPTR
:LYF     LDY            #-1
         STY            REFLAG                    ;Flag replace mode
:RY      INY
         LDA            (TXTPTR),Y                ;Get replacement
         BEQ            :SR
         STA            (REPTR),Y
         EOR            DELIM
         BNE            :RY
:SR      STA            (REPTR),Y
:OK      MOVD           LINNUM;ENDLIN
:EDITLUP JSR            LINTOIN
         BCS            :ALLDONE                  ;Done if no more program
         COMPR          ENDLIN;STARTL
         BLT            :ALLDONE                  ; or if past range
         LDX            #0
         STX            STRPNT                    ;Init search to start of str
         LDA            (MEMTOP,X)                ;String given?
         BNE            :JF
:ED      JSR            EDITIN                    ;Do edit/replace
         JSR            INTOPRG                   ;Put new line in program
         BIT            REFLAG
         BPL            :NXS                      ;Skip if not replace mode
         JSR            CROUT                     ;CR after replacement shown
         JSR            LINTOIN                   ;Get line back
:JF      JSR            FINDSTR                   ;This line have string?
         BCS            :ED                       ;Branch if so
:NXS     INCD           STARTL                    ;Point to line past this one
         BNE            :EDITLUP                  ;Loop always
:ALLDONE JMP            DOSWRM                    ;Must exit this way or
                                                  ; from error
:TEN     TYA
         PHP                                      ;Not Z
:AUTOCMD LDX            #10
         LDY            #0
         PLP
         BNE            :GETP
:FE      STX            STARTL
         STY            STARTL+1
         JSR            WHERE
         BCS            :TEN
         TAY
         TXA
         ADC            #10
         TAX
         BCC            :FE
         INY
         BNE            :FE                       ;Allow drop thru if high #
:GETP    JSR            CHRGOT
         BEQ            :SETEN                    ;Branch if no increm
         JSR            CHKCOM
         BCS            :SETEN
         JSR            LINGET
         LDY            LINNUM+1
         LDX            LINNUM
         BNE            :SETEN
         DEY
:SETEN   DEX                                      ;Decrease increment since
         STX            ENDLIN                    ; it is added to current+1
         STY            ENDLIN+1
:AUTOLUP JSR            WHERE
         BCS            :LINOK                    ;Branch if no lines above
         CPX            STARTL
         BNE            :LINOK                    ; or not this one
         CMP            STARTL+1
         BEQ            :ALLDONE                  ;Exit if this line exists
:LINOK   JSR            TOFOUT
         CLV                                      ;Right justify line #
         JSR            MAKLIN                    ;Get line # to input buffer
         LDA            #' '
         STA            IN+5
         JSR            EDITIN
         JSR            INTOPRG
         INCD           STARTL
         JSR            WHERE
         PHA
         PHP
         LDA            STARTL
         CLC
         ADC            ENDLIN
         STA            STARTL
         LDA            STARTL+1
         ADC            ENDLIN+1
         STA            STARTL+1
         PLP
         PLA
         BCS            :AUTOLUP                  ;Branch if no lines above
         CPX            STARTL
         SBC            STARTL+1
         BGE            :AUTOLUP                  ;Or if nxt line > next auto
         BLT            :ALLDONE                  ;Exit otherwise

TOFOUT   LDA            STARTL
         STA            FAC+2
         LDA            STARTL+1
         STA            FAC+1
         LDX            #$90
         SEC
         JSR            FLO2
         JMP            FOUT

*-----------------------------------
* Line (# STARTL) to IN
* LOWTR -> this or next line on exit
*-----------------------------------

WHERE    MOVD           STARTL;LINNUM
         JSR            FINDLINE
         LDY            #1
         LDA            (LOWTR),Y                 ;EOP?
         SEC
         BEQ            :RET
         INY
         LDA            (LOWTR),Y                 ;Get line #
         TAX
         INY
         LDA            (LOWTR),Y
         CLC
:RET     RTS

MAKLIN   LDX            #-1
:NX      INX
         LDA            STACK,X                   ;Find end of line # string
         STA            IN,X
         BNE            :NX
         STA            IN+6
         BVS            :XL
         LDY            #4                        ;-> 5th char in IN
:MV      LDA            #' '
         DEX
         BMI            :OV                       ;Justify right
         LDA            STACK,X
:OV      STA            (INPTR),Y
         DEY
         BPL            :MV
         LDX            #5
:XL      STX            LINPNT
         STX            STRSTRT
RET      RTS

LINTOIN  JSR            WHERE
         BCS            RET
         STX            STARTL
         STA            STARTL+1
         JSR            TOFOUT
:SETV    ADC            #1                        ;Clrs V 1st time, sets V 2nd
         JSR            MAKLIN
         LDY            #3
         JSR            LISTTOIN                  ;Get rest of line
         BCC            RET                       ;Exit if no problem
         LDA            #$7F
         BVC            :SETV
         JMP            MEMERR                    ;Err if still too long

*-----------------------
* Line at LOWTR to IN+5
* Must preserve V status
*-----------------------

TOKDON   LDY            FORPNT
         JSR            DOOUT
         LDA            (LOWTR),Y
         CMP            #rem                      ;Don't put extra spaces
         BEQ            NY                        ; after REM and DATA
         CMP            #data
         BEQ            NY
LISTTOIN JSR            PACKOUT
NY       INY
         LDA            (LOWTR),Y
         BPL            :NOTOK
         BVC            :ISTOK
         CMP            #print
         BNE            :ISTOK
         LDA            #'?'
:NOTOK   JSR            DOOUT
         BNE            NY
         CLC
         RTS
:ISTOK   STY            FORPNT                    ;Save ptr to real line
         LDY            #>TOKTBL                  ;Note low,hi bytes =
         STY            TOKPNT+1
         DEY
         TAX                                      ;Token to X
         DEX
         BPL            :PT
:TOKL    INY
         BNE            :OV1
         INC            TOKPNT+1
:OV1     LDA            (TOKPNT),Y
         BPL            :TOKL                     ;Skip through token table
         DEX                                      ; till found this one
         BMI            :TOKL
:PT      JSR            PACKOUT
:TOKLP   INY
         BNE            :OV2
         INC            TOKPNT+1
:OV2     LDA            (TOKPNT),Y
         BMI            TOKDON
         JSR            DOOUT
         BNE            :TOKLP

PACKOUT  BVS            BACK
         LDA            #' '                      ;Else store space
DOOUT    STY            TEMP
         LDY            LINPNT
         AND            #$7F
         STA            (INPTR),Y
         BEQ            BACK                      ;Just made it
         LDY            TEMP
         INC            LINPNT
         BNE            BACK
         PLA
         PLA
         SEC
BACK     RTS

*-----------------------------------
* IN to program line.  This forces a
* return by setting the outhook.
*-----------------------------------

INTOPRG
         LDA            #>IN
         LDY            #>:OUROUT
         LDX            #1
:IT      STA            TXTPTR,X
         LDA            CSWL,X
         STA            HOOKSV,X
         STY            CSWL,X
         LDY            #:OUROUT
         DEX
         TXA
         BEQ            :IT
         TSX
         STX            STKPNT
         LDX            #$F8                      ;This prevents trouble
         TXS                                      ; from interupts
         JSR            CHRGOT
         JMP            NXLIN

:OUROUT  LDX            STKPNT                    ;Always = $9E
         TXS
         MOVD           HOOKSV;CSWL
         RTS

*--------------------------------------------------
* Routine to search line in IN for string at MEMTOP
* Used by both (string) edit mode and replace mode:
*--------------------------------------------------

FINDSTR  LDX            STRPNT
         BNE            :DX
         LDX            STRSTRT
:DX      DEX                                      ;Start past line #
:SX      STX            CHARAC                    ;Remember position in line
         LDY            #-1
:NY      INY
         INX
         LDA            (MEMTOP),Y
         BEQ            :RET                      ;Branch if FOUND
         CMP            IN,X
         BEQ            :NY
         LDX            CHARAC                    ;Reject, update ptr
         INX
         LDA            IN,X
         BNE            :SX                       ;Loop unless line done
         CLC                                      ;Flag not found
         RTS
:RET     TXA
         STX            OLDPNT                    ;-> end of find string
         STY            CHARAC
         SBC            CHARAC
         STA            STRPNT                    ;-> end of replace string
         RTS

*-----------------------------------------------
* Routine to list IN with replacement string
* in inverse, and to build the replacement line:
*-----------------------------------------------

MAKNEW   LDY            #0
         LDX            #0
         STX            REPTR
:MV      LDA            IN,X
         STA            (NEWPTR),Y
         BEQ            :DONE
         JSR            OUTCHAR                   ;Updates Y
         INX
         CPX            STRPNT
         BNE            :MV
         LDX            #0
:GN      LDA            (REPTR,X)
         BEQ            :REDON
         STA            (NEWPTR),Y
         JSR            INVCHAR                   ; "
         INC            REPTR
         BNE            :GN
:REDON   LDA            STRPNT
         CLC
         ADC            LEN
         TAX
         STY            TEMP
         BNE            :MV
:DONE    STY            CURPNT                    ;TEMP has next strpnt
RETN     RTS

*----------------------------
* Main line editing routines:
*----------------------------

ABORT    JSR            CLREPLC
         JMP            DOSWRM

DOREPLC  JSR            MAKNEW                    ;Make new line & show it
:JG      JSR            BELKEY
         LDX            OLDPNT                    ;In case change rejected
         CMP            #'X'&$1F
         BEQ            ABORT
         CMP            #'C'&$1F
         BEQ            ABORT
         AND            #%11011111
         CMP            #'N'
         BEQ            :NO
         EOR            #'Y'
         BNE            :JG
         TAY                                      ;Do the replacement
:MV      LDA            (NEWPTR),Y
         STA            (INPTR),Y
         INY
         BNE            :MV
         LDX            TEMP
:NO      STX            STRPNT
         JSR            CLREPLC                   ;Erase question line
LISTN    LDY            CURPNT                    ;List line from CURPNT on
:EN      LDA            (INPTR),Y
         BEQ            RETN
         JSR            OUTCHAR
         BNE            :EN

EDITIN   BIT            REFLAG
         BMI            DOREPLC                   ;Branch if replace mode
         LDX            #6                        ;For backspacing
         STX            CURPNT
         JSR            PRBL2
         STX            MODE
         STX            FZCHAR
         JSR            PRNTIN
:ELUP    STY            CURPNT
         LDA            (INPTR),Y
         BNE            :JPRNT                    ;Check line not too long
         INY
         BNE            :NZ
         DEY
:NZ      STA            (INPTR),Y
         DEY
         LDA            #' '
         STA            (INPTR),Y
:JPRNT   JSR            SETI                      ;Print from cursor at CURPNT
:CURY    LDY            CURPNT
         INY
:DYK     DEY
:JKEY    JSR            GETKEY
:ISCNT   CMP            #' '
         BLT            :ISCMD                    ;Branch if control char
         LDX            #2                        ; (In case its DEL)
         CMP            #$7F
         BEQ            :DEL                      ; or DELETE key
         BIT            MODE
         BMI            :INSRT                    ;Insert/zap mode
         BVS            :FIND                     ;Find mode
:NXCHR   INY
         BEQ            :DYK                      ;Reject if at end of buffer
         PHA
         LDA            IN-1,Y                    ;If cursor on eol
         BNE            :PUL
         STA            (INPTR),Y                 ; then put eol at next spot
:PUL     PLA
         DEY
         STA            (INPTR),Y                 ;Put char at cursor
         JSR            OUTCHAR                   ;Update screen pos
         BMI            :ELUP

:ISCMD   LDX            #:CMDEND-:CMDS-1
:IL      CMP            :CMDS,X
         BEQ            :GO
         DEX
         BPL            :IL
         BMI            :JKEY

:GO      STX            MODE
:DEL     LDA            #>:REPLC                  ;Keep mode for DEL
         PHA
         LDA            :ADRS,X
         PHA
         LDA            #0
         TAX
         SEC
         RTS

* All commands in table must be below this

:REPLC   BIT            AUTOFLG
         BMI            :JKEY
         JSR            WIPE                      ;Erase current line
         JSR            LINTOIN                   ;Get line from program
         JMP            EDITIN

:FIND    JSR            :CHKMODE                  ;Check for recursion
         HEX            2C
:WORD    LDA            #' '
         HEX            2C
:STAT    LDA            #':'
         JSR            :FINDIT
         STA            CHARAC
:MC      LDA            (INPTR),Y                 ;Move cursor to found char
         JSR            OUTCHAR
         CPY            CHARAC
         BNE            :MC
         BEQ            :IG

:CASE    LDA            (INPTR),Y
         CMP            #$40
         BLT            :NXCHR
:SPC     EOR            #$20
         BNE            :NXCHR                    ;Always

:DELCMD  TYA
         BEQ            :JKEY                     ;Reject if at start of line
         DEC            CURPNT
         JSR            OUTSP                     ;In case at eol
         JSR            BACK2                     ;Set to del char before curs
:DCMD    LDA            (INPTR),Y
         BEQ            :JC
         TYA
:DD      TAX
         JSR            :DODEL
         BEQ            :JC

:OCMD    JSR            GETKEY                    ;Get next key
         CLV                                      ;Not zap
:INSRT   STA            CHARAC
         BVS            :ZAP
:FE      LDA            (INPTR),Y                 ;Find eol
         BEQ            :MV
         INY
         BNE            :FE
:BAD     STY            MODE
         BEQ            :JC                       ;Always

:MV      INY
         BEQ            :BAD                      ;Reject if line too long
:UP      LDA            IN-1,Y
         STA            (INPTR),Y                 ;Move line up
         DEY                                      ; from cursor on
         CPY            CURPNT
         BNE            :UP
         LDA            CHARAC
         STA            (INPTR),Y                 ;Put inserted character
         JSR            OUTCHAR
:IG      JMP            :ELUP

:ZAP     JSR            :CHKMODE
         JSR            :FINDIT
         PHA
         JSR            CLREOL
         PLA
         SBC            #1                        ;Carry is set
         BCS            :DD                       ;Always

:FCMD    ROR
         HEX            2C
:ZCMD    LDA            #-1
:ICMD    ROR
         STA            MODE                      ;FF=zap, 80=insert, 40=find
         STX            FZCHAR
         JMP            :JKEY

:END     JSR            GOEND
:FOR     LDA            (INPTR),Y
         BEQ            :SPC                      ;In case of END
         JSR            OUTCHAR
         BNE            :LIN

:BEGIN   JSR            BACKUP
:BAKSP   TYA
         BEQ            :IG
         LDA            (INPTR),Y
         JSR            OUTCHAR
         JSR            BACK2
:LIN     LDA            (INPTR),Y
         BEQ            :IG
         JSR            INVCHAR
         JSR            BACKSPC
         STY            CURPNT
:JC      JMP            :CURY

:ABORT   JSR            WIPE                      ;Erase line and exit
         JMP            DOSWRM

:PACK    JSR            PACK
         BCS            :IG                       ;Always

:TRUNC   JSR            CLREOL                    ;Clear from cursor on
         LDA            #0
         STA            (INPTR),Y                 ;Set eol
:CR      JSR            GOEND
         JMP            CROUT

* All commands in table must be above this

         ERR            :CR!:REPLC&$FF00
         ERR            :REPLC&:REPLC&$FF-1/-1

:FINDIT  INY
         LDX            IN,Y
         BEQ            :XM
         CMP            (INPTR),Y
         BNE            :FINDIT
         TYA
         LDY            CURPNT
         RTS
:XM      STX            MODE
         STX            FZCHAR
         PLA
         PLA
         JMP            :CURY

:CHKMODE LDX            FZCHAR                    ;Called by FIND/ZAP
         BEQ            :SC                       ;Br if 1st char after cmd
         CMP            FZCHAR
         BEQ            :SC                       ;Branch if same as 1st
         TAX                                      ;Save char
         PLA                                      ;Pop call
         PLA
         LDA            #0
         STA            FZCHAR                    ;Clear flags
         STA            MODE
         TXA                                      ;Char back
         JMP            :ISCNT                    ;Use it
:SC      STA            FZCHAR                    ;Save for next keypress
         RTS

:CMDS    DFB            'I'&$1F,'F'&$1F,$7F,'D'&$1F,$D
         DFB            'U'&$1F,'H'&$1F,'B'&$1F,'N'&$1F
         DFB            'X'&$1F,'Q'&$1F,'Z'&$1F,'R'&$1F
         DFB            'O'&$1F,'P'&$1F,'C'&$1F,'W'&$1F
         DFB            'S'&$9F,'L'&$9F
:CMDEND

:ADRS    DFB            :ICMD-1
         DFB            :FCMD-1
         DFB            :DELCMD-1
         DFB            :DCMD-1
         DFB            :CR-1
         DFB            :FOR-1
         DFB            :BAKSP-1
         DFB            :BEGIN-1
         DFB            :END-1
         DFB            :ABORT-1
         DFB            :TRUNC-1
         DFB            :ZCMD-1
         DFB            :REPLC-1
         DFB            :OCMD-1
         DFB            :PACK-1
         DFB            :ABORT-1
         DFB            :WORD-1
         DFB            :STAT-1
         DFB            :CASE-1

:DODEL   LDA            IN+1,X                    ;Used by ^D, delete & zap
         STA            (INPTR),Y                 ;Delete char at Y
         INX
         INY
         BNE            :DODEL
PRNTIN   LDY            CURPNT
         BEQ            SETI
:BS      JSR            BACKSPC                   ;Backspace to start
         BNE            :BS
:FOR     LDA            (INPTR),Y                 ;Then print to cursor
         JSR            OUTCHAR
         CPY            CURPNT
         BNE            :FOR
SETI     LDA            #$3F                      ;Print inverse cursor
         STA            INVFLG
         JSR            LISTN                     ;Print rest of line
         JSR            OUTSP
BAK      JSR            BACKSPC                   ;Backspace to cursor
         CPY            CURPNT
         BNE            BAK
         RTS

*--------------
* Misc routines
*--------------

GOEND    JSR            LISTN
         JSR            OUTSP                     ;In case cursor at end
         HEX            2C
:SIN     STA            (INPTR),Y
:JBS     JSR            BACKSPC
         LDA            (INPTR),Y
         BEQ            :JBS
         EOR            #' '
         BEQ            :SIN
         RTS

BACK2    JSR            BACKSPC
BACKSPC  LDA            #$88
         JSR            COUT
         DEY                                      ;Must be last to set status
RTS      RTS

BACKUP   TYA                                      ;Assumes that Y=CURPNT
         BEQ            RTS                       ;Backspace to start of line
         LDA            #0
         STA            CURPNT
         BEQ            BAK

WIPE     JSR            BACKUP                    ;Go to start of line
CLREOL   LDA            (INPTR),Y
         BEQ            CURBACK                   ;Continue unless line done
         JSR            OUTSP                     ;Send a space
         BNE            CLREOL
CLREPLC  LDY            CURPNT
         LDX            CURPNT                    ;Used after replace
         JSR            BACKUP
         TXA
         TAY
         JSR            PRBL2
CURBACK  JSR            BACKSPC                   ;Backspace to start again
         CPY            CURPNT
         BNE            CURBACK
         RTS

PACK     JSR            WIPE
         LDX            #-1
         LDY            #-1
:NX      INX
:NY      INY
         LDA            (INPTR),Y
         STA            IN,X
         BEQ            :DONE
         CMP            #' '
         BEQ            :NY
         CMP            #'"'
         BNE            :NX
:LIT     INX
         INY
         LDA            (INPTR),Y
         STA            IN,X
         BEQ            :DONE
         CMP            #'"'
         BNE            :LIT
         BEQ            :NX
:DONE    TAY                                      ;=0
:MVC     LDA            (INPTR),Y                 ;Move cursor past line #
         EOR            #'0'
         CMP            #10
         BGE            RTN
         EOR            #'0'
         JSR            OUTCHAR
         BNE            :MVC

*---------------------
* Key getting routine:
*---------------------

BELKEY   JSR            BELL
GETKEY   JMP            (KEYVEC)
KEYGET   LDA            KEY
         BPL            KEYGET
         BIT            STROBE
         AND            #$7F
         BEQ            KEYGET                    ;Reject ^@
RTN      RTS

*------------------
* Character output:
*------------------

OUTSP    LDA            #" "
OUTCHAR  ORA            #$80
         CMP            #" "
         BGE            PRT
         ADC            #'@'
INVCHAR  LSR            INVFLG
         LSR            INVFLG
PRT      PHA
         JSR            COUT
         LDA            #-1
         STA            INVFLG
         INY                                      ;To update cursor
         PLA
         RTS
