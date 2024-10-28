******************************
*                            *
*      EJECT BASIC CMD       *
*                            *
*  Glen E. Bredon   5/1/86   *
*                            *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/EJECT.CMD
         FIN

         EXP            OFF
         TR             ADR
         TR

CHRGOT   =              $B7
IN       =              $200
COUT     =              $FDED

* ProDOS MLI call codes:

getinfo  =              $C4

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters
FBITS    =              $BE56                     ;Parameter bits found
VSLOT    =              $BE61
VDRIV    =              $BE62
GOSYSTEM =              $BE70                     ;Call MLI routine
XRETURN  =              $BE9E
INFPARMS =              $BEB4                     ;GETINFO parm list
DEVNUM   =              $BF30
DEVCNT   =              $BF31
DEVLST   =              $BF32
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

STADR    MAC
         LDA            #]1
         STA            ]2
         LDA            #>]1
         STA            ]2+1
         <<<

DOS      MAC
         LDA            #]1
         JSR            GOSYSTEM
         <<<

         AST            50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP            PARSE                     ;These 2 jumps permit RELOC
DOSEXIT  JMP            XRETURN                   ; to daisy chain commands
AMPEXIT  JMP            MONRTS                    ;Daisy chain & cmds
AMPENTRY BNE            AMPEXIT                   ;Other & cmds to next rout
         LDY            #0
:SN      LDA            CMDNAME,Y                 ;Show our "list" of dos cmds
         JSR            COUT                      ;If all modules have this
         INY                                      ; routine then &<RTN> will
         CPY            #AMPEND-CMDNAME
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            27                        ;Signature

PARSE    LDX            #CMDEND-CMDNAME-1
         STX            XLEN
         SEC                                      ;In case we exit here
:ISIT    LDA            IN,X
         AND            #%11011111
         EOR            CMDNAME,X
         BNE            DOSEXIT                   ;Support daisy chain
         DEX
         BPL            :ISIT
         STA            XCNUM                     ;Signal external cmd
         STADR          DOEJECT;XTRNADDR
         LDA            #%00010001                ;File name optional
         STA            PBITS
         LDA            #%00001100                ;Allow @,S,D params
         STA            PBITS+1
         CLC                                      ;Say we accept the cmd
         RTS

CMDNAME  ASC            "EJECT"
CMDEND   ASC            "[path][,S#,D#][,@#]"8D
AMPEND

DOEJECT  LDA            FBITS
         LSR                                      ;File name given?
         BCC            :NONAME
         LDA            #10                       ;# of parms for GETINFO
         STA            INFPARMS
         DOS            getinfo
         TAX
:GOTSD   LDA            DEVNUM
         BCC            :EJECT
         TXA
         RTS

:NONAME  LDA            FBITS+1
         AND            #%00001100
         LSR
         LSR                                      ;Clears carry A=0-3
         BEQ            :GOTSD
         CMP            #2
         BGE            :ALL
         EOR            VDRIV
         LSR
         PHP
         LDA            VSLOT
         ASL
         ASL
         ASL
         ASL
         ASL
         PLP
         ROR
:EJECT   PHA
         ASL
         BMI            :LZ
         LDA            #2
         HEX            2C
:LZ      LDA            #0
         ADC            #1
         STA            :DRIVE
         PLA
         LSR
         LSR
         LSR
         LSR
         ASL
         TAY
         LDA            $BF10,Y
         ADC            #3
         STA            :CALL+1
         LDA            $BF11,Y
         STA            :CALL+2
         STA            :LOOK+2
         EOR            #$C0
         CMP            #8
         BGE            :NO
         LDY            #7
:LOOK    LDA            $C500,Y
         CMP            :DATA-1,Y
         BNE            :NO
         DEY
         DEY
         BPL            :LOOK
:CALL    JSR            $C50D
         DFB            4
         DA             :LST
         LDA            #3
         RTS

:ALL     LDY            DEVCNT
:ALLUP   TYA
         PHA
         LDX            DEVLST,Y
         TXA
         AND            #$F
         CMP            #$B
         BNE            :PULL
         TXA
         JSR            :EJECT
:PULL    PLA
         TAY
         DEY
         BPL            :ALLUP
:NO      CLC                                      ;Never an error
         RTS

:LST     DFB            3
:DRIVE   DFB            1
         DA             :BUF
         DFB            4

:DATA    HEX            20,00,00,00,03
:BUF     DA             0                         ;Part of DATA
