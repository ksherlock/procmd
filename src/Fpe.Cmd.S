********************************
*                              *
*             FPE              *
*                              *
* Applesoft interface for FPE  *
*                              *
*   Glen E. Bredon   5/4/89    *
*                              *
********************************

         DATE

         XC
         XC

         REL
SAVOBJ   KBD
         DO    SAVOBJ
         DSK   OBJECT/FPE.CMD
         FIN

BASE     =     $FFF0

         EXP   OFF
         TR
         TR    ADR

fmove    =     $00        MOVE
fround   =     $01        ROUND TO INT
fsinh    =     $02        SINH
fint     =     $03        INT PART
fsqr     =     $04        SQUARE ROOT
fln1     =     $06        LN(X+1)
fexp1    =     $08        EXP(X)-1
ftanh    =     $09        TANH
fatn     =     $0A        ARCTAN
fasin    =     $0C        ARCSIN
fatnh    =     $0D        ARCTANH
fsin     =     $0E        SINE
ftan     =     $0F        TANGENT
fexp     =     $10        EXP(X)
fpwr2    =     $11        2^X
fpwr10   =     $12        10^X
flog     =     $14        LOG
flog10   =     $15        LOG base 10
flog2    =     $16        LOG base 2
fabs     =     $18        ABSOLUTE VALUE
fcosh    =     $19        COSH
fneg     =     $1A        NEGATE
facos    =     $1C        ARCCOS
fcos     =     $1D        COS
fexpon   =     $1E        Get exponent
fmant    =     $1F        Get mantissa
fdiv     =     $20        DIVIDE
fmod     =     $21        MODULO REMAINDER
fadd     =     $22        ADD
fmult    =     $23        MULTIPLY
fieeemod =     $25        IEEE Remainder
fscale   =     $26        SCALE
fsub     =     $28        SUBTRACT
fsincos  =     $30        SINE & COSINE SIMULTANEOUSLY
fcmp     =     $38        COMPARE
ftst     =     $3A        TEST

* ProDOS BASIC interp locations:

IN       =     $200
XTRNADDR =     $BE50      ;External command vector
XLEN     =     $BE52      ;Length of cmd -1 put here
XCNUM    =     $BE53      ;Put 0 here for ext cmd
PBITS    =     $BE54
FBITS    =     $BE56
VLINE    =     $BE68
XRETURN  =     $BE9E
COUT     =     $FDED
MONRTS   =     $FFCB      ;Has RTS (for & linking)

*===================================================
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   PARSE
DOSEXIT  JMP   XRETURN
AMPEXIT  JMP   MONRTS
         BNE   AMPEXIT
         LDY   #0
:SN      LDA   CMDNAME,Y
         JSR   COUT
         INY
         CPY   #AMPEND-CMDNAME
         BLT   :SN
         JSR   CHRGOT
         BRA   AMPEXIT

         DFB   35         ;Signature

CMDNAME  ASC   "FPE"
CMDEND   ASC   " [,@0]"8D
AMPEND

PARSE    LDX   #CMDEND-CMDNAME-1
         STX   XLEN
         SEC              ;In case we exit here
:ISIT    LDA   IN,X
         AND   #%11011111
         EOR   CMDNAME,X
         BNE   DOSEXIT    ;Support daisy chain
         DEX
         BPL   :ISIT
         STZ   XCNUM      ;Signal external cmd
         CLC
         XCE
         REP   %00100000
         LDA   #%00001000_00010000
         STA   PBITS      ;Allow @ parm
         LDA   #START
         STA   XTRNADDR
         XCE
         RTS

*=================================================

CHARAC   =     $D
DIMFLG   =     $10
VALTYP   =     $11
INTFLG   =     $12
CPRMASK  =     $16
INDEX    =     $5E
VARNAM   =     $81
VARPNT   =     $83
LASTOP   =     $87
CPRTYP   =     $89
TEMP3    =     $8A
FAC      =     $9D
FACSGN   =     FAC+5
ARG      =     $A5
ARGSGN   =     ARG+5
SGNCPR   =     $AB
VPNT     =     $A0
EXTRAFAC =     $AC
CHRGOT   =     $B7
TXTPTR   =     $B8
SEED     =     $C9
REMSTK   =     $F8

         DUMMY $91        ;Packed dec number
ESGN     DFB   0          ;Sign of exponent
SGNZ     DFB   0          ;High bit = sign
EXPON    DFB   0          ;Exp in BCD
         DFB   0          ;Unused
MANT     DFB   0          ;Integer in BCD,
         DS    8          ; but 1st nibble unused
EXPT     DFB   0          ;Exponent in FIN
PARITY   DFB   0          ;Nibble ptr when building
DP       DFB   0          ;Decimal point pointer
         ERR   \$A4
         DEND

* Tokens:

fn       =     $C2
not      =     $C6
plus     =     $C8
minus    =     $C9
sgn      =     $D2
sqr      =     $DA
peek     =     $E2

MEMERR   =     $D410
NEWSTT   =     $D7D2
MISMATCH =     $DD76
STRTXT   =     $DE81
EQUOP    =     $DE98
SYNERR   =     $DEC9
POSOP    =     $DF65
IQERR    =     $E199
GIVAYF   =     $E2F2
SIGNIF   =     $E82E
FROUND   =     $E88F
OVERFLOW =     $E8D5
CONUPK   =     $E9E3
DIVERR   =     $EAE1
MOVMF    =     $EB2B
MFA      =     $EB55
RNDB     =     $EB72
FCOMP    =     $EBB2
NEGOP    =     $EED0
CAT      =     $E597

INCD     MAC
         INC   ]1
         BNE   NI
         INC   ]1+1
NI       <<<

DECD     MAC
         LDA   ]1
         BNE   ND
         DEC   ]1+1
ND       DEC   ]1
         <<<

PULL     MAC
         PLA
         STA   ]1
         PLA
         STA   ]1+1
         <<<

*=================================================

PATCH    =     $DE64      ;Intercept GETVAL and
PATCH2   =     $DD8E      ; call to it from FRMEVL

NEWGET   INC   TXTPTR
         BNE   NEWGOT
         INC   TXTPTR+1
NEWGOT   LDA   (TXTPTR)
         CMP   #':'
         BCC   ON
         RTS

ON       SBC   #'0'-1
         CMP   #' '-$30
         BEQ   NEWGET
         SEC
         SBC   #-'0'
LRET     RTS

DONE     SEC
         XCE
         LDX   REMSTK
         TXS
         JMP   NEWSTT+6

LOOK     LDA   1,S        ;Is it from GETVAL
         CMP   #PATCH+2
         BNE   NEWGOT     ;Skip if not
         LDA   2,S
         CMP   #>PATCH+2
         BNE   NEWGOT
         LDA   #SKIP-1    ;Fix stack to return to SKIP
         STA   1,S
         LDA   #>SKIP-1
         STA   2,S
         LDA   4,S        ;GETVAL called by FRMEVL?
         CMP   #>PATCH2+2
         BNE   NEWGOT     ;Skip if not
         LDA   #>GRAB-1   ;Else patch to return to
         STA   4,S        ; GRAB in our FRMEVL
         LDA   #GRAB-1
         STA   3,S
         LDA   (TXTPTR)
         CMP   #':'
         BCC   ON
         BNE   LRET
         INCD  TXTPTR     ;Here it is mini lang.
         CLC
         XCE              ;Sets carry
         LDA   (TXTPTR)
         SBC   #$CF       ;>
         BEQ   FROMM
         DEC              ;=
         BEQ   CONSTANT
         DEC              ;<
         BEQ   TOMEM
         LDA   #-1
         PHA              ;Set end marker
         BRA   NEXTCHR

ITX      INC   TXTPTR+1
         BRA   NEXTCHR

ISDIG    AND   #7
         PHA              ;Push register on stack
         INC   TXTPTR
         BEQ   ITX
NEXTCHR  LDA   (TXTPTR)
         BEQ   DONE
         CMP   #':'
         BLT   ISDIG
         BEQ   DONE
         TAX
         PLA
         BMI   :GO        ;If end marker $FF
         STA   REGISTER
         PLY
         BMI   :SS        ;If one digit, SRC = DEST
         TYA
         PLY              ;Pop end marker
:SS      ASL
         ASL
         ASL
         TSB   REGISTER
:GO      LDA   REGISTER
         XBA
         LDA   CMDTABLE-$C0,X
         TAY
         REP   %00100000
         LSR
         XBA
FPESTART STA   BASE+8     ;Command
         PHX              ;Set new end marker
         INC   TXTPTR
         CPY   #$70
         LDA   #%10000000
]LUP     AND   BASE
         BNE   ]LUP
         SEP   %00110000
         BLT   NEXTCHR
         JMP   TEST       ;Do COMPARE or TEST

TOMEM    XBA              ;=0
         LDY   #1
         LDA   (TXTPTR),Y
         EOR   #%11100000 ;= EOR '0' OR #%01101000*2
         XBA
         REP   %00110000
         INC   TXTPTR
         INC   TXTPTR
         LSR
         XBA
         LDY   #$89
         JSR   GETREG
         MX    %11
         TSC
         ADC   #5         ;CC
         TCS
         LDA   FAC
         RTS

FROMM    BRA   FROMMEM

CONSTANT XBA              ;A=0
         LDY   #1
         LDA   (TXTPTR),Y ;Register
         ORA   #%10111000
         XBA
         INY              ;=1
         LDA   (TXTPTR),Y ;Constant to download
         AND   #$3F
         ASL
         REP   %00110000
         LSR              ;Clears carry
         XBA
         STA   BASE+8     ;Command
         LDA   TXTPTR
         ADC   #3
         STA   TXTPTR
         LDA   #%10000000
]LUP     AND   BASE
         BNE   ]LUP
         SEC
         XCE
         LDX   REMSTK
         TXS
         JMP   NEWSTT+6

FROMMEM  REP   %00100000
         LDA   (VARPNT)
         STA   FACSGN-1
         ORA   #$8000
         STA   FAC
         LDY   #3
         LDA   (VARPNT),Y
         STA   FAC+3
         SEP   %00110000
         DEY
         LDA   (VARPNT),Y
         STA   FAC+2
         STZ   EXTRAFAC
         LDA   #0
         XBA
         DEY              ;=1
         LDA   (TXTPTR),Y
         EOR   #%10100000 ;= # and & OR %01001000*2
         XBA
         REP   %00110000
         LSR
         XBA
         LDY   #$89
         STA   BASE+8     ;Command
         SEP   %00110000
         LDA   FACSGN
         XBA
         LDA   FAC        ;Combine sign and exp of FAC
         REP   %00110001
         BNE   :NZ
         STZ   FAC
         STZ   FAC+2
         STZ   FAC+4
         LDA   FAC
         BRA   :OV

:NZ      AND   #$80FF     ;Mask out garbage
         ADC   #$3F7E     ;Convert AS exp to FPE exp
         XBA
:OV      LDX   FAC+1
]LUP     CPY   BASE       ;Response
         BEQ   ]LUP
         STA   BASE+$C
         STZ   BASE+$E
         STX   BASE+$C
         LDA   FAC+3
         STA   BASE+$E
         STZ   BASE+$C
         STZ   BASE+$E
         CLC
         LDA   #2
         ADC   TXTPTR
         STA   TXTPTR
         LDX   REMSTK
         LDA   #%10000000
]LUP     AND   BASE
         BNE   ]LUP
         SEC
         XCE
         TXS
         JMP   NEWSTT+6

TEST     REP   %00110000
         LDA   #$20+$88   ;Status request
         STA   BASE+8
         LDY   #$89
]LUP     CPY   BASE
         BEQ   ]LUP
         LDX   BASE+$C
         LDA   BASE+$E
         LDA   #%10000000
]LUP     BIT   BASE
         BNE   ]LUP
         TXA
         BIT   #4
         BNE   :Z
         LDA   #$325C     ;Move ROM #1 to reg 0
         STA   BASE+8
         LDA   #%10000000
]LUP     AND   BASE
         BNE   ]LUP
         TXA
         AND   #8
         BEQ   :MORE
         LDA   #$1A00     ;Negate reg 0
         BRA   :SB

:Z       LDA   #$0F5C
:SB      STA   BASE+8
         LDA   #%10000000
]LUP     AND   BASE
         BNE   ]LUP
:MORE    SEP   %00110000
         JMP   NEXTCHR

REGISTER DFB   0

         DS    $84

*=================================================
* Main formula evalutation routine.
* On entry TXTPTR points at 1st chr of formula.

MERR     JMP   MEMERR

FRMEVL   DECD  TXTPTR
         LDX   #0         ;Initial preference
         BRA   EVAL

FRMLOOP  ASL   EXTRAFAC   ;Need to round up?
         BCC   :OK        ;Skip if not
         INC   FAC+4      ;Inline ADDEPS for speed
         BNE   :OK
         INC   FAC+3
         BNE   :OK
         INC   FAC+2
         BNE   :OK
         INC   FAC+1
         BNE   :OK
         LDA   FAC        ;Skip if FAC = 0
         BEQ   :OK
         JSR   FROUND     ;Round if overflow to exp
:OK      LDA   MATHTBL+2,Y
         PHA              ;Push bin math routine adrs
         LDA   MATHTBL+1,Y
         PHA
         LDX   MATHTBL,Y  ;Prepare to push prefnce
         PEI   FAC+4      ;Push unpacked FAC
         PEI   FAC+2
         PEI   FAC
         LDA   CPRTYP
         PHA              ;Push last CPRTYP
EVAL     PHX              ; and preference
         TSX
         CPX   #$36
         BLT   MERR
         JSR   GETVAL     ;Get value or str desc
GRAB     STZ   CPRTYP     ; at TXTPTR
         LDA   (TXTPTR)
:CL      SEC
         SBC   #$CF       ;> token
         BLT   :TYP?
         BEQ   :OV
         CMP   #3         ;or =, <
         BGE   :TYP?      ;Branch if not
:OV      ROL
         EOR   CPRTYP     ;Set bits of CPRTYP:
         CMP   CPRTYP     ; 00000>=<
         BCC   SNTXERR
         STA   CPRTYP
         JSR   NEWGET     ;Another operator?
         BRA   :CL

:CAT     JMP   CAT

:TYP?    LDX   CPRTYP
         BNE   COMPARE    ;Branch if had <,=,>
         BGE   NOTMATH    ;Branch if next token > "<"
         ADC   #$CF-plus
         BCC   NOTMATH    ;Branch if next token < "+"
         BNE   :NOCAT
         BIT   VALTYP
         BMI   :CAT       ;Now A-reg has offset
:NOCAT   STA   INDEX
         ASL
         ADC   INDEX      ;Times 3
         TAY
PREFTEST PLA              ;Get last preferance
         CMP   MATHTBL,Y  ;Compare current priority
         BGE   DOMTH      ;Do now if preferred
         BIT   VALTYP     ;Was last result a #?
         BMI   MISM
NXOP     PHA
SAVOP    JSR   FRMLOOP    ;Do recursion
         LDY   LASTOP
         BPL   PREFNC     ;Branch if more formula
         PLX
         BNE   DOMATH     ;Do last operation
         LDA   FAC
         RTS

COMPARE  LSR   VALTYP     ;Enable string compare
         TXA              ;Set CPRTYP: 0000>=<C
         ROL              ; where C=carry from
         STA   CPRTYP     ; next character test.
         DECD  TXTPTR
         LDY   #PLUS-MATHTBL ;Force using POSOP for
         BRA   PREFTEST   ; all three comparisons.

SNTXERR  JMP   SYNERR

WASSTR   CMP   #$64
         BEQ   STROK      ;Allow string compare
MISM     JMP   MISMATCH

NOTMATH  PLA              ;Set up to exit routine
         BEQ   EXIT       ;Exit if no math to do
         LDY   #-1
DOMTH    BIT   VALTYP
         BMI   WASSTR
STROK    STY   LASTOP
         BRA   DOMATH

* Pull floating # from stack, place in ARG and go to
* math routine via RTS (address was placed on stack):
* (Note that <=> routines all go to POSOP.)

PREFNC   PLA
         CMP   MATHTBL,Y  ;Compare preference
         BLT   NXOP       ;Get more formula if less
DOMATH   PLA              ;Else perform last operation
         LSR              ;Restore carry status
         STA   CPRMASK    ; 00000>=<
         PULL  ARG        ;Get previous value to ARG
         PULL  ARG+2
         PULL  ARG+4
         EOR   FACSGN
         STA   SGNCPR     ;May not be needed
EXIT     LDA   FAC        ;Go to routine with status
         RTS              ; set by FAC

*===================================================

ISNUM    EOR   #'0'
         CMP   #10
         EOR   #'0'
         BLT   NUMBER
         CMP   #'.'
         BEQ   NUMBER
         CMP   #' '
         BEQ   NEXT
         CMP   #'"'
         BNE   PARCHK
         JMP   STRTXT

NUMBER   JMP   FIN        ;If numeric

ISNOT    LDY   #UNOT-MATHTBL
POP      PLA
         PLA
         BRA   SAVOP

MIN      LDY   #MINUS-MATHTBL
         BRA   POP

FUNCT    JMP   $E354

JSYNERR  JMP   SYNERR

NOTVARL  CMP   #minus
         BEQ   MIN
         CMP   #plus
         BEQ   NEXT
         CMP   #not
         BEQ   ISNOT
         CMP   #fn
         BEQ   FUNCT
         CMP   #sgn
         BGE   UNARY
PARCHK   JSR   CHKOPN     ;Is there a '(' at TXTPTR?
         JSR   FRMEVL     ;If so, evaluate and
         LDA   #')'       ;Check for ')'
         HEX   2C
CHKOPN   LDA   #'('
         EOR   (TXTPTR)
         BNE   JSYNERR
         TAY
         JMP   NEWGET     ;If ok, get next chr & rtn

* Get value of variable, function or number following
* TXTPTR, or point to string descriptor if a string,
* and put in FAC.  This also evaluates expressions in
* parens by means of a recursive call to FRMEVL.

GETVAL   STZ   VALTYP     ;Init type = not string
NEXT     INCD  TXTPTR
         LDA   (TXTPTR)
SKIP     CMP   #'A'
         BLT   ISNUM      ;Not alpha, check for num
         CMP   #'Z'+1
         BGE   NOTVARL    ;Branch if not a varl
         STZ   DIMFLG     ;It is a variable
         STA   VARNAM
         STZ   VALTYP
         STZ   INTFLG
         LDX   #0
]LUP     INCD  TXTPTR
         LDA   (TXTPTR)   ;Inline CHRGET for speed
         CMP   #' '
         BEQ   ]LUP
         EOR   #'0'
         CMP   #10
         EOR   #'0'
         JSR   $E00A      ;Call PTRGET in middle
         STA   VPNT       ;Var ptr for string
         STY   VPNT+1
         STA   INDEX      ; & for other usage
         STY   INDEX+1
         LDX   VALTYP
         BNE   :STRING
         CLC
         XCE
         REP   %00100000
         LDX   INTFLG
         BMI   :INT
         LDY   #3
         LDA   (INDEX),Y  ;Get variable value
         STA   FAC+3      ; and unpack into FAC
         LDY   #1
         LDA   (INDEX),Y
         STA   FACSGN
         ORA   #$80
         STA   FAC+1
         XCE
         DEY
         LDA   (INDEX)
         STA   FAC
:STRING  STZ   EXTRAFAC
         RTS

:INT     LDA   (INDEX)
         XBA
         TAY
         XBA
         XCE
         JMP   GIVAYF

* Process unary operators (functions):

UNARY    CMP   #peek
         BGE   :OLDU
         CMP   #sqr
         BLT   :OLDU
         ASL
         PHA
]LUP     INCD  TXTPTR
         LDA   (TXTPTR)
         CMP   #' '
         BEQ   ]LUP
         JSR   PARCHK     ;Check syntax & eval argnt
         PLX              ;Retrieve token*2
         JMP   (UNFNC-$B4,X) ;$B4 = sqr*2

:OLDU    JMP   $DF0C

*=================================================

UNFNC    DA    SQR
         DA    RND
         DA    LOG
         DA    EXP
         DA    COS
         DA    SIN
         DA    TAN
         DA    ATN

MATHTBL  HEX   79         ;Preferences
         DA    FADDT-1    ; and routine addresses
         HEX   79
         DA    FSUBT-1
         HEX   7B
         DA    FMULTT-1
         HEX   7B
         DA    FDIVT-1
         HEX   7D
         DA    FPWRT-1
         HEX   50
         DA    AND-1
         HEX   46
         DA    OR-1
MINUS    HEX   7F
         DA    NEGOP-1
UNOT     HEX   7F
         DA    EQUOP-1
PLUS     HEX   64
         DA    POSOP-1

*=================================================

INT      =     $EC23
OR       =     $DF4F
AND      =     $DF55

*================================================

EXP0     JMP   $E850      ;0^A

FPWRT    BEQ   EXP        ;A^0 done as e^0
         LDA   ARG
         BEQ   EXP0
         LDX   #TEMP3
         LDY   #0
         JSR   MOVMF      ;Store at TEMP3
         LDA   ARGSGN
         BPL   :P1        ;Branch if argument is +
         JSR   INT        ;Get INT part of exponent
         LDA   #TEMP3
         LDY   #0
         JSR   FCOMP      ;Is it an integer power?
         BNE   :P1
         TYA              ;If so, allow neg argument
         LDY   CHARAC     ;Get parity (from INT)
:P1      JSR   MFA        ;Move argument to FAC
                          ;Least signif bit can be set
         PHY              ; only from the LDY CHARAC
         JSR   LOG        ;Get LOG(argument)
         LDA   #TEMP3
         LDY   #0
         JSR   CONUPK
         JSR   FMULTT     ;Compute expon*LOG(argum)
         JSR   EXP        ;Raise to e-th power
         PLA              ;Was exponent a negative
         LSR              ; odd integer?
         BCC   :RND       ;Return if not
         JSR   NEGOP      ;Negate FAC if so
:RND     JMP   RNDB

FUNCTION MAC
         LDX   #]1
         BRA   DOFUNCT
         <<<

LOG      LDX   #$14
         LDA   FAC
         BEQ   IQ
         HEX   2C
SQR      LDX   #$04
         LDA   FACSGN
         BPL   DOFUNCT
IQ       JMP   IQERR

COS      FUNCTION $1D
SIN      FUNCTION $0E
TAN      FUNCTION $0F
ATN      FUNCTION $0A
EXP      LDX   #$10
DOFUNCT  CLC              ;Send unary function to FPE
         XCE
         LDY   #$89
         BRA   BIN2

*------------------------------------

FSUBT    =     $E7AA
FADDT    =     $E7C1      ;+ and - done normally

ZFAC     STZ   FAC
RET      RTS

BY0      JMP   DIVERR

FDIVT    BEQ   BY0        ;/ and * sent to FPE
         LDX   #$20
         BRA   DOBINARY

FMULTT   BEQ   RET
FMULT    LDX   #$23
DOBINARY LDA   ARG
         BEQ   ZFAC
         CLC              ;Entry for binary ops
         XCE
         REP   %00110000
         LDA   #$48       ;Move to reg0
         STA   BASE+8     ;Command
         SEP   %00110000
         LDA   ARGSGN
         XBA
         LDA   ARG        ;Combine sign and exp
         REP   %00110001
         AND   #$80FF     ;Mask unused exp bits
         ADC   #$3F7E     ; and adjust AS exp to
         XBA              ; FPE exp
         LDY   #$89
]LUP     CPY   BASE       ;Response
         BEQ   ]LUP
         STA   BASE+$C
         STZ   BASE+$E
         LDA   ARG+1
         STA   BASE+$C
         LDA   ARG+3
         STA   BASE+$E
         STZ   BASE+$C
         STZ   BASE+$E
         LDA   #%10000000
]LUP     AND   BASE
         BNE   ]LUP
         SEP   %00110000  ;Entry for unary functions
BIN2     TXA              ;Instruction
         XBA
         LDA   #$48       ;Operate FAC,reg0 to reg0
         REP   %00110000
         STA   BASE+8     ;Command
         SEP   %00110000
         LDA   FACSGN
         XBA
         LDA   FAC        ;Combine sign and exp of FAC
         REP   %00110001
         BNE   :NZ
         STZ   FAC
         STZ   FAC+2
         STZ   FAC+4
         STZ   EXTRAFAC
         LDA   FAC
         BRA   :OV

:NZ      AND   #$80FF     ;Mask out garbage
         ADC   #$3F7E     ;Convert AS exp to FPE exp
         XBA
:OV      CPY   BASE       ;Response
         BEQ   :OV
         STA   BASE+$C
         STZ   BASE+$E
         LDA   FAC+1
         STA   BASE+$C
         LDA   FAC+3
         STA   BASE+$E
         LDA   EXTRAFAC
         STA   BASE+$C
         STZ   BASE+$E
         LDA   #%10000000
]LUP     AND   BASE
         BNE   ]LUP
DOWNLOAD LDA   #$68       ;Move from reg0 command
GETREG   STA   BASE+8
]LUP     CPY   BASE       ;Response
         BEQ   ]LUP
         LDA   BASE+$C
         STA   FACSGN     ;Set sign
         XBA
         ASL              ; and kill sign
         LSR
         TAY              ; leaving exponent
         ADC   #$82       ;Adjust to AS exponent
         STA   FAC
         LDA   BASE+$E
         LDA   BASE+$C
         STA   FAC+1
         LDA   BASE+$E
         STA   FAC+3
         LDA   BASE+$C
         STA   EXTRAFAC
         LDA   BASE+$E
         CPY   #$407E     ;Check if exp too big for AS
         LDA   #%10000000
]LUP     AND   BASE
         BNE   ]LUP
         BGE   OVRFLO
         CPY   #$3F7E     ; or too small
         BGE   RTN
         STZ   FAC        ;Zero FAC in latter case
         SEC
RTN      XCE
RTN1     RTS

*=================================================
* Fast random number generator LCG type (2^16+5)
*-------------------------------------------------

RND      CLC
         XCE
         REP   %00100000
         LDA   FAC+4
         STA   ARG+4
         LDA   FAC+2
         STA   ARG+2
         LDA   FAC
         STA   ARG
         TAX
         BEQ   LS         ;RND(0) = use current FAC
         LDY   FACSGN
         BPL   LS         ;Branch on RND(+)
         SEP   %00110000
         STZ   FACSGN     ;RND(-X) = use X for seed
         JSR   ATN        ;To make RND(-integer) seed
         CLC              ; a more mixed up bit stream
         XCE
         BRA   R1

OVRFLO   XCE
OVRFLOW  JMP   OVERFLOW

LS       LDA   SEED+1     ;Get seed to FAC
         STA   FAC+1
         LDA   SEED+3
         STA   FAC+3
         TXA              ;Recall sign
         BEQ   ROUND      ;Skip if RND(0)
R1       REP   %00110000
         LDA   FAC+3
         STA   SEED+3     ;Seed * 2 to fac
         ASL   FAC+3
         LDA   FAC+1
         STA   SEED+1
         ROL
         SEC              ;To add 1
         ROL   FAC+3      ;Seed * 4 + 1
         ROL
         TAX
         CLC
         LDA   FAC+3
         ADC   SEED+3
         STA   FAC+3
         TAY
         TXA
         ADC   SEED+1
         CLC              ;Seed * 5 + 1 + seed * 2^16
         ADC   SEED+3     ; = seed * (2^16+5) + 1
         STA   SEED+1
         STA   FAC+1
         STY   SEED+3
ROUND    SEC
         XCE
         LDA   #$80
         STA   FAC        ;Normalize < 1
         STZ   EXTRAFAC
         STZ   FACSGN
         JSR   SIGNIF     ;Float
         LDA   ARG
         BEQ   RTN1       ;Done if RND(0)
         LDX   ARGSGN
         BMI   RTN1       ; or RND(-)
         CLC
         XCE
         REP   %00100000
         LDA   ARG
         EOR   #$8081
         ORA   ARG+2
         BEQ   RTN        ;C is set.  Done if RND(1)
         JSR   FMULT      ;Times X if RND(X), X not 1
         LDX   #3         ;Integer part command
         JMP   DOFUNCT    ;=INT(RND(1)*X) if X not 1

         MX    %11

*===============================
* Decimal ascii to fp converter:
*-------------------------------

OVFLO    LDA   ESGN
         BPL   OVRFLOW    ;Error if overflow in exp
         STZ   FAC        ;Underflow, set to 0
         RTS

FIN      PHP
         CLC
         XCE
         REP   %00100000
         STZ   MANT
         STZ   MANT+2
         STZ   MANT+4
         STZ   MANT+6
         STZ   MANT+8     ;& EXPT
         STZ   ESGN       ;& SGNZ
         LDX   #-1
         STX   DP         ;Init dec pnt pointer
         LDY   #%01010101
         STY   PARITY
         LDY   #-1
         STY   EXPON
         INX
         TXY
         XCE
         PLP
         BCS   :DP        ;Branch if '.' at start
:DIG     AND   #$F
         BNE   :X
         LDA   MANT
         BEQ   :IY
         LDA   #0
:X       ASL   PARITY     ;Carry = low nibble
         BCC   :OV
         INC   PARITY
         ASL
         ASL
         ASL
         ASL
         INX
:OV      CPX   #7
         BGE   :LE
         ORA   MANT,X     ;Add BCD digit
         STA   MANT,X
:LE      INC   EXPON
:IY      INY
]LUP     INCD  TXTPTR
         LDA   (TXTPTR)
         EOR   #'0'
         CMP   #10
         EOR   #'0'
         BCC   :DIG       ;Continue if digit
         EOR   #' '
         BEQ   ]LUP
         EOR   #'+'!' '   ;Ignore +
         BEQ   ]LUP
         EOR   #'-'!'+'
         BNE   :E
         ROR   SGNZ       ;Set negative sign
         BRA   ]LUP

:EDIG    AND   #$F
         STA   FAC
         LDA   EXPT       ;Compute explicit exponent
         CMP   #10
         BGE   OVFLO
         ASL
         STA   EXPT
         ASL
         ASL
         ADC   EXPT
         ADC   FAC
         STA   EXPT
         BRA   :EXP

:E       EOR   #'E'!'-'
         BEQ   :EXP
         EOR   #'.'!'E'
         BNE   :DONE
:DP      STY   DP         ;Set dec pnt pointer
         BRA   ]LUP

:RE      ROR   ESGN
:EXP     JSR   NEWGET
         BCC   :EDIG
         EOR   #'+'
         BEQ   :EXP
         EOR   #plus!'+'
         BEQ   :EXP
         EOR   #'-'!plus
         BEQ   :RE
         EOR   #minus!'-'
         BEQ   :RE
         BIT   ESGN
         BPL   :DONE
         LDA   #0
         SBC   EXPT       ;Negate exponent if had -
         STA   EXPT
         SEC
:DONE    LDA   DP         ; number of digits
         INC
         BEQ   :SDP       ;Branch if no explicit dp
         TYA
         SBC   DP         ;Else set exp defect
:SDP     STA   DP
         LDA   EXPON
         CLC
         ADC   EXPT       ;Exp difference
         SEC
         SBC   DP
         TAY
         BPL   :ADJ
         LDA   #%01000000
         TSB   SGNZ
         TYA
         EOR   #$FF       ;Correct amount of adjust
         INC
:ADJ     LDY   #-1
         SEC
]LUP     SBC   #10
         INY
         BCS   ]LUP
         ADC   #10
         STA   EXPON
         TYA
         ASL
         ASL
         ASL
         ASL
         TSB   EXPON
         CLC
         XCE
         REP   %00110000
         LDA   #$4C       ;Packed dec to reg 0
         STA   BASE+8
         LDA   SGNZ
         LDX   SGNZ+2
         LDY   #$89
]LUP     CPY   BASE       ;Response
         BEQ   ]LUP
         STA   BASE+$C    ;Send 96 bit packed dec #
         STX   BASE+$E
         LDA   SGNZ+4
         STA   BASE+$C
         LDA   SGNZ+6
         STA   BASE+$E
         LDA   SGNZ+8
         STA   BASE+$C
         LDA   SGNZ+10
         STA   BASE+$E
         LDY   #$89
         LDA   #%10000000
]LUP     AND   BASE
         BNE   ]LUP
         JMP   DOWNLOAD

START    CLC
         XCE
         STA   $C00B
         LDA   #$4C       ;Patch into CHRGET
         STA   CHRGOT+3
         LDA   FBITS+1
         AND   #%00001000
         BEQ   :S3        ;Branch if no @ parm
         LDA   VLINE      ;Get the @ parm
         BEQ   :KILL      ;Branch if @0
:S3      REP   %00100000
         LDA   #$C70B
         STA   ARG
         LDX   #7
]LUP     LDA   (ARG)
         CMP   #$AF01
         BEQ   :FOUND
         DEC   ARG+1
         DEX
         BNE   ]LUP
:KILL    SEP   %00110000
         LDA   #$C9
         STA   CHRGOT+3   ;Fix CHRGET if @0
         REP   %00100000
         LDA   #$B03A
         BRA   :SC

:FOUND   TXA
         ASL
         ASL
         ASL
         ASL
         ORA   #$C080     ;Plus base
         STA   ARG        ;Save for temp use
         REP   %00110000
         LDX   #FPEEND-FPESTART
]LUP     LDA   FPESTART,X ;Check for bytes FFFX
         TAY
         ORA   #$F        ;This could go bad!
         INC
         BNE   :NEXT
         TYA              ;If FFFX found,
         AND   #$F        ; then get the X
         ORA   ARG        ; and add base giving
         STA   FPESTART,X ; C080+X0
:NEXT    DEX
         BPL   ]LUP
         STZ   BASE+6     ;Restore FPE
         LDA   BASE+6
         LDA   #LOOK      ;Patch rest of CHRGET
:SC      STA   CHRGOT+4
         SEC
         XCE
         STA   $C00A
         RTS

*=================================================

         DS    1

CMDTABLE DFB   fln1*2     ;TAB(
         DFB   fmove*2    ;TO
         DFB   fcosh*2    ;FN
         DFB   fexp1*2    ;SPC(
         DFB   $00        ;THEN
         DFB   fatnh*2    ;AT
         DFB   fneg*2     ;NOT
         DFB   fasin*2    ;STEP
         DFB   fadd*2     ;PLUS
         DFB   fsub*2     ;-
         DFB   fmult*2    ;*
         DFB   fdiv*2     ;/
         DFB   fpwr10*2   ;^
         DFB   flog10*2   ;AND
         DFB   fsincos*2  ;OR
         DFB   fmant*2    ;>
         DFB   fcmp*2     ;=
         DFB   fexpon*2   ;<
         DFB   ftst*2     ;SGN
         DFB   fint*2     ;INT
         DFB   fabs*2     ;ABS
         DFB   fpwr2*2    ;USR
         DFB   flog2*2    ;FRE
         DFB   fscale*2   ;SCRN
         DFB   fmod*2     ;PDL
         DFB   facos*2    ;POS
         DFB   fsqr*2     ;SQR
         DFB   fround*2   ;RND
         DFB   flog*2     ;LOG
         DFB   fexp*2     ;EXP
         DFB   fcos*2     ;COS
         DFB   fsin*2     ;SIN
         DFB   ftan*2     ;TAN
         DFB   fatn*2     ;ATN
         DFB   fsinh*2    ;PEEK
         DFB   ftanh*2    ;LEN

*=================================================

FPEEND
         ERR   *&*&$FF
