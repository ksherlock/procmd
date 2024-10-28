******************************
*                            *
*     COMPACT BASIC CMD      *
*                            *
*  Glen E. Bredon  11/10/88  *
*                            *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/COMPACT.CMD
         FIN

         EXP            OFF
         TR
         TR             ADR

STREND   =              $6D                       ;Bottom of free space
FRETOP   =              $6F                       ;Top of free space
HIMEM    =              $73                       ;Bottom of system buffer
CHRGOT   =              $B7
BUFPNT   =              $D2
BUFSIZ   =              $D4
PATHPNT1 =              $E0                       ;File 1 pathname ptr
PATHPNT2 =              $E2                       ;File 2 "
REF1     =              $E4                       ;File 1 ref #
REF2     =              REF1+1                    ;File 2 ref #
TEMP     =              $E6                       ;7
PNT      =              $E8                       ;Orig pointer
DPNT     =              $EA                       ;Dest pointer
ENDPNT   =              $EC                       ;End of buffer
IN       =              $200
COUT     =              $FDED

* ProDOS MLI call codes:

create   =              $C0
open     =              $C8
read     =              $CA
write    =              $CB
close    =              $CC
getmark  =              $CF
seteof   =              $D0

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
CRETYPE  =              $BEA4
SREFNUM  =              $BEC7                     ;Ref # for geteof
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

INCD     MAC
         INC            ]1
         BNE            NC
         INC            ]1+1
NC       <<<

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

         DFB            34                        ;Signature

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
         STADR          DOCMD;XTRNADDR
         LDA            #%11                      ;Two file names expected
         STA            PBITS
         STX            PBITS+1
         CLC                                      ;Say we accept the cmd
         RTS

CMDNAME  ASC            "COMPACT"
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

:MEMOK   STA            BUFSIZ+1
         LDY            HIMEM+1                   ;Adrs high of system buffer
         STY            OSYSBUF+1                 ;System buffer for orig
         LDX            #2
]LUP     LDA            VPATH1-1,X
         STA            PATHPNT1-1,X
         LDA            VPATH2-1,X
         STA            PATHPNT2-1,X
         DEX
         BNE            ]LUP
         STX            BUFSIZ
         JSR            OPEN                      ;Open file 1, X=0
         BCS            :CLSERR                   ;Close if error
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
         JSR            COPEN                     ;Open file 2
         BCC            :ON                       ;X=3
:CLSERR  JSR            CLOSE
         SEC
         RTS

:ON      LDA            #0
         STA            BUFPNT
         STA            RWDATA
         LDA            STREND+1
         ADC            #5
         STA            RWDATA+1
         STA            BUFPNT+1

MAIN     JSR            READIT                    ;Read file 1
         BCC            :MORE
         CMP            #5
         BEQ            :MORE                     ;Ok if EOF
         JMP            ERR

:DONE    JMP            DONE

:MORE    LDA            RWGOT
         STA            ENDPNT
         ORA            RWGOT+1
         CLC
         BEQ            :DONE
         LDA            BUFPNT+1
         STA            PNT+1
         STA            DPNT+1
         ADC            RWGOT+1
         STA            ENDPNT+1
         LDY            #0
         STY            PNT
         STY            DPNT
]LOOP
         LDA            (PNT),Y
         ORA            #$80
         STA            (DPNT),Y
         LDX            PNT+1
         LDA            PNT
         CLC
         ADC            #2
         BCC            :OV
         INX
:OV      CMP            ENDPNT
         TXA
         SBC            ENDPNT+1
         BGE            :BNO
         LDA            (DPNT),Y
         CMP            #" "
         BEQ            :L1
         CMP            #"."
         BEQ            :DD
         CMP            #"-"
         BNE            :TB
:DD      LDY            #4
]LUP     CMP            (PNT),Y
         BNE            :TNO
         DEY
         BNE            ]LUP
         STY            TEMP
         ADC            #$FE-"-"-1
         LDY            #3
         BNE            :ST2

:TNO     JMP            :NO

:TB      CMP            #$89
         BNE            :CR
:IY      INY
         CPY            #9
         BGE            :BNO
         LDA            (PNT),Y
         ORA            #$80
         CMP            #$89
         BEQ            :IY
         SEC
         LDA            #$98
         DEY
         BEQ            :BNO
         BNE            :ST

:CR      CMP            #$8D
         BNE            :E1
:C1      INY
         CPY            #9
         BGE            :BNO
         LDA            (PNT),Y
         ORA            #$80
         CMP            #$8D
         BEQ            :C1
         CMP            #$89
         BNE            :NO
         LDA            #$90
:ST      DEY
         STY            TEMP
:ST2     STA            TEMP+1
         LDX            PNT+1
         TYA
         SEC
         ADC            PNT
         BCC            :T
         INX
:T       CMP            ENDPNT
         TAY
         TXA
         SBC            ENDPNT+1
:BNO     BGE            :NO
         STY            PNT
         STX            PNT+1
         LDA            TEMP
         ORA            TEMP+1
         LDY            #0
         BEQ            :YES

:E1      CMP            #$E1
         BLT            :NO
:L1      INY
         LDA            (PNT),Y
         ORA            #$80
         CMP            #" "
         BEQ            :L2
         CMP            #$E1
         BLT            :NO
:L2      INY
         LDA            (PNT),Y
         ORA            #$80
         CMP            #" "
         BEQ            :L3
         CMP            #$E1
         BLT            :NO
:L3      AND            #%00011111
         STA            TEMP+1
         LDY            #0
         LDA            (PNT),Y
         ASL
         ASL
         AND            #$7F
         STA            TEMP
         INY
         LDA            (PNT),Y
         PHA
         LSR
         LSR
         LSR
         AND            #%11
         ORA            TEMP
         DEY
         STA            (DPNT),Y
         PLA
         ASL
         ASL
         ASL
         ASL
         ASL
         ORA            TEMP+1
         INCD           DPNT
         INCD           PNT
         INCD           PNT
:YES     STA            (DPNT),Y
:NO      LDY            #0
         INCD           PNT
         INCD           DPNT
         LDA            PNT
         CMP            ENDPNT
         LDA            PNT+1
         SBC            ENDPNT+1
         BLT            :NOTDONE
         LDA            DPNT
         STA            RWCOUNT
         LDA            DPNT+1
         SBC            BUFPNT+1
         STA            RWCOUNT+1
         LDA            REF2                      ; and write to file 2
         STA            RWREFNUM
         DOS            write
         BCS            ERR
         JMP            MAIN

:NOTDONE JMP            ]LOOP

DONE     LDA            REF2
         STA            SREFNUM
         DOS            getmark
         BCS            ERR
         DOS            seteof
ERR      PHP
         JSR            CLOSE
         PLP
         RTS

READIT   LDA            REF1
         STA            RWREFNUM
         LDA            BUFSIZ
         STA            RWCOUNT                   ;Use half pgs for compare,
         LDA            BUFSIZ+1
         STA            RWCOUNT+1
         DOS            read                      ;Read from source
         RTS

COPEN    LDA            #$BF
         STA            CRETYPE
         DOS            create
         LDX            #1
OPEN     DOS            open
         BCS            :RET
         LDA            OREFNUM
         STA            REF1,X
:RET     RTS

CLOSE    PHA                                      ;Remember error code
         LDA            #0
         STA            CFREFNUM
         DOS            close                     ;Close both files
         PLA                                      ;Retrieve error code
         RTS
