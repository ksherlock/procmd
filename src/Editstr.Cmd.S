*************-*-Mode:Merlin-*-***********
*                                       *
*           EDIT STRING Command         *
*              version 1.3              *
*                                       *
* Syntax: EDITSTR:X$ {,LL} {^#} {<>/}   *
*      X$= string variable to edit      *
*      LL= maximum input length         *
*      ^ = capitalize all input         *
*      # = numeric input only           *
*      < = left justify                 *
*      > = right justify                *
*      / = center                       *
*                                       *
*****************************************

*  This is an external command that may be connected with
*  BASIC.SYSTEM through ProDOS, to allow line editing of
*  strings in an Applesoft program.
*
*  The editing routines come from John Tierney's MMM.ML
*  package, which accompanies his MAUG.MSG.MGR program.
*  Here, they are converted from an & routine that loads
*  below the running program to an external command that
*  relocates itself below the ProDOS buffers, to make the
*  routines more accessible from your Applesoft program.
*
*  To use this source file, you need Merlin Pro to
*  assemble it and Glen Bredon's PROCMD package to
*  convert it to a self-relocating CMD file.
*
*  For instructions on using the CMD file, see the file
*  EDITSTR.DOC.
*
*  Version 1.1 - 27 Aug 87 - Add left, right, center
*                             justification
*
*                                         David W. Walker
*                                         CIS 73727,54

         REL
SAVOBJ   KBD
         DO             SAVOBJ
         DSK            OBJECT/EDITSTR.CMD
         FIN

         TR
         TR             ADR

* BASIC/Monitor zero-page variables

INVFLG   =              $32
FRETOP   =              $6F
VARPNT   =              $83

* Our zero-page variables

         DUM            $40

ZPSTRT

CHAR     DFB            0
OAFLG    DFB            0
INSFLG   DFB            0
UCFLG    DFB            0
JSTFLG   DFB            0                         ;0=left,$80=right,$40=cntr
CURSOR   DFB            0
STRLEN   DFB            0                         ;length of string variable
WIDTH    DFB            0                         ;screen width for edit
MAXLEN   DFB            0                         ;maximum edit line length
MRGN     DFB            0                         ;screen column to start input
POINT    DFB            0                         ;cursor in editing line
STRDSC   DA             0                         ;pointer to string descriptor
STRADR   DA             0                         ;address of string

ZPEND    ERR            ZPEND/$51

         DEND

* ASCII characters

CtrlB    =              $02
CtrlD    =              $04
BS       =              $08                       ;left arrow
TAB      =              $09
CR       =              $0D                       ;carriage return
CtrlN    =              $0E
CtrlQ    =              $11
CtrlR    =              $12
CtrlU    =              $15                       ;right arrow
CtrlX    =              $18
ESC      =              $1B
SPACE    =              $20
DELETE   =              $7F

QUOTE    =              $A2

* BASIC input processing

CHRGET   =              $00B1
CHRGOT   =              $00B7
TXTPTR   =              $00B8

* BASIC variables

IN       =              $0200
OURCH    =              $057B

* BASIC.SYSTEM globals

XTRNCMD  =              $BE50                     ;address of our main routine
CMDLEN   =              $BE52                     ;length of our command
XCNUM    =              $BE53                     ;always zero for extern cmd
PBITS    =              $BE54                     ;zero for no parse
XRETURN  =              $BE9E                     ;BASIC entry

* I/O locations

KEY      =              $C000
STROBE   =              $C010
SPKR     =              $C030
OAPPLE   =              $C061

* Applesoft internal routines

PTRGET   =              $DFE3                     ;find variable address
GETSPA   =              $E452                     ;make space for string
MOVSTR   =              $E5E2                     ;move string to (FRESPC)
GETBYT   =              $E6F8                     ;evaluate formula -> X

* Monitor routines

CROUT    =              $FD8E
COUT     =              $FDED
MONRTS   =              $FFCB

*===============================
* Command starts here
*===============================
DOSNTRY  JMP            PARSE                     ;entry from ProDOS
DOSEXIT  JMP            XRETURN                   ;chain to next command
AMPEXIT  JMP            MONRTS                    ;chain to next & routine

AMPNTRY  BNE            AMPEXIT                   ;pass on & commands

         LDY            #0                        ;& entry zero,
:LOOP    LDA            SYNTAX,Y                  ;..show command syntax
         BEQ            :EXIT
         JSR            COUT
         INY
         BNE            :LOOP
:EXIT    JSR            CHRGOT                    ;update TXTPTR, etc.
         BEQ            AMPEXIT

IDBYTE   DFB            32                        ;our ID byte

PARSE    LDX            #NAMEND-NAME-1            ;length of command name
         STX            CMDLEN                    ;pass to BASIC
         INX
         SEC                                      ;signal 'not our command'
:LOOP    LDA            IN-1,X                    ;get char from program
         AND            #%11011111                ;convert to U/C
         EOR            SYNTAX,X                  ;compare with command name
         BNE            DOSEXIT                   ;not our command, leave
         DEX                                      ;matched so far, try next char
         BNE            :LOOP

* Matched our command name - set up for BASIC 'parse'

         LDA            #<XEQ                     ;pass return addr to BASIC
         STA            XTRNCMD
         LDA            #>XEQ
         STA            XTRNCMD+1

         STX            XCNUM                     ;external command code
         STX            PBITS                     ;no parsing wanted
         STX            PBITS+1
         CLC
         RTS                                      ;back to BASIC

* Command syntax and name

SYNTAX   DFB            QUOTE
NAME     ASC            "EDITSTR"
NAMEND   DFB            QUOTE
         ASC            ":X$ {,LL} {^#} {<>/}"8D
         DFB            00

* Return here after BASIC 'parse'

XEQ      PLA                                      ;get BASIC's return addr
         TAX
         PLA
         TAY
         LDA            #>XEQ1-1                  ;push our address
         PHA
         LDA            #<XEQ1-1
         PHA
         TYA                                      ;re-push BASIC's address
         PHA
         TXA
         PHA
         CLC                                      ;signal 'no error'
         RTS                                      ;return to BASIC

* Return here from second trip to BASIC

XEQ1     LDX            #ZPEND-ZPSTRT             ;save zero-page
:LOOP    LDA            ZPSTRT-1,X
         PHA
         DEX
         BNE            :LOOP

         STX            UCFLG                     ;no upper-casing
         STX            MAXLEN                    ;default to full width
         STX            JSTFLG                    ;default to left justify

         LDA            #79
         STA            WIDTH                     ;init screen width

         LDA            OURCH                     ;start line at cursor
         STA            MRGN

         JSR            CHRGET                    ;gobble ':'
         JSR            GETPTRS                   ;get pointers to string

PARAMS   LDY            #$00                      ;look for parameters
         LDA            (TXTPTR),Y
         BEQ            SETUP                     ;end of input line

         CMP            #':'
         BEQ            SETUP                     ;end of statement

         CMP            #$CC                      ;"^" token
         BEQ            :UPCASE                   ;..uppercase input

         CMP            #'#'
         BEQ            :NUM                      ;numeric entry

         CMP            #$D1                      ;"<" token
         BEQ            :LEFT

         CMP            #$CF                      ;">" token
         BEQ            :RIGHT

         CMP            #$CB                      ;"/" token
         BEQ            :CENTER

         CMP            #','
         BEQ            :COMMA                    ;just skip over comma

         JSR            GETBYT                    ;get input max length
         CPX            WIDTH                     ;valid length?
         BCS            PARAMS                    ;..no, try again

         STX            MAXLEN                    ;..yes, save length spec
         CLV
         BVC            PARAMS

:LEFT    LDX            #0                        ;left justify
         HEX            2C                        ;dummy 'BIT'

:RIGHT   LDX            #$80
         HEX            2C

:CENTER  LDX            #$40
         STX            JSTFLG
         BNE            :COMMA

:UPCASE  LDX            #$FF                      ;uppercase input
         BNE            :SKIP
:NUM     LDX            #$7F                      ;numeric input
:SKIP    STX            UCFLG

:COMMA   JSR            CHRGET                    ;skip comma
         CLV
         BVC            PARAMS                    ;get next parameter

* Initialize string to edit

SETUP    LDA            MAXLEN                    ;get input length spec
         BEQ            :DFLT                     ;zero: use default length

         CLC                                      ;length given,
         ADC            MRGN                      ;..add starting column
         CMP            WIDTH                     ;..is there room?
         BCC            :FINISH                   ;...OK, do it

:DFLT    SEC                                      ;default to width
         LDA            WIDTH                     ;..minus margin
         SBC            MRGN
         STA            MAXLEN

:FINISH  JSR            CPYSTR                    ;copy default string

         LDA            #$FF
         STA            INSFLG                    ;overwrite mode

         LDA            #$00
         STA            POINT                     ;start at beginning of line

         JSR            PREOL

* Get input char and process

INPUT    JSR            INVCRSR                   ;highlight char under crsr

:KEYIN   LDA            KEY                       ;get keystroke
         BPL            :KEYIN
         LDX            OAPPLE                    ;check for Open-Apple pressed
         BIT            STROBE

         AND            #$7F                      ;clear high bit

         BIT            UCFLG                     ;uppercase line?
         BPL            :PROCES                   ;no, just process

         CMP            #'a'
         BCC            :PROCES
         CMP            #'z'+1
         BCS            :PROCES
         AND            #%11011111                ;convert to U/C

:PROCES  STA            CHAR
         STX            OAFLG
         JSR            NRMCRSR
         LDA            OAFLG                     ;get Open-Apple state
         AND            #$80                      ;isolate high bit
         ORA            CHAR                      ;combine with char
         STA            CHAR

         BMI            CTRLS                     ;high bit set = OA pressed

         CMP            #$20
         BCC            CTRLS                     ;control char

         CMP            #$7F
         BEQ            CTRLS                     ;'delete' char

         LDX            UCFLG
         BEQ            :SKIP                     ;0 = upper-case input
         BMI            :SKIP                     ;neg = normal input

         CMP            #'0'                      ;pos. = numeric entry
         BCC            BADKEY
         CMP            #'9'+1
         BCS            BADKEY

:SKIP    LDY            INSFLG                    ;insert mode?
         BEQ            :INSRT                    ;..yes, insert char

         LDX            POINT                     ;..no, overwrite at point
         LDA            IN,X
         BNE            :WRT                      ;..except at end of line

         STA            INSFLG                    ;end of line, insert

:INSRT   JSR            INSERT
         CLV
         BVC            INPUT                     ;..loop for more

:WRT     LDA            CHAR
         STA            IN,X
         JSR            PRLINE
         INC            POINT

GOBACK   CLV
         BVC            INPUT                     ;loop for more

* Process control chars

CTRLS    EOR            #TAB                      ;Tab char?
         BNE            :SET

         STA            INSFLG                    ;Clear overwrite flag
         BEQ            INPUT

:SET     LDX            #$FF                      ;set overwrite flag
         STX            INSFLG

:SCANLP  INX                                      ;scan list of ctrl chars
         LDA            CMDKYS,X
         BEQ            BADKEY
         CMP            CHAR
         BNE            :SCANLP

* Exit through ctrl-char routine

         TXA
         ASL
         TAX
         LDA            #>INPUT-1
         PHA
         LDA            #INPUT-1
         PHA
         LDA            ADRSTBL+1,X
         PHA
         LDA            ADRSTBL,X
         PHA
         LDA            #0
         RTS

* Click for bad input

BADKEY   JSR            CLICK
         CLV
         BVC            GOBACK

* Clear line and exit (ESC)

ESCAPE   JSR            CLRLN
         JSR            NRMCRSR
         JSR            PRLINE
         LDA            #$1C                      ;Ctrl-\ flag
         STA            IN
         LDA            #$00
         STA            IN+1
         JSR            STOSTR
         BNE            EDXIT                     ;Always

* Clear line from cursor and exit (Ctrl-Q)

CUTOFF   JSR            CLREOL                    ;show edited line

* Finish line and exit (Return)

RETURN   JSR            NRMCRSR
         JSR            PRLINE
         JSR            STOSTR                    ;store in string
         JSR            CROUT                     ;print carriage return

EDXIT    PLA
         PLA
         LDX            #ZPSTRT-ZPEND             ;restore zero-page contents
]LOOP    PLA
         STA            ZPEND&$FF,X
         INX
         BMI            ]LOOP
         RTS                                      ;..end exit routine

* Insert char at point

INSERT   LDA            JSTFLG
         BEQ            :LFT                      ;zero = normal (left) justify

         JSR            DELSPC                    ;right or center, make room

:LFT     JSR            GETLEN

         CPX            MAXLEN
         BCS            CLICK

         INX
:LOOP2   DEX
         LDA            IN,X
         STA            IN+1,X
         CPX            POINT
         BNE            :LOOP2

         LDA            CHAR
         STA            IN,X

:EXIT    JSR            PREOL
         INC            POINT
         RTS

* Get length of string in X

GETLEN   LDX            #$FF
]LOOP    INX                                      ;find zero-byte at end
         LDA            IN,X
         BNE            ]LOOP
         RTS

* Sound a short click (bad key)

CLICK    LDX            #$0A
:BUZZ    LDY            #$20
         LDA            SPKR
:CLIK    DEY
         BNE            :CLIK
         DEX
         BNE            :BUZZ
         RTS

* Delete char before point (Delete)

DELLFT   LDX            POINT
         BEQ            CLICK
         DEC            POINT
         DEX

:LOOP    INX
         LDA            IN,X
         STA            IN-1,X
         BNE            :LOOP

         BEQ            PREOL

* Delete char at point (Ctrl-D)

DELCHR   LDX            POINT
         LDA            IN,X
         BEQ            CLICK
         DEX

:LOOP    INX
         LDA            IN+1,X
         STA            IN,X
         BNE            :LOOP

* Print changed line

PREOL    LDA            JSTFLG
         BEQ            :COMMON                   ;left justified
         BMI            :RT                       ;right justified
         JSR            CJ1
         JMP            :COMMON

:RT      JSR            RJ1

:COMMON  JSR            PRLINE

         LDA            #SPACE!$80                ;clear to end of line
:LOOP    JSR            COUT
         INX
         CPX            MAXLEN
         BCC            :LOOP

         RTS

* Move point left (Ctrl-H)

LEFT     LDA            POINT
         BEQ            CLICK                     ;beginning of line, click
         DEC            POINT
         RTS

* Move point to the right (Ctrl-U)

RIGHT    LDX            POINT
         LDA            IN,X
         BEQ            CLICK                     ;end of line, click
         INC            POINT
         RTS

* Move point to beginning of line (Ctrl-B)

MVBGN    STA            POINT
         RTS

* Move point to end of line (Ctrl-N)

MVEOL    JSR            GETLEN
         STX            POINT
         RTS

* Clear line (Ctrl-X)

CLRLN    STA            POINT                     ;Point to line start

CLREOL   JSR            GETLEN
         TXA                                      ;at end of line, just quit
         BEQ            :EXIT
         SEC
         SBC            POINT
         TAX
         SEC
         LDA            MRGN                      ;set cursor at point
         ADC            POINT
         STA            CURSOR

:LOOP1   LDA            #$A0                      ;clear to end of line
         JSR            CHROUT
         DEX
         BNE            :LOOP1
         TXA
         LDX            POINT                     ;terminate line at point
         STA            IN,X
:EXIT    RTS

* Restore original line (Ctrl-R)

RESTORE  JSR            CLRLN
         JSR            CPYSTR

* Left justify line (OA-,)

LJUST    LDX            #0
         STX            JSTFLG                    ;clear justification flag
         LDA            IN,X
         BEQ            :EXIT

:LOOP    JSR            DELSPC                    ;delete leading spaces
         BEQ            :LOOP

:EXIT    JMP            PREOL                     ;show justified line

* Delete first char if it is a space

DELSPC   LDX            #0
         LDA            IN,X
         CMP            #SPACE                    ;is it a space?
         BNE            :EXIT                     ;..no, leave with Z flag clear

         LDA            POINT                     ;move point left, unless it's
         BEQ            :OK                       ; at first position already
         DEC            POINT

:OK      DEX                                      ;adjust X for next INX

:LOOP    INX
         LDA            IN+1,X
         STA            IN,X
         BNE            :LOOP                     ;done, exit with Z flag set

:EXIT    RTS

* Right justify line (OA-.)

RJUST    LDX            #$80
         STX            JSTFLG                    ;set right just'n flag
         JSR            RJ1
         JMP            PREOL

RJ1      JSR            INSSPC                    ;insert spaces to fill line
         BNE            RJ1
         RTS

* Insert space at beginning of line

INSSPC   JSR            GETLEN                    ;Sets A=0

         CPX            MAXLEN                    ;room for insertion?
         BCC            :ROOM                     ;..yes, go on
         TAX
         RTS                                      ;..no, exit with Z flag set

:ROOM    INC            POINT                     ;keep point on same char

         INX
:LOOP2   DEX                                      ;make room for char
         LDA            IN,X
         STA            IN+1,X
         TXA
         BNE            :LOOP2

         LDA            #SPACE
         STA            IN
         RTS                                      ;exit with Z flag clear

* Center line (OA-/)

CJUST    LDX            #$40                      ;set Center flag
         STX            JSTFLG
         JSR            CJ1
         JMP            PREOL

CJ1      JSR            DELSPC                    ;delete any leading spaces
         BEQ            CJ1

         JSR            GETLEN

         TXA
         EOR            #$FF                      ;subtract len from MAXLEN
         SEC
         ADC            MAXLEN
         BEQ            :EXIT                     ;equal, no padding needed

         CLC                                      ;else divide by 2
         LSR
         TAY

:LOOP2   JSR            INSSPC                    ;..and insert that many spaces
         DEY
         BNE            :LOOP2

:EXIT    RTS

* Print whole line to screen

PRLINE   LDA            MRGN
         STA            CURSOR
         STA            OURCH

         LDX            #$FF                      ;print IN buffer to screen
]LOOP    INX
         LDA            IN,X
         BEQ            :EXIT
         JSR            CHROUT
         CLV
         BVC            ]LOOP
:EXIT    RTS

* Print inverse char at cursor

INVCRSR  LDA            #$7F                      ;set inverse
         STA            INVFLG

* Print normal char at cursor

NRMCRSR  LDA            MRGN
         CLC
         ADC            POINT
         STA            CURSOR
         LDX            POINT
         LDA            IN,X
         BNE            :SKIP
         LDA            #$20
:SKIP    JSR            CHROUT
         LDA            #$FF                      ;set normal
         STA            INVFLG
         RTS

* Print char in Acc to screen

CHROUT   PHA                                      ;save char
         JSR            :SETCH
         INC            CURSOR                    ;increment CH
         PLA                                      ;recall char
         ORA            #$80                      ;set high bit
         JSR            COUT                      ;print to screen
:SETCH   LDA            CURSOR                    ;get new CH
         STA            OURCH
         RTS

* Get pointers to string variable

GETPTRS  JSR            PTRGET
         LDY            #$00
         LDA            (VARPNT),Y                ;get string length
         STA            STRLEN
         INY
         LDA            (VARPNT),Y                ;get string address
         STA            STRADR
         INY
         LDA            (VARPNT),Y
         STA            STRADR+1

         LDA            VARPNT                    ;save pointer to descriptor
         STA            STRDSC
         LDA            VARPNT+1
         STA            STRDSC+1
         RTS

* Copy string to IN buffer

CPYSTR   LDA            MAXLEN
         CMP            STRLEN
         BCS            :MAX
         STA            STRLEN
:MAX     LDY            #$FF
]LOOP    INY
         CPY            STRLEN
         BEQ            ENDSTR
         LDA            (STRADR),Y
         STA            IN,Y
         CLV
         BVC            ]LOOP

ENDSTR   LDA            #$00
         STA            IN,Y
         RTS

* Store string in free memory

STOSTR   JSR            GETLEN
         STX            STRLEN
         TXA
         JSR            GETSPA                    ;get space for line
         LDX            #<IN
         LDY            #>IN
         JSR            MOVSTR                    ;move string to variable
         LDY            #$00
         LDA            STRLEN                    ;update string descriptor
         STA            (STRDSC),Y
         INY
         LDA            FRETOP
         STA            (STRDSC),Y
         LDA            FRETOP+1
         INY
         STA            (STRDSC),Y
         RTS

* Pointers to ctrl-char routines

ADRSTBL  DA             CUTOFF-1
         DA             RETURN-1
         DA             RESTORE-1
         DA             MVBGN-1
         DA             MVEOL-1
         DA             DELCHR-1
         DA             DELLFT-1
         DA             LEFT-1
         DA             RIGHT-1
         DA             CLRLN-1
         DA             ESCAPE-1
         DA             LJUST-1
         DA             CJUST-1
         DA             RJUST-1

* Control chars

CMDKYS   DFB            CtrlQ                     ;Ctrl-Q
         DFB            CR                        ;Return
         DFB            CtrlR                     ;Ctrl-R
         DFB            CtrlB                     ;Ctrl-B
         DFB            CtrlN                     ;Ctrl-N
         DFB            CtrlD                     ;Ctrl-D
         DFB            DELETE                    ;Delete
         DFB            BS                        ;Left-arrow
         DFB            CtrlU                     ;Right-arrow
         DFB            CtrlX                     ;Ctrl-X
         DFB            ESC                       ;Esc
         DFB            ","                       ;Open-Apple comma
         DFB            "/"                       ;Open-Apple slash
         DFB            "."                       ;Open-Apple period

         BRK                                      ;end of table
