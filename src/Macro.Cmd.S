********************************
*                              *
*     MACRO  BASIC COMMAND     *
*                              *
*    Glen Bredon     1/4/85    *
*                              *
********************************

         DATE

         EXP            OFF

         TR

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/MACRO.CMD
         FIN

* ProDOS BASIC interp locations:

INVEC    =              $BE32
XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters, 0 = none (2 bytes)
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

         AST            50

PNT      =              $1A
BASL     =              $28
MEMTOP   =              $73
CHRGOT   =              $B7
IN       =              $200
KEY      =              $C000
STROBE   =              $C010
BUTT0    =              $C061
BUTT1    =              $C062
COUT     =              $FDED

         AST            50

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

         AST            50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP            PARSE                     ;These two jumps permit RELOC
DOSEXIT  JMP            XRETURN                   ; to daisy chain commands
AMPEXIT  JMP            MONRTS                    ;This one to daisy chain & cmds
AMPENTRY BNE            AMPEXIT                   ;Other & cmds to next routine
         LDY            #0
:SN      LDA            CMDNAME,Y
         JSR            COUT
         INY
         CPY            #AMPEND-CMDNAME
         BLT            :SN
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            13                        ;Signature

* Pointers for use be macro table editing program:

         DA             MACTBL-DOSENTRY+$4100
         DFB            0,>ENDMOD-DOSENTRY+$4100
OLDVEC   DA             $FD1B                     ;Existing vector put here

CMDNAME  ASC            "MACRO"
CMDEND   HEX            8D
AMPEND

PARSE    LDX            #CMDEND-CMDNAME-1
         STX            XLEN
         INX
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
         SEC                                      ;In case mismatch here
         BNE            DOSEXIT
         DEX                                      ;Carry is set
         BNE            :ISIT
         STX            XCNUM                     ;Signal external cmd
         STX            PBITS                     ; and no parms
         STX            PBITS+1
         STADR          START;XTRNADDR
         STX            MACSTATE                  ;Defeat mac mode
         STX            PNT
         CLC
         RTS

START    PLA
         TAY
         PLA
         TAX
         LDA            #>CONT-1
         PHA
         LDA            #CONT-1
         PHA
         TXA
         PHA
         TYA
         PHA
         CLC
         RTS

DATA     ASC            "EDIT"

CALLOLD  JMP            (OLDVEC)

CONT     PHA                                      ;Must preserve all registers
         STY            YSAV                      ; for unknown reason
         LDY            INVEC
         LDA            INVEC+1
         CPY            #KEYIN
         BNE            :SETV
         CMP            #>KEYIN
         BEQ            EXIT
:SETV    STY            OLDVEC                    ;Set to call existing
         STA            OLDVEC+1                  ; keyget routine
         STADR          KEYIN;INVEC
         LDA            MEMTOP+1
         CLC
         ADC            #4
         STA            PNT+1
:LOOK    LDY            #$23                      ;Look through all possible
:LUP     LDA            (PNT),Y                   ; pages for "EDIT"
         CMP            DATA-$20,Y
         BNE            :REJ
         DEY
         CPY            #$20
         BGE            :LUP
         LDA            #>KEYGET                  ;Patch in our address
         STA            (PNT),Y
         DEY
         LDA            #KEYGET
         STA            (PNT),Y
         BCC            EXIT                      ;Always

:REJ     INC            PNT+1
         LDA            PNT+1
         CMP            #$9A
         BLT            :LOOK
EXIT     LDY            YSAV
         PLA
         RTS

KEYIN    BIT            MACSTATE
         BPL            GETK                      ;If not doing macro
         STA            (BASL),Y
         JSR            SENDMAC                   ;Get next macro char
         BNE            SETHI                     ;Branch if imm exit
         LDA            (BASL),Y
GETK     JSR            CALLOLD
         AND            #$7F
         BEQ            SETHI                     ;Just pass the ^@
         LSR            FLAG                      ;Flag immediate mode
         BIT            BUTT0
         BMI            GOTMAC
         BIT            BUTT1
         BMI            GOTMAC
SETHI    ORA            #$80
RET      RTS

GOTMAC   JSR            TESTMAC
         BPL            SETHI                     ;Always

KEYGET   SEC                                      ;From the editor
         ROR            FLAG
         BIT            MACSTATE
         BMI            SENDMAC                   ;Branch if now in macro
:GETK    LDA            KEY
         BPL            :GETK
         BIT            STROBE
         AND            #$7F
         BEQ            :GETK                     ;Must reject ^@
         BIT            BUTT0
         BMI            TESTMAC
         BIT            BUTT1
         BPL            RET
                                                  ;Fall into TESTMAC
TESTMAC  PHA                                      ;Imm mode only
         STADR          MACTBL;PNT
         STY            YSAV
         LDY            #0
:LOOK    PLA
         PHA
         AND            #$7F                      ;In case immed mode
         CMP            #$60                      ;Check for lower case match
         BLT            :CMP
         AND            #%01011111
:CMP     CMP            (PNT),Y
         BEQ            :GOTIT
:SKIP    JSR            GETCHR
         BPL            :SKIP
         JSR            GETCHR
         BNE            :LOOK
         BEQ            EXIT                      ;Not defined

:GOTIT   PLA
         ROR            MACSTATE                  ;Flag we are in macro
         LDY            YSAV
SENDMAC  STY            YSAV
         LDY            #0
:JGC     JSR            GETCHR
         BMI            :STYM
         BNE            :NOTLAST
         BIT            FLAG                      ;In edit mode?
         BMI            :JGC                      ;Branch if so
:STYM    STY            MACSTATE                  :Flag end of macro
:NOTLAST LDY            YSAV
         AND            #$7F
         RTS

GETCHR   INCD           PNT
         LDA            (PNT),Y
         RTS

MACSTATE BRK                                      ;Minus if doing macro
YSAV     BRK                                      ;General
FLAG     BRK                                      ;Minus if from editor

MACTBL
         ASC            '-'0708
         ASC            '-'1515151515151515151515151515158D
         DCI            '0CATALOG'
         DCI            '1CATALOG,D1'
         DCI            '2CATALOG,D2'
         DCI            '3CATALOG/RAM'
         DCI            'LLIST'
         HEX            04
         ASC            'PRINT CHR$(4)"'00
         ASC            '"'0889
         DCI            'PPREFIX'
         ASC            '=PREFIX'0D
         ASC            'PREFIX'1B
         ASC            'IIJJJJJJJ'1B1515151515151595
         ASC            :'PRINT ":00
         ASC            :":0889
         ASC            '9PRINT SPC('00
         ASC            ')'0889
         DCI            'GGOSUB'
         ASC            'IIF '00
         ASC            ' THEN'080808080889
         ASC            '4CHR$('00
         ASC            ')'0889
         ASC            '/INPUT "'00
         ASC            '"'0889
         ASC            'FFOR '00
         ASC            ' = 1 TO'0808080808080889
         ASC            'DDATA"'00
         ASC            '"'0889
         DCI            'XXDRAW'
         DCI            'K=PEEK(49152)'
         DCI            'SPOKE49168,0'
         HEX            151515151515151595
         HEX            080808080808080888
         DCI            'RRENUMBER'
         DCI            'HHOLD'
         DCI            'MMERGE'
         DCI            'EEDIT'
         DCI            'AAUTO'

ENDTBL   DFB            0                         ;End of table

         DS             ENDTBL&ENDTBL&$FF!$FF
ENDMOD
