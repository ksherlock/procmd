******************************
*                            *
*    "RDLINE" BASIC CMD      *
*                            *
*  Glen E. Bredon   2/22/87  *
*                            *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"
         EXP            OFF
         TR
         TR             ADR
         DO             SAVOBJ
         DSK            OBJECT/RDLINE.CMD
         FIN

LEN      =              $D0                       ;String length
OFFSET   =              $D1                       ;Offset in buffer
INSFLG   =              $D2
ARROWFLG =              $D3
DFLTLEN  =              $D4

DFPNT    =              $E0
CURSOR   =              $E2

IN       =              $200
STRING   =              IN                        ;Must use input buffer
DEFAULT  =              $240
TEMPLATE =              $2C0
KEY      =              $C000
STROBE   =              $C010
COUT     =              $FDED

* Applesoft stuff:

A1L      =              $3C
VALTYP   =              $11
FORPNT   =              $85
CHRGET   =              $B1
CHRGOT   =              $B7

INLIN    =              $D52C
PUTSTR   =              $DA7B
OUTDO    =              $DB5C
SYNERR   =              $DEC9
PTRGET   =              $DFE3
STRSPA   =              $E3DD
PUTNEW   =              $E42A
MOVSTR   =              $E5E2

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parms, 0 = none (2 bytes)
XRETURN  =              $BE9E                     ;RTS (for dos cmd linking)
MONRTS   =              $FFCB                     ;RTS (for & linking)

* Token:

input    =              132

         AST            50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP            PARSE                     ;These two jumps let RELOC
DOSEXIT  JMP            XRETURN                   ; daisy chain commands
AMPEXIT  JMP            MONRTS                    ;This daisy chains & cmds
AMPENTRY BNE            AMPER                     ;Other & cmds to next rout
         LDY            #AMPNAME-AMPEND-1
:SN      LDA            AMPEND-$FF,Y              ;Show our "list" of cmds
         JSR            COUT                      ;If all modules have this
         INY                                      ; routine then &<RTN> will
         BNE            :SN                       ; give list of all dos cmds.
BACK     JSR            CHRGOT                    ;Reestablish A and status
         JMP            AMPEXIT                   ;Go to next routine (always)
RTN      RTS

* Signature = 32 = JSR:

POINT    JSR            CHRGET                    ;Point to 1st char of varl
         JSR            PTRGET                    ;Get string pointer
         LDX            VALTYP
         INX
         STX            OFFSET                    ;Zero for both cmd and &
         BEQ            RTN                       ;Err if not string
         JMP            SYNERR

AMPER    EOR            #input                    ;&INPUT?
         BNE            BACK                      ;Exit if not
         JSR            POINT                     ;Get string pointer
         STA            FORPNT
         STY            FORPNT+1
         JSR            INLIN                     ; and input, leaves X=-1
]LUP     INX                                      ; and strips high bits
         LDA            IN,X                      ; and puts 0 at end
         BNE            ]LUP
         TXA                                      ;=length
         JMP            MAKIT                     ;Move the string

PARSE    LDX            #CMDEND-CMDNAME
:ISIT    LDA            IN-1,X
         AND            #%11011111
:FUNNY   EOR            CMDNAME-1,X
:BDOSEX  SEC                                      ;In case we exit here
         BNE            DOSEXIT                   ;Support daisy chain
         DEX
         BNE            :ISIT
         STX            XCNUM                     ;Signal external cmd
         STX            PBITS                     ;and no parameters
         STX            PBITS+1
         LDA            #START
         STA            XTRNADDR
         LDA            #>START
         STA            XTRNADDR+1
         LDY            #CMDEND-CMDNAME-1
         LSR            ARROWFLG
:GETTEM  JSR            GETIN
         BEQ            :FUNNY                    ;Disallow empty template!
         CMP            #" "                      ;Bypass leading spaces
         BEQ            :GETTEM
         CMP            #"!"
         BNE            :SLOOP
         ROR            ARROWFLG
         BMI            :GETTEM
:SLOOP   CMP            #"~"
         BNE            :STEMP                    ;Branch if not lit flag
         JSR            GETIN
         BEQ            :FIN
         AND            #$7F                      ;Mask hi bit = not command
:STEMP   STA            TEMPLATE,X
         INX
         CPX            #$40
         BGE            :BDOSEX
         JSR            GETIN
         BNE            :SLOOP
:FIN     STY            XLEN
         LDA            #0
         STA            TEMPLATE,X                ;Signal end of template
         CLC                                      ;For ProDOS
         RTS

GETIN    INY
         LDA            IN,Y
         CMP            #$8D
         RTS

START    PLA                                      ;Comes back here
         TAX                                      ;Allow ProDOS to parse the
         PLA                                      ; string (setting TXTPTR)
         TAY                                      ; but force it to pass
         LDA            #>RDLINE-1                ; control back to us.
         PHA
         LDA            #RDLINE-1
         PHA
         TYA
         PHA
         TXA
         PHA
         CLC                                      ;Tell ProDOS all is well
         RTS

SETUNDER LDY            #0
]LUP     LDA            #"_"
         STA            DEFAULT,Y
         LDA            TEMPLATE,Y
         BEQ            :RET
         INY
         BNE            ]LUP
:RET     RTS

MVDFLT   TAY
         LDA            DFPNT+1
         BEQ            :AX
         TXA
         BEQ            :RET
:MUV     LDA            (DFPNT),Y
         STA            DEFAULT,Y
         INY
         DEX
         BNE            :MUV
:RET     RTS
:AX      TAX
         RTS

STOREOUT JSR            OUTDO
         STA            DEFAULT,X
GETDFLT  LDA            DEFAULT,X
STORESTR AND            #$7F
         STA            STRING,X
         ORA            #$80
         RTS

STSTR    JSR            STORESTR
OUT      JSR            OUTDO
         INX
GOEND    LDA            TEMPLATE,X
         BEQ            :RET
         JSR            ISCHAR
         BNE            STSTR
         JSR            GETDFLT
         CMP            #"_"
         BNE            OUT
         STX            LEN
:LEND    INX
         LDA            TEMPLATE,X
         BEQ            :HAVEN
         JSR            GETDFLT
         CMP            #"_"
         BEQ            :LEND
         BNE            OUT
:HAVEN   LDX            LEN
:RET     RTS

SETCUR   PHA
         LSR            INSFLG
         LDA            #""
         STA            CURSOR
         PLA
         RTS

RDLINE   JSR            SETCUR
         JSR            POINT
         STA            FORPNT
         STY            FORPNT+1
         LDX            #0
         STX            DFPNT+1
         JSR            CHRGOT
         CMP            #','
         BNE            MAIN0
         JSR            POINT
         STA            DFPNT
         STY            DFPNT+1
         LDY            #0
         LDA            (DFPNT),Y
         TAX
         INY
         LDA            (DFPNT),Y
         PHA
         INY
         LDA            (DFPNT),Y
         STA            DFPNT+1
         PLA
         STA            DFPNT
MAIN0    STX            DFLTLEN
MAINLOOP JSR            SETUNDER
         LDX            DFLTLEN
         JSR            MVDFLT                    ;Sets X=0
:LUP     LDA            TEMPLATE,X
         BEQ            :BS
         JSR            ISCHAR                    ;Is it a command chr
         BNE            :OVER                     ;Print it if not
         LDA            DEFAULT,X                 ; else substitute fill char
:OVER    JSR            OUTDO
         INX
         BNE            :LUP

:BS      JSR            BACKSPC                   ;Backspace to 1st char
         DEX
         BNE            :BS
:GETINP  LDA            TEMPLATE,X
         BEQ            :GETKEY                   ;Wait for CR at end
         JSR            ISCHAR
         BEQ            :GETKEY                   ;Branch if a command
:OUTINP  JSR            STOREOUT                  ;Else put in string
         INX
         BNE            :GETINP

:GETKEY  TAY                                      ;Save command in Y
:KEY     JSR            CURKEY
         STX            LEN
         CMP            #"R"&$9F
         BNE            :I
         TXA
         BEQ            MAINLOOP
:BSP     JSR            BACKSPC
         DEX
         BNE            :BSP
         BEQ            MAINLOOP

:I       CMP            #"I"&$9F
         BNE            :ISCNT
         STA            INSFLG
         LDA            $FBC0
         AND            #$1F
         BEQ            :SCU
         LDA            #"|"
:SCU     STA            CURSOR
         BCS            :KEY

:ISCNT   CMP            #" "
         BGE            :AR
         JSR            SETCUR
:AR      BIT            ARROWFLG
         BPL            :N
         CMP            #"J"&$9F
         BEQ            :JAR
         CMP            #"K"&$9F
         BNE            :N
:JAR     JMP            :GOTINP
:N       CMP            #"N"&$9F
         BNE            :W
         JSR            GOEND
:GINP    JMP            :GETINP

:B       CMP            #"B"&$9F
         BNE            :PICK
         TXA
         BNE            :BS
         BEQ            :GINP

:W       CMP            #"W"&$9F
         BNE            :Q
]LUP     LDA            TEMPLATE,X
         BEQ            :GINP
         JSR            ISCHAR
         BNE            :OUTINP
         LDA            DEFAULT,X
         CMP            #"_"
         BEQ            :GINP
         JSR            STOREOUT
         INX
         CMP            #"0"
         BLT            :GINP
         CMP            #"9"+1
         BLT            ]LUP
         AND            #%11011111
         CMP            #"A"
         BLT            :GINP
         CMP            #"Z"+1
         BGE            :GINP
         BLT            ]LUP

:Q       CMP            #"Q"&$9F
         BNE            :B
]LUP     JSR            TEMCHAR
         BNE            :TERMED
         LDA            #"_"
         JSR            STOREOUT
         INX
         BNE            ]LUP
:TERMED  CPX            LEN
         BEQ            :INP
         JSR            BACKSPC
         DEX
         BPL            :TERMED

:PICK    CMP            #"U"&$9F
         BNE            :ISBS
         LDA            TEMPLATE,X
         BEQ            :INP
         LDA            DEFAULT,X
         ORA            #$80
         CMP            #"_"
         BNE            :ISBS
         LDA            #" "
:ISBS    CMP            #$88                      ;Process BS and DEL
         BEQ            :BAK
         CMP            #"D"&$9F
         BEQ            :DODEL
         CMP            #$FF
         BEQ            :DEL
         BNE            :ZRO

:DEL     TXA
         BEQ            :INP
         LDA            TEMPLATE-1,X
         JSR            ISCHAR
         BNE            :INP
         DEX
         JSR            BACKSPC
:DODEL   STX            LEN
]LUP     LDA            TEMPLATE+1,X
         JSR            ISCHAR
         BNE            :TERMED
         LDA            DEFAULT+1,X
         STA            DEFAULT,X
         JSR            OUTDO
         INX
         BNE            ]LUP

:BAK     JSR            LASTCHR                   ;Erase the cursor
:BAKUP   TXA
         BEQ            :INP
         JSR            BACKSPC                   ;And backspace
         DEX
         JSR            TEMCHAR                   ;Bypass formatting chars
         BNE            :BAKUP
:INP     JMP            :GETINP

:DASH    CPY            #"-"
         BNE            :UND
         CMP            #$8D                      ;Any non-cntrl or CR for -
         BEQ            :BGOT
:CONT    CMP            #" "
         BLT            :INP
:GOTKEY  BIT            INSFLG
         BPL            :OVSTR
         PHA
]LUP     JSR            OUTDO
         INX
         JSR            TEMCHAR
         BNE            :ENDINS
         LDA            DEFAULT-1,X
         BNE            ]LUP
:ENDINS  DEX
         JSR            BACKSPC
         CPX            LEN
         BEQ            :INSD
         LDA            DEFAULT-1,X
         STA            DEFAULT,X
         BGE            :ENDINS
:INSD    PLA
         STA            DEFAULT,X
:OVSTR   JMP            :OUTINP

:ZRO     CMP            #"["&$9F
         BEQ            :GOTINP
         CPY            #0                        ;At end of template
         BNE            :CAR                      ; accept only CR
         EOR            #$8D
:BGOT    BEQ            :GOTINP
                                                  ;Drop through illegal chr
:UND     CPY            #"_"
         BEQ            :CONT                     ;Non-cntrl (no CR) for _
         CPY            #"*"
         BEQ            :NUM                      ;Only numer for *
         CPY            #"#"
         BEQ            :ISSP                     ;Space or numer for #
         CPY            #"%"                      ; or %
         BNE            :C
:ISSP    CMP            #" "
:BEKEY   BEQ            :GOTKEY
:NUM     CMP            #"0"
         BLT            :INP
         CMP            #"9"+1
:BGOTK   BLT            :GOTKEY
:BGKEY   JMP            :GETINP

:CAR     CPY            #"^"
         BNE            :SLASH                    ;Accept FILENAMES for ^
         CMP            #"/"
         BEQ            :BGKEY
         BNE            :SL2
:SLASH   CPY            #"/"
         BNE            :DASH                     ; PATHNAMES for /
:SL2     CMP            #$8D
         BEQ            :GOTINP                   ;Always accept CR for these
         CMP            #"."
         BLT            :INP
         CMP            #"9"+1
         BLT            :GOTKEY
         LDY            #"A"                      ;Force alpha upshift
:C       CPY            #"a"                      ;Here cmd is AaBbCc
         BGE            :ISC                      ; so convert to UC
         CMP            #"A"                      ; if cmd is caps
         BLT            :ISC
         AND            #%11011111
:ISC     PHA
         TYA
         AND            #%11011111                ;Convert cmd to caps
         TAY
         PLA
         CPY            #"B"
         BLT            :ALPHA
         BEQ            :ISCR
         CMP            #" "
         BEQ            :BEKEY                    ;Accept spc and CR if C
:ISCR    CMP            #$8D                      ;Accept alpha and CR if B
         BEQ            :GOTINP
:ALPHA   PHA                                      ;Accept alpha only if A
         AND            #%11011111
         SEC
         SBC            #"A"
         CMP            #"Z"-"A"+1
         PLA
         BNE            :BGOTK                    ;Allow alpha only

:GOTINP  JSR            GOEND                     ;Now have input, leave last
         STX            LEN                       ; key for program to check!
         LDY            TEMPLATE,X
         JSR            LASTCHR
         TYA
         BEQ            :LX0
:CLEOL   LDA            TEMPLATE,X
         BEQ            :LX0
         JSR            ISCHAR
         BNE            :OUT
         LDA            #" "
:OUT     JSR            OUTDO
         INX
         BNE            :CLEOL
:LX0     TAX                                      ;=0
:LTE     LDA            TEMPLATE,X
         CMP            #"%"
         BNE            :NOTPER
         ROR            OFFSET                    ;Signal a %
         LDA            STRING,X
         CMP            #' '
         BNE            :MAKSTR                   ;If no spc then make str
:IX      INX
         BNE            :LTE                      ;Loop till no spcs at %
:NOTPER  JSR            ISCHAR                    ; and no formatting chars
         BNE            :IX
:MAKSTR  LDA            LEN                       ;Get input length
         BIT            OFFSET
         BPL            MAKIT                     ;Use it if no % cmds
         STX            OFFSET                    ;Save start offset
         SEC
         SBC            OFFSET                    ;And subtract it for len
MAKIT    JSR            STRSPA                    ;A=string len, make space
         LDX            OFFSET
         LDY            #>STRING
         JSR            MOVSTR                    ;Move to string space
         JSR            PUTNEW                    ;Create temp descriptor
         JMP            PUTSTR                    ;Move descriptor to var

TEMCHAR  LDA            TEMPLATE,X
ISCHAR   LDY            #CHAREND-CHARS-1
:LOOK    CMP            CHARS,Y
         BEQ            :RET                      ;Eq if a command char
         DEY
         BPL            :LOOK
:RET     RTS                                      ;Not eq if not a cmd

LASTCHR  LDA            #" "
         CPY            #0
         BEQ            OUTBACK                   ;Use spc if at templ end
         LDA            DEFAULT,X                 ; else print fill char
OUTBACK  JSR            OUTDO
BACKSPC  LDA            #$88                      ;Then backspace
         JMP            COUT

CURKEY   BIT            STROBE
:CURLUP  LDA            CURSOR
         BNE            :KW
         XC
         STA            $C00F
         PHX
         LDX            #3
]LUP     LDA            CURDATA,X
         JSR            COUT
         DEX
         BPL            ]LUP
         PLX
         XC             OFF
         LDA            #$8E
:KW      JSR            KEYWAIT
         LDA            TEMPLATE,X
         BEQ            :SPC
         LDA            DEFAULT,X
         HEX            2C
:SPC     LDA            #" "
         JSR            KEYWAIT
         BEQ            :CURLUP
         RTS

KEYWAIT  JSR            OUTBACK
         STA            A1L+1
]LUP     LDA            KEY
         BMI            :RET
         INC            A1L
         BNE            ]LUP
         INC            A1L+1
         BNE            ]LUP
:RET     RTS

CURDATA  HEX            985F8F9B

CHARS    ASC            "^/-_%#*AaBbCc"
CHAREND

AMPNAME  ASC            """
CMDNAME  ASC            "RDLINE"
CMDEND   ASC            ! template":A$[,default$]!
AMPEND   HEX            8D
