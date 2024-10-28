******************************
*                            *
*      SETINFO BASIC CMD     *
*----------------------------*
*  Glen E. Bredon   1/16/87  *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/SETINFO.CMD
         FIN

         EXP            OFF
         TR

CHRGOT   =              $B7
IN       =              $200
COUT     =              $FDED

* ProDOS MLI call codes:

setinfo  =              $C3
getinfo  =              $C4

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters
FBITS    =              $BE56                     ;Parameter bits found
VADDR    =              $BE58                     ;A parameter value
VLINE    =              $BE68                     ;@ parameter value
VTYPE    =              $BE6A                     ;T parameter value
GOSYSTEM =              $BE70                     ;Call MLI routine
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
INFPARMS =              $BEB4                     ;GETINFO parm list
ACCESS   =              $BEB7                     ;File access put here
FILETYPE =              $BEB8                     ;File type put here
FIAUX    =              $BEB9                     ;Aux type put here
BUBIT    =              $BF95
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

MOVD     MAC
         LDA            ]1
         STA            ]2
         LDA            ]1+1
         STA            ]2+1
         <<<

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

DOSENTRY JMP            PARSE                     ;These two jumps permit RELOC
DOSEXIT  JMP            XRETURN                   ; to daisy chain commands
AMPEXIT  JMP            MONRTS                    ;This one to daisy chain & cmds
AMPENTRY BNE            AMPEXIT                   ;Other & cmds to next routine
         LDY            #0
:SN      LDA            CMDNAME,Y                 ;Show our "list" of dos cmds
         JSR            COUT                      ;If all modules have this
         INY                                      ; routine then &<RTN> will
         CPY            #AMPEND-CMDNAME
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            29                        ;Signature

PARSE    LDX            #CMDEND-CMDNAME-1
         STX            XLEN
         INX
         SEC                                      ;In case we exit here
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
         BNE            DOSEXIT                   ;Support daisy chain
         DEX
         BNE            :ISIT
         STX            XCNUM                     ;Signal external cmd
         LDX            #%101                     ;T allowed, filename expected
         STX            PBITS                     ;File name expected
         LDA            #%10001000                ;Allow A,@ parameter
         STA            PBITS+1
         STADR          DOINFO;XTRNADDR
         CLC                                      ;Say we accept the cmd
         RTS

CMDNAME  ASC            "SETINFO"
CMDEND   ASC            " path [,T typ,A auxtyp,@ access]"8D
AMPEND

DOINFO   LDA            FBITS
         LSR                                      ;Found file name?
         BCS            :T1                       ;Branch if so
         LDA            #6                        ;Path not found error
         HEX            2C
:BADTYPE LDA            #13                       ;File type mismatch
         SEC
:ERROR   RTS

:T1      LDA            #10
         STA            INFPARMS
         DOS            getinfo
         BCS            :ERROR
         LDA            FBITS
         AND            #%100
         BEQ            :NOTYPE
         LDA            VTYPE
         LDX            FILETYPE
         CMP            #$F
         BNE            :TSTT
         CMP            FILETYPE
         BNE            :BADTYPE
         BEQ            :NOTYPE
:TSTT    CPX            #$F
         BEQ            :BADTYPE
         STX            VTYPE
         STA            FILETYPE
:NOTYPE  LDA            FBITS+1
         ASL
         AND            #%10000
         BEQ            :NOAT
         LDA            VLINE
         AND            #%11100011
         STA            ACCESS
         AND            #%00100000
         EOR            #%00100000
         STA            BUBIT
:NOAT    BCC            :SETIT
         MOVD           VADDR;FIAUX
:SETIT   LDA            #7
         STA            INFPARMS
         DOS            setinfo
         RTS
