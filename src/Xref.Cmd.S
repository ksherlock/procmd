******************************
*                            *
*       XREF BASIC CMD       *
*                            *
*  Glen E. Bredon  12/31/84  *
*                            *
******************************

         DATE

         REL                                      ;Generate a LNK file

         EXP            OFF
         TR

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/XREF.CMD
         FIN

CHARAC   =              $D                        ;Used for line parsing
TEMP     =              $E                        ;PRLINNUM usage
DEFLAG   =              $16                       ;* if var is defined in line
TOKEN    =              $1A                       ;Last token found on line
NUMLINS  =              $1B                       ;Specified # lines/page
LEN      =              $1C                       ;# refs/line
COUNT    =              $1D                       ;Countdown to CR
CSWH     =              $37
LINNUM   =              $50                       ;Line # for xref of var
TXTTAB   =              $67
VARNAM   =              $81                       ;Var found (3 bytes, eg AB$)
CURVAR   =              $89                       ;Current candidate for smallest
LINCNT   =              $91                       ;Countdown for page skip
LASTCHR  =              $92                       ;Char before # ref
YSAV     =              $93                       ;Save for line ptr in FINDVAR
HIGHTR   =              $96                       ;Header ptr
LOWTR    =              $9B                       ;Pointer for FINDVAR
MINVAR   =              $9D                       ;Last var xrefed or 0 (3 bytes)
CHRGET   =              $B1
CHRGOT   =              $B7                       ;Used only for &
TXTPTR   =              $B8
TXTPSV   =              $F4
NUMFLAG  =              $F6
REMSTK   =              $F8
IN       =              $200
KEY      =              $C000
STROBE   =              $C010
FINDLINE =              $D61A
LINGET   =              $DA0C
ISLETC   =              $E07D                     ;Returns C set if alpha
PRBL2    =              $F94A
PRBL3    =              $F94C
CROUT    =              $FD8E
COUT     =              $FDED
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters, 0 = none (2 bytes)
FBITS    =              $BE56                     ;Parms found
VENDA    =              $BE5D                     ;E param value
VLNTH    =              $BE5F                     ;L param value
VPATH1   =              $BE6C
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)

* Tokens:

for      =              129
next     =              130
data     =              131
input    =              132
del      =              133
dim      =              134
read     =              135
let      =              170
goto     =              171
run      =              172
gosub    =              176
rem      =              178
def      =              184
list     =              188
get      =              190
fn       =              194
then     =              196
minus    =              201

MOV      MAC
         LDA            ]1
         STA            ]2
         <<<

MOVD     MAC
         MOV            ]1;]2
         MOV            ]1+1;]2+1
         <<<
MOVT     MAC
         MOVD           ]1;]2
         MOV            ]1+2;]2+2
         <<<

COMPT    MAC
         LDA            ]1+2
         CMP            ]2+2
         LDA            ]1+1
         SBC            ]2+1
         LDA            ]1
         SBC            ]2
         <<<

         AST            50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP            PARSE                     ;These two jumps permit RELOC
DOSEXIT  JMP            XRETURN                   ; to daisy chain commands
AMPEXIT  JMP            MONRTS                    ;This one to daisy chain & cmds
AMPENTRY BNE            AMPEXIT                   ;Other & cmds to next routine
         LDY            #0
:SN      LDA            CMDNAME,Y                 ;Show our "list" of dos cmds
         JSR            COUT                      ;If all modules have this
         INY                                      ; routine then &<RTN> will
         CPY            #AMPEND-AMPNAME+1
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            11                        ;Signature

PARSE    LDX            #CMDEND-CMDNAME
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
         SEC                                      ;In case we exit here
         BNE            DOSEXIT                   ;Support daisy chain
         DEX
         BNE            :ISIT
         STX            XCNUM                     ;Signal external cmd
         LDA            #%00010001                ;File name optional
         STA            PBITS                     ; (makes parameters legal)
         LDA            #%00110000                ;Allow E,L parms
         STA            PBITS+1
         LDA            #XREF
         STA            XTRNADDR
         LDA            #>XREF
         STA            XTRNADDR+1
         LDX            #3
         LDA            IN+4
         CMP            #"#"
         BNE            :SX
         INX
:SX      STX            XLEN
         CLC
         RTS

*--------------------
*  Main program loop:
*--------------------

XREF     TSX
         STX            REMSTK
         LDX            #2
:MV      LDA            TXTPTR-1,X
         STA            TXTPSV-1,X
         LDA            VPATH1-1,X
         STA            HIGHTR-1,X
         DEX
         BNE            :MV
         LDA            #" "
         STA            PAGE+1                    ;For reentry
         LDA            #"2"
         STA            PAGE
         LDA            FBITS+1
         ASL
         ASL
         ASL                                      ;E parm to carry
         STX            MINVAR                    ;Init min var accepted
         STX            MINVAR+1
         STX            MINVAR+2
         BCC            :NOE
         LDX            VENDA
:NOE     STX            NUMLINS
         DEX
         DEX
         DEX
         STX            LINCNT
         ASL                                      ;L parm to carry
:L80     LDA            #80
         BCC            :NOL
         LDA            VLNTH
:NOL     LSR                                      ;/8
         LSR
         LSR
         CMP            #40/8                     ;L40 is minimum
         BLT            :L80
         STA            LEN
         LDY            #1
         LDA            (TXTTAB),Y                ;Is there a program
         BEQ            :EXIT                     ;Abort if not
         JSR            DOCR
         LDA            XLEN
         CMP            #4
         ROR            NUMFLAG                   ;- if # mode
:XLUP0   LDY            #3                        ;Point to 1st char of 1st line
         STY            LASTCHR
         LDA            #-1
         STA            CURVAR                    ;Set max current var
         STA            CURVAR+1
         STA            CURVAR+2
         MOVD           TXTTAB;LOWTR
:XLUP    JSR            FINDVAR                   ;Find next variable
         BCC            :CPR                      ;Branch if found
:EXIT    JMP            ABORT                     ;All done if none found

:CPR     JSR            COMINVAR
         BGE            :XLUP                     ;Reject if this is <= min
:CPRV    COMPT          VARNAM;CURVAR
         BGE            :REJECT                   ;Reject var if => cur var
         MOVT           VARNAM;CURVAR
:REJECT  JSR            FINDVAR                   ;Look for a smaller var
         BCS            :DOX                      ;None smaller -> xref cur var
         JSR            COMINVAR
         BLT            :CPRV                     ;If var in good range, check it
         BGE            :REJECT                   ;Else look for another
:DOX     JSR            DOXREF                    ;Xref cur var
         MOVT           CURVAR;MINVAR
         JMP            :XLUP0                    ;Set min = cur and loop

COMINVAR COMPT          MINVAR;VARNAM
         RTS

         AST            50

AMPNAME
CMDNAME  ASC            "XREF"
CMDEND   ASC            "[#][header,E ln/pg,L chars/ln]"
AMPEND
PAGMSG   HEX            8D
PAGE     REV            "=== Page  2"
PAGEND

*--------------------------------------------
* Have smallest var.  Print it and its xrefs:
*--------------------------------------------

DOXREF   BIT            NUMFLAG
         BPL            :LX6                      ;Branch if var mode
         LDA            CURVAR
         STA            LINNUM+1
         LDA            CURVAR+1
         STA            LINNUM
         JSR            FINDLINE
         LDA            #":"
         BCS            :OV                       ;If found
         LDA            #"?"
:OV      STA            DEFLAG
         LDA            #1
         JSR            PRLINNUM                  ;Print refncd line
         BEQ            :GOTHRU                   ;Always
:LX6     LDX            #6                        ;Char count
         LDY            #0
:PN      LDA            CURVAR,Y
         ASL                                      ;Strip real array flag
         BEQ            :NP
         SEC
         ROR
         JSR            COUT
         DEX                                      ;Count it
:NP      INY
         CPY            #3
         BLT            :PN
         LDA            #"("                      ;Set for array signal
         BIT            CURVAR+2                  ;Is it an array
         BMI            :AR                       ;Branch if so
         LDA            #" "                      ;Else print space
:AR      JSR            PRBL3                     ;Print 4th char & fill spaces
:GOTHRU  MOVD           TXTTAB;LOWTR
         JSR            FINDVAR3
         JMP            :OVER
:DXLUP   JSR            FINDVAR                   ;Look for a ref to cur var
:OVER    BCS            DOCR                      ;Exit with CR if no more
         LDX            #2
:ISIT    LDA            VARNAM,X                  ;Does var = cur var?
         CMP            CURVAR,X
         BNE            :DXLUP                    ;Reject if not
         DEX
         BPL            :ISIT
         BIT            NUMFLAG
         BPL            :DEC
         LDA            #" "
         LDX            TOKEN
         CPX            #gosub
         BNE            :DEF
         LDA            #"s"
:DEF     STA            DEFLAG
:DEC     DEC            COUNT                     ;Countdown print fields
         BNE            :SAML
         JSR            DOCR                      ;CR & page header if needed
         DEC            COUNT
         LDA            XLEN
         CLC
         ADC            #3
         TAX                                      ;7 for num, 6 for var
         JSR            PRBL2
:SAML    LDA            #2
         JSR            PRLINNUM                  ;Print xref line
         JMP            :DXLUP                    ; and loop

DOCR     MOV            LEN;COUNT                 ;# refs/line wanted
         DEC            LINCNT
         BNE            :CR
         LDA            NUMLINS
         BEQ            :CR
         SEC
         SBC            #3
         STA            LINCNT
         JSR            CROUT
         LDA            CSWH
         EOR            #$C1
         BEQ            :CC
         LDA            #1
:CC      CLC
         ADC            #$8C
         JSR            COUT
         LDA            FBITS
         LSR
         BCC            :LX                       ;No header
         TYA
         PHA
         LDY            #0
         LDA            (HIGHTR),Y
         TAX
:NY      INY
         LDA            (HIGHTR),Y
         ORA            #$80
         JSR            COUT
         DEX
         BNE            :NY
         LDA            #" "
         JSR            COUT
:PA      PLA
         TAY
:LX      LDX            #PAGEND-PAGMSG-1
:PP      LDA            PAGMSG,X
         JSR            COUT
         DEX
         BPL            :PP
         INC            PAGE
         LDA            PAGE
         CMP            #":"
         BLT            :CR
         LDA            #"0"
         STA            PAGE
:IP      INC            PAGE+1
         CMP            PAGE+1                    ;If this was space
         BGE            :IP                       ; it is bumped to 1
:CR      JSR            CROUT
         LDA            KEY
         BPL            :RET
         BIT            STROBE
         CMP            #"C"&$9F
         BEQ            ABORT
         CMP            #" "
         BNE            :RET
:WAIT    LDA            KEY
         BPL            :WAIT                     ;Strobe left uncleared for spc
:RET     RTS

ABORT    MOVD           TXTPSV;TXTPTR
         LDX            REMSTK
         TXS
         CLC
         RTS

*-----------------------------------------
* Routine to print LINNUM
* LINNUM is destroyed.
* Prints # justified right in field of 5,
* Then DEFLAG, then fills field of 8 spcs.
*-----------------------------------------

PRLINNUM STY            YSAV
         PHA
         LDX            #9
         STX            TEMP
:L0      LDY            #"0"
:LUP     LDA            LINNUM
         CMP            :NUMTBL-1,X
         LDA            LINNUM+1
         SBC            :NUMTBL,X
         BCC            :MD
         STA            LINNUM+1
         LDA            LINNUM
         SBC            :NUMTBL-1,X
         STA            LINNUM
         INY
         BNE            :LUP
:MD      TYA
         DEX
         BEQ            :DIG
         CMP            #"0"
         BEQ            :MODE
         STA            TEMP
:MODE    BIT            TEMP
         BMI            :DIG
         LDA            #" "                      ;Justify right
:DIG     JSR            COUT
:NX      DEX
         BPL            :L0
         LDA            DEFLAG                    ;Print * or space
         JSR            COUT
         LDY            YSAV
         PLA
         TAX
         JMP            PRBL2

:NUMTBL  DA             1,10,100,1000,10000

*----------------------------------------
* Find variable starting at (LOWTR).
* Name put in VARNAM (3 bytes).
* 2nd byte = 0 if one char name.
* 3rd byte = 0 '$' '%' '(' "$" "%" as
*   simple real, str, int   or
*   array  real, str, int
*
* Line with variable put in LINNUM.
* DEFLAG = * if defined here, else space.
* Carry is set if no var is found.
*----------------------------------------

TKENS    DFB            del,run,list,goto,gosub,then
TKEND

FINDVAR3 BIT            NUMFLAG
         BPL            FINDVAR0
         LDY            #3                        ;Point to 1st char of line
         STY            LASTCHR                   ;Forget last char
FINDVAR  BIT            NUMFLAG
         BPL            FINDVAR2                  ;Branch if var mode
         LDA            #0
         STA            CURVAR+2
         STA            VARNAM+2
         LDA            LASTCHR
         BEQ            NXLIN
         CMP            #','
         BEQ            :YES2
         CMP            #minus
         BNE            :FV
:YES     STA            TOKEN
:YES2    CLC
         TYA
         ADC            LOWTR
         STA            TXTPTR
         LDA            LOWTR+1
         ADC            #0
         STA            TXTPTR+1
:CG      JSR            CHRGET
         BCC            :LG
         CMP            #','
         BEQ            :CG
         CMP            #minus
         BEQ            :CG
:FV      INY
         LDA            (LOWTR),Y
         BEQ            NXLIN
         BPL            :FV
         LDX            #TKEND-TKENS
:CT      CMP            TKENS-1,X
         BEQ            :YES
         DEX
         BNE            :CT
         BEQ            :FV
:LG      JSR            LINGET
         STA            LASTCHR
         LDA            LINNUM
         STA            VARNAM+1                  ;Refnced line
         LDA            LINNUM+1
         STA            VARNAM
         LDY            #2
         LDA            (LOWTR),Y
         STA            LINNUM                    ;Referring line
         INY
         LDA            (LOWTR),Y
         STA            LINNUM+1
         LDA            TXTPTR
         SBC            LOWTR
         TAY
         CLC
         RTS

NXLIN    LDY            #0
         STY            TOKEN
         LDA            (LOWTR),Y
         TAX
         INY
         LDA            (LOWTR),Y
         BEQ            :EOP
         STA            LOWTR+1
         STX            LOWTR
         LDA            (LOWTR),Y
         BNE            FINDVAR3
:EOP     SEC
         RTS

FINDVAR0 LDY            #3                        ;Point to 1st char of line
         LDA            #0
FINDVAR1 STA            LASTCHR                   ;Forget last char
FINDVAR2 INY
         LDA            (LOWTR),Y
         BEQ            NXLIN
         BPL            :JI                       ;Branch if not token
         STA            TOKEN
         CMP            #rem
         BEQ            NXLIN
         CMP            #data
         BNE            :ISQ
         LDX            #':'                      ;Move to EOS if DATA
:STCHR   TXA
:STCHR2  STA            CHARAC
:BY      INY
         LDA            (LOWTR),Y
         BEQ            NXLIN
         CMP            CHARAC
         BNE            :OV
         CPX            CHARAC
         BEQ            FINDVAR1
         BNE            :STCHR
:OV      CMP            #'"'
         BNE            :BY
         BEQ            :STCHR2

:ISQ     STA            LASTCHR                   ;It is not a var so save
         CMP            #'"'
         BNE            FINDVAR2                  ;Reject if not var, tok, "
         TAX
         BNE            :STCHR                    ;Bypass string literal

:JI      JSR            ISLETC                    ;Is it a var
         BCC            :ISQ                      ;Branch if not
:GOTV    STA            VARNAM                    ;Got a var, save 1st char
         LDX            #0                        ;Default for 2nd char
         STX            VARNAM+2                  ;& 3rd
         JSR            GETCHR
         BCC            :NAM                      ;Branch if 2nd char in name
         JSR            ISLETC
         BCC            :END                      ;Skip if 1 char name
:NAM     TAX                                      ;Get 2nd char
:PAS     JSR            GETCHR                    ;Bypass the rest
         BCC            :PAS
         JSR            ISLETC
         BCS            :PAS
:END     DEY                                      ;-> last char of name
         STX            VARNAM+1
         CMP            #'$'
         BEQ            :SET3
         CMP            #'%'
         BNE            :ISARY
:SET3    STA            VARNAM+2                  ;Set $ or %
         INY
         JSR            GETCHR                    ;Get char after $ or %
         DEY
:ISARY   CMP            #'('
         BNE            :NOTAR                    ;Branch if not an array
         LDA            VARNAM+2
         ORA            #$80                      ;Set high for alpha & compare
         STA            VARNAM+2                  ;"$", "%", or $80
         INY                                      ;-> char (
:NOTAR   STY            YSAV                      ;Save pointer in line
         LDA            LASTCHR
         BEQ            :ISASS
         CMP            #':'
         BEQ            :ISASS
         CMP            TOKEN                     ;If last char was token
         BEQ            :USIT                     ; then check token list
         CMP            #','
         BEQ            :USTOK                    ;If it was comma or semicolon
         CMP            #';'                      ; then check token, else
         BNE            :NOTASS                   ; not an assignment
:USTOK   LDA            TOKEN
:CHKT    LDX            #:TOKEND-:TOKENS-1
:CT      CMP            :TOKENS,X                 ;Is it an assignment token
         BEQ            :ISASS                    ; that does not require = ?
         DEX
         BPL            :CT
:NOTASS  LDA            #" "
         HEX            2C
:ISASS   LDA            #"*"
         STA            DEFLAG                    ;Set defined flag * or spc
         STA            LASTCHR                   ;Defeat for next go
         LDY            #2
         LDA            (LOWTR),Y                 ;Line # low
         STA            LINNUM
         INY
         LDA            (LOWTR),Y                 ;Line # high
         STA            LINNUM+1
         LDY            YSAV                      ;Retreive line pointer
         CLC                                      ;Signal var found
         RTS

:USIT    CMP            #fn
         BNE            :CHKT                     ;If not a func then chk tokens
         LDA            #'['
         STA            VARNAM+2                  ;Flag it a func
:LUKDEF  DEY
         CPY            #4
         BLT            :NOTASS
         LDA            (LOWTR),Y                 ;Find FN token
         CMP            #fn
         BNE            :LUKDEF
         DEY
         LDA            (LOWTR),Y                 ;Get previous char
         CMP            #def
         BEQ            :ISASS                    ;Flag if the def statement
         BNE            :NOTASS                   ; else not an assignment

:TOKENS  DFB            input,dim,read,get,let,then,for,next
:TOKEND

GETCHR   INY
         LDA            (LOWTR),Y
         EOR            #'0'
         CMP            #10                       ;Clear carry if numeric
         EOR            #'0'                      ;Original back
         RTS
