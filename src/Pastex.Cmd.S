******************************
*                            *
*    PASTE for ProSel-16     *
*                            *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/PASTEX.CMD
         FIN

         EXP            OFF
         TR
         TR             ADR

STREND   =              $6D                       ;Bottom of free space
FRETOP   =              $6F                       ;Top of free space
HIMEM    =              $73                       ;Bottom of system buffer
CHRGOT   =              $B7
GOT1     =              $D0                       ;Amount read
BUFPNT   =              $D2
GOT2     =              GOT1+4                    ;D4,D5
PATHPNT1 =              $E0                       ;File 1 pathname ptr
PATHPNT2 =              $E2                       ;File 2 "
REF1     =              $E4                       ;File 1 ref #
EOF1     =              $E5                       ;6,7
REF2     =              REF1+4                    ;File 2 ref #
EOF2     =              EOF1+4                    ;9,A,B
TEMP     =              $EE                       ;Compare/paste and misc
POS1     =              $93                       ;4,5
POS2     =              POS1+4                    ;7,8,9
BUFSIZ   =              $A0                       ;1
OFFSET   =              $FA                       ;B,C
IN       =              $200
COUT     =              $FDED

* ProDOS MLI call codes:

open     =              $C8
read     =              $CA
write    =              $CB
close    =              $CC
setmark  =              $CE
geteof   =              $D1

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters
FBITS    =              $BE56                     ;Parameter bits found
VPATH1   =              $BE6C                     ;Pointer to pathname 1
VPATH2   =              $BE6E                     ; " 2
GOSYSTEM =              $BE70                     ;Call MLI routine
XRETURN  =              $BE9E                     ;Has RTS
SREFNUM  =              $BEC7                     ;Ref # for geteof
SMARK    =              $BEC8                     ;File size (3 bytes)
OSYSBUF  =              $BECE                     ;Buffer ptr for OPEN
OREFNUM  =              $BED0                     ;File ref # for OPEN
RWREFNUM =              $BED6                     ;Ref # for read/write
RWDATA   =              $BED7                     ;Buffer ptr for read/write
RWCOUNT  =              $BED9                     ;# of bytes to read/write
RWGOT    =              $BEDB                     ;# bytes got
CFREFNUM =              $BEDE                     ;Ref # for CLOSE
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
AMPEXIT  JMP            MONRTS                    ;To daisy chain & cmds
AMPENTRY BNE            AMPEXIT                   ;Other & cmds to next rout.
         LDY            #0
:SN      LDA            CMDNAME,Y                 ;Show our list of dos cmds
         JSR            COUT                      ;If all modules have this
         INY                                      ; routine then &<RTN> will
         CPY            #AMPEND-CMDNAME
         BLT            :SN                       ; list all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next rout. (always)

         DFB            $F0                       ;Signature

PARSE    LDX            #CMDEND-CMDNAME-1
         LDY            #CMDEND-CMDNAME-1
:PAR     STX            XLEN
         INX
         INY
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,Y
         SEC                                      ;In case we exit here
         BNE            DOSEXIT                   ;Support daisy chain
         DEY
         DEX
         BNE            :ISIT
         STX            XCNUM                     ;Signal external cmd
         STY            TEMP                      ;Indicate COMPARE/PASTE
         STADR          DOCMD;XTRNADDR
         LDA            #%11                      ;Two file names expected
         STA            PBITS
         STX            PBITS+1
         CLC                                      ;Say we accept the cmd
         RTS

CMDNAME  ASC            "PASTEX"
CMDEND   ASC            " pathname1, pathname2"8D
AMPEND

DOCMD    LDA            FBITS
         LSR                                      ;Found file name?
         BCS            :FND                      ;Branch if so
:SYNERR  LDA            #11
:ERROR   SEC
         RTS

:FND     LSR                                      ;Second name given?
         BCC            :SYNERR                   ;Error if not
         LDA            FRETOP+1
         SBC            STREND+1                  ;Get free space
         SBC            #5                        ;Subt part pg & 4 buff pgs
         BEQ            :TOOL                     ;Error if no pages left
         BCS            :MEMOK                    ; or if even less
:TOOL    LDA            #14                       ;Program too large
         BNE            :ERROR
:MEMOK   LDY            TEMP
         STA            BUFSIZ+1
         LDA            #$80
         STA            BUFSIZ
         LDY            HIMEM+1                   ;Adrs high of system buffer
         STY            OSYSBUF+1                 ;System buffer for orig
         LDX            #2
]LUP     LDA            VPATH1-1,X
         STA            PATHPNT1-1,X
         LDA            VPATH2-1,X
         STA            PATHPNT2-1,X
         DEX
         BNE            ]LUP
         JSR            OPEN                      ;Open file 1, X=0
         BCS            :CLSERR                   ;Close if error
         LDA            SMARK
         SBC            #5
         STA            SMARK
         LDA            SMARK+1
         SBC            #0
         STA            SMARK+1
         DOS            setmark
         BCS            :CLSERR
]LUP     LDA            SMARK-1,X
         STA            EOF1-1,X
         DEX
         BNE            ]LUP
         LDA            (PATHPNT1,X)
         TAY
:MV1     LDA            (PATHPNT1),Y
         STA            IN+$C0,Y
         DEY
         BPL            :MV1
         LDA            (PATHPNT2,X)
         TAY                                      ;Length of path 2
:MVN     LDA            (PATHPNT2),Y
         STA            (PATHPNT1),Y
         DEY                                      ;Now system -> to path 2
         BPL            :MVN
         LDY            STREND+1
         INY                                      ;Use 1st 4 free pages
         STY            OSYSBUF+1                 ; for file 2 buffer
         LDX            #4
         JSR            OPEN                      ;Open file 2
         BCC            :ON                       ;X=3
:CLSERR  JSR            CLOSE
         SEC
         RTS

:ON      LDA            SMARK-1,X
         STA            EOF2-1,X
         LDA            #0
         STA            POS1-1,X
         STA            POS2-1,X
         STA            OFFSET-1,X
         DEX
         BNE            :ON
         STA            BUFPNT
         LDA            STREND+1
         ADC            #5
         STA            RWDATA+1
         STA            BUFPNT+1

* Append routine:

         ASL            BUFSIZ                    ;=0
]LUP     LDX            #4
         JSR            READIT                    ;Read from file 2
         BCS            :BERR
         LDA            GOT2
         ORA            GOT2+1
         BEQ            :PDONE
         LDA            REF1                      ; and write to file 1
         STA            RWREFNUM
         DOS            write
         BCS            :BERR
         LDA            POS2+1
         ADC            BUFSIZ+1
         STA            POS2+1
         BCC            ]LUP
         INC            POS2+2
         BCS            ]LUP
:PDONE   LDA            EOF1
         SEC
         SBC            #$45
         STA            SMARK
         LDA            EOF1+1
         SBC            #0
         STA            SMARK+1
         LDA            #0
         STA            SMARK+2
         LDA            REF1
         STA            SREFNUM
         STA            RWREFNUM
         DOS            setmark
:BERR    BCS            :ERR
         LDA            #$80
         STA            RWCOUNT
         ASL
         STA            RWCOUNT+1
         DOS            read
         BCS            :ERR
         DOS            setmark
         BCS            :ERR
         LDY            #$45+2
         LDX            #2
]LUP     LDA            (BUFPNT),Y
         STA            EOF1,X
         DEY
         DEX
         BPL            ]LUP
         LDA            EOF1
         CLC
         ADC            #6
         STA            EOF1
         BCC            :NC
         INC            EOF1+1
         BNE            :NC
         INC            EOF1+2
:NC      LDY            #$45-2
         LDX            #2
]LUP     LDA            EOF1,X
         STA            (BUFPNT),Y
         DEY
         DEX
         BPL            ]LUP
         LDY            #10
         LDX            #2
]LUP     LDA            EOF1,X
         STA            (BUFPNT),Y
         DEY
         DEX
         BPL            ]LUP
         LDA            EOF1
         CLC
         ADC            #$46
         STA            EOF1
         BCC            :NI
         INC            EOF1+1
         BNE            :NI
         INC            EOF1+2
:NI      LDY            #2
]LUP     LDA            EOF1,Y
         STA            (BUFPNT),Y
         DEY
         BPL            ]LUP
         LDY            #18
         LDA            #0
         STA            (BUFPNT),Y
         DOS            write
:ERR     PHP
         JSR            CLOSE
         PLP
         RTS

READIT   LDA            POS1,X
         STA            SMARK
         CMP            EOF1,X
         LDA            POS1+1,X
         STA            SMARK+1
         SBC            EOF1+1,X
         LDA            POS1+2,X
         STA            SMARK+2
         SBC            EOF1+2,X
         BLT            :READ                     ;Branch if something left
         LDA            #0                        ;Here if empty file
:ZGOT    STA            GOT1,X
         STA            GOT1+1,X
         CLC                                      ;Signal no error
         RTS

:READ    LDA            REF1,X
         STA            SREFNUM
         STA            RWREFNUM
         DOS            setmark
         BCS            :RET
         LDA            BUFSIZ
         STA            RWCOUNT                   ;Use half pgs for compare,
         ADC            POS1,X                    ; full buffer for paste
         TAY
         LDA            BUFSIZ+1
         STA            RWCOUNT+1
         ADC            POS1+1,X
         PHA
         LDA            POS1+2,X
         ADC            #0
         STA            TEMP
         TYA
         CMP            EOF1,X
         PLA
         SBC            EOF1+1,X
         LDA            TEMP
         SBC            EOF1+2,X
         BLT            :DOR                      ;Branch if more file
         LDA            EOF1,X                    ;Else set to read only
         SBC            POS1,X                    ; what is left
         STA            RWCOUNT
         LDA            EOF1+1,X
         SBC            POS1+1,X
         STA            RWCOUNT+1
         ORA            RWCOUNT
         BEQ            :ZGOT                     ;If no more then zero GOT
:DOR     DOS            read                      ;Read from source
         PHA                                      ;Save error code
         LDA            RWGOT
         STA            GOT1,X                    ;Get amount read for
         LDA            RWGOT+1                   ; testing & perserve carry.
         STA            GOT1+1,X
         PLA                                      ;Recall error code
:RET     RTS

OPEN     DOS            open
         BCS            :RET
         LDA            OREFNUM
         STA            REF1,X
         STA            SREFNUM
         DOS            geteof
         LDX            #3
:RET     RTS

CLOSE    PHA                                      ;Remember error code
         LDA            #0
         STA            CFREFNUM
         DOS            close                     ;Close both files
         PLA                                      ;Retrieve error code
         RTS
