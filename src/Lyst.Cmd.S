********************************
*                              *
*     LYST   BASIC COMMAND     *
*                              *
*    Glen Bredon    1/15/85    *
*                              *
********************************

         DATE

         EXP            OFF
         TR
         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/LYST.CMD
         FIN

* Data

MAX      =              50

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54
FBITS    =              $BE56
VENDA    =              $BE5D
VLENTH   =              $BE5F
VLINE    =              $BE68
VPATH1   =              $BE6C
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

         AST            50

CSWH     =              $37
TXTTAB   =              $67
FORPNT   =              $85
HIGHTR   =              $96
LOWTR    =              $9B
FAC      =              $9D
CHRGOT   =              $B7
REMSTK   =              $F8
STACK    =              $100
IN       =              $200
KEY      =              $C000
STROBE   =              $C010
FLO2     =              $EBA0
FOUT     =              $ED34
CROUT    =              $FD8E
COUT     =              $FDED
TOKTBL   =              $D0D0
OUTDO    =              $DB5C

* Our usage:

TOKPNT   =              $D6                       ;Low byte always 0
CHRCNT   =              $E0                       ;# Chrs printed on line
TAB      =              $E1                       ;FOR-NEXT indenting
LINTAB   =              $E2                       ;IF indenting
QUOFLAG  =              $E3                       ;Quote, REM (V bit), flag
TEMP     =              $E4
NUMLINES =              $E5                       ;Specified page length
LINCNT   =              $E6                       ;Countdown of this
LINLEN   =              $E7                       ;Line length - 8
MINTAB   =              $E8                       ;= left margin + 6
MARGIN   =              $E9                       ;Left margin
IFFLAG   =              $EA                       ;Flags line with IF
TOKEN    =              $EB

* Tokens

for      =              129
next     =              130
if       =              173
rem      =              178

         AST            50

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

LINK     MAC
         LDY            #0
         LDA            (]1),Y
         TAX
         INY
         LDA            (]1),Y
         STA            ]1+1
         STX            ]1
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
:PA      LDA            AMPNAME,Y
         JSR            COUT
         INY
         CPY            #AMPEND-AMPNAME
         BLT            :PA
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            15                        ;ID byte

PARSE    LDX            #CMDEND-CMDNAME-1
         STX            XLEN
         SEC
         INX
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
         BNE            DOSEXIT
         DEX                                      ;Carry is set
         BNE            :ISIT
         STX            TOKPNT
         STX            XCNUM                     ;Signal external cmd
         LDA            #%00010001                ;Filename allowed
         STA            PBITS
         LDA            #%00111001                ;E,L,@,R parms allowed
         STA            PBITS+1
         STADR          START;XTRNADDR
         CLC                                      ;Tell interpreter we
         RTS                                      ; accepted command

AMPNAME
CMDNAME  ASC            "LYST"
CMDEND   ASC            " [header,E ln/pg,L chrs/ln,@ marg]"8D
AMPEND

PAGMSG   HEX            8D
PAGE     REV            "=== Page  2"
PAGEND

START    TSX
         STX            REMSTK
         LDA            #" "
         STA            PAGE+1
         LDA            #"2"
         STA            PAGE
         MOVD           VPATH1;HIGHTR
         LDX            #80-8                     ;Default
         LDA            FBITS+1
         PHA
         PHA
         AND            #%00010000
         BEQ            :SX
         LDA            VLENTH                    ;Get L parm
         SEC
         SBC            #8
         TAX
:SX      STX            LINLEN
         PLA
         AND            #%00100000
         BEQ            :NOE
         LDA            VENDA                     ;Get E parm
         SEC
         SBC            #3                        ;Sub 3 for header
:NOE     STA            NUMLINES
         STA            LINCNT
         PLA
         AND            #%00001000                ;Get @ parm
         BEQ            :MAR                      ;Branch if none
         LDA            VLINE
:MAR     STA            MARGIN
         CLC
         ADC            #6
         STA            MINTAB
         STA            TAB
         MOVD           TXTTAB;LOWTR
         LSR            TOKEN

* Main program loop:

:NXTLIN  LDY            #1
         LDA            (LOWTR),Y
         BEQ            :EXIT                     ;All done if link 0
         LDA            #0
         STA            CHRCNT
         STA            LINTAB                    ;Init "IF" indenting
         STA            QUOFLAG                   ;  and quote flag
         JSR            DOCR                      ;CR and pagination
         JSR            DOMARG                    ;Do left margin
         INY
         LDA            (LOWTR),Y                 ;Line # low
         TAX
         INY
         LDA            (LOWTR),Y                 ; & high
         JSR            PRAX                      ;Print it
         JSR            DOTAB                     ;Do indenting
         LDY            #3
         STY            IFFLAG                    ;Init "IF" flag
         JSR            LIST1LIN                  ;Print this prog line
         LINK           LOWTR
         BNE            :NXTLIN                   ;Back for next
:EXIT    CLC
BACK     RTS

*--------------------
* List line at LOWTR:
*--------------------

LIST1LIN INY
         LDA            (LOWTR),Y
         BEQ            BACK
         CMP            TOKEN
         BEQ            :LLW
         LDX            TOKEN
         STA            TOKEN
         CMP            #rem
         BEQ            :DASH
         CPX            #rem
         BNE            :LLW
:DASH    JSR            DASH
:LLW     LDA            (LOWTR),Y
         BEQ            BACK                      ;In case from TOKDON
         BMI            :OV
         JSR            SPCOUT                    ;Space at start if non token
:OV      DEY
:NY      INY
:LL      LDA            (LOWTR),Y
         BMI            :ISTOK
         BEQ            BACK
         JSR            DOOUT                     ;Print char
         BIT            QUOFLAG
         BVS            :NY                       ;Branch if REM
         CMP            #'"'
         BNE            :STAT
         LDA            QUOFLAG                   ;Toggle quote mode
         EOR            #$80
         STA            QUOFLAG
:STAT    BIT            QUOFLAG
         BMI            :NY                       ;Branch if literal
         EOR            #':'
         BNE            :NY
         STA            CHRCNT
         INY
         LDA            (LOWTR),Y
         BEQ            BACK
         DEY
         JSR            DOCR
         JSR            DOTAB
         BEQ            LIST1LIN                  ;Always

:TOKDON  LDY            FORPNT
         JSR            DOOUT
         INY
         BNE            :LLW

:ISTOK   STY            FORPNT                    ;Save ptr to real line
         LDY            #>TOKTBL                  ;Note low,hi bytes =
         STY            TOKPNT+1
         DEY
         TAX                                      ;Token to X
:IF      CPX            #if
         BNE            :REM
         STX            IFFLAG                    ;Flag IF for "NEXT" decision
         LDA            LINTAB
         ADC            #2
         STA            LINTAB
:REM     CPX            #rem
         BNE            :CF
         ROR                                      ;Set both sign and V bits
         STA            QUOFLAG
:CF      CPX            #for
         BNE            :ISNX
         LSR            IFFLAG                    ;Cancel IF flag for a FOR
         LDA            TAB
         ADC            #2
         CMP            #MAX
         BGE            :DX
         STA            TAB
:ISNX    CPX            #next
         BNE            :DX
         BIT            IFFLAG
         BMI            :DX
         STY            TEMP
         LDY            FORPNT
:IT      LDA            TAB
         SBC            #3                        ;Back tab up 3 places
         CMP            MINTAB
         BLT            :EX
         STA            TAB
:NXY     INY
         LDA            (LOWTR),Y
         BEQ            :EX
         CMP            #':'
         BEQ            :EX
         CMP            #','                      ;Do again if multiple
         BEQ            :IT                       ; NEXT
         BNE            :NXY
:EX      LDY            TEMP
:DX      DEX
         BPL            :PT
:TOKL    INY
         BNE            :OV1
         INC            TOKPNT+1
:OV1     LDA            (TOKPNT),Y
         BPL            :TOKL                     ;Skip through token table
         DEX                                      ; till found this one
         BMI            :TOKL
:PT      JSR            SPCOUT
:TOKLP   INY
         BNE            :OV2
         INC            TOKPNT+1
:OV2     LDA            (TOKPNT),Y
         BMI            :TOKDON
         JSR            DOOUT
         BNE            :TOKLP

SPCOUT   LDA            #' '
DOOUT    PHA
         SEC
         LDA            CHRCNT
         SBC            LINLEN
         BLT            :PUL                      ;Branch if not near border
         CMP            #7
         BGE            :NXL                      ;Branch if at the border
         PLA
         PHA
         CMP            #' '
         BNE            :PUL                      ;New line now if at word brk
:NXL     LDA            #0
         STA            CHRCNT
         JSR            DOCR
         JSR            DOTAB
         LDX            #7
:JSP     JSR            SPCOUT
         DEX
         BNE            :JSP
:PUL     PLA
         CMP            #' '
:ISC     BGE            :NOTCNTR
         ADC            #'@'
         PHA
         LDA            #'^'
         JSR            :NOTCNTR
         PLA
:NOTCNTR
         INC            CHRCNT
         JMP            OUTDO

PRAX     STX            FAC+2                     ;Print A,X in decimal
         STA            FAC+1                     ; right justified
         LDX            #$90
         SEC
         JSR            FLO2
         JSR            FOUT
         LDX            #-1
:NX      INX
         LDA            STACK,X
         BNE            :NX
         LDY            #4
:PN      LDA            #' '
         DEX
         BMI            :OV
         LDA            STACK,X
:OV      STA            IN+$80,Y
         DEY
         BPL            :PN
         LDX            #5
:NY      INY
         LDA            IN+$80,Y
         JSR            DOOUT
         DEX
         BNE            :NY
         RTS

DASH     LDA            FBITS+1
         LSR
         BCS            RET
:DSH     LDA            #'-'
         JSR            DOOUT
         LDA            CHRCNT
         CMP            LINLEN
         BLT            :DSH
         JSR            DOCR
DOTAB    LDA            CHRCNT
         CMP            TAB
         BGE            :CHKLT
         JSR            SPCOUT                    ;Print spaces till
         BNE            DOTAB                     ; CHRCNT = TAB
:CHKLT   LDX            LINTAB
         BEQ            RET
:JS      JSR            SPCOUT                    ;Tab more for IF indent
         DEX
         BNE            :JS
RET      RTS

DOCR     DEC            LINCNT
         BNE            :CR
         LDA            NUMLINES
         BEQ            :CR
         STA            LINCNT
         JSR            :CR
         LDA            CSWH
         EOR            #$C1
         BEQ            :CC                       ;Branch if printer
         LDA            #1                        ;Substitute CR
:CC      CLC
         ADC            #$8C
         JSR            COUT
         JSR            DOMARG
         LDA            FBITS
         LSR
         BCC            :LX                       ;No header
         TYA
         PHA
         LDY            #0
         LDA            (HIGHTR),Y
         BEQ            :PA                       ;Not needed
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
         LDA            #0
         STA            CHRCNT
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

ABORT    LDX            REMSTK
         TXS
         CLC
         RTS

DOMARG   LDX            MARGIN
         BEQ            :RET
:JSP     JSR            SPCOUT
         DEX
         BNE            :JSP
:RET     RTS
