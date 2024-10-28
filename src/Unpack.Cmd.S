******************************
*                            *
*     UNPACK  BASIC CMD      *
*                            *
*  Glen E. Bredon  11/10/88  *
*                            *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/UNPACK.CMD
         FIN

         EXP            OFF
         TR
         TR             ADR

STREND   =              $6D                       ;Bottom of free space
FRETOP   =              $6F                       ;Top of free space
HIMEM    =              $73                       ;Bottom of system buffer
CHRGOT   =              $B7
WBUFPNT  =              $D2
PATHPNT1 =              $E0                       ;File 1 pathname ptr
PATHPNT2 =              $E2                       ;File 2 "
REF1     =              $E4                       ;File 1 ref #
REF2     =              REF1+1                    ;File 2 ref #
TEMP     =              $E6                       ;7
OURSTK   =              $E8
PACK     =              $E9
BUFSIZ   =              $EB
BUFEND   =              $EC
BUFPNT   =              $EE
IN       =              $200
COUT     =              $FDED

KEY      =              $C000
STROBE   =              $C010

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
CRFILID  =              $BEA4
CRFKIND  =              $BEA7
SREFNUM  =              $BEC7                     ;Ref # for geteof
OSYSBUF  =              $BECE                     ;Buffer ptr for OPEN
OREFNUM  =              $BED0                     ;File ref # for OPEN
RWREFNUM =              $BED6                     ;Ref # for read/write
RWDATA   =              $BED7                     ;Buffer ptr for read/write
RWCOUNT  =              $BED9                     ;# of bytes to read/write
RWGOT    =              $BEDB
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
         BNE            NI
         INC            ]1+1
NI       <<<

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

CMDNAME  ASC            "UNPACK"
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

:MEMOK   STA            BUFSIZ
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
:RET     RTS

:ON      TSX
         STX            OURSTK
         LDA            #0
         STA            WBUFPNT
         STA            BUFPNT
         STA            BUFEND
         STA            BUFPNT+1
         STA            BUFEND+1
         BEQ            :TLOOP

:TLOOP   JSR            READ                      ;Read a byte
         JSR            :GETBUF
         JMP            :TLOOP

:GETBUF  STA            PACK
         TAX
         BMI            :BF
         JSR            READ
         STA            PACK+1
         LDA            PACK
         LSR
         LSR
         BEQ            :SP1
         ORA            #%11100000
:SP1     ORA            #%10100000
         JSR            :BF
         LDA            PACK+1
         ASL
         ROL            PACK
         ASL
         ROL            PACK
         ASL
         ROL            PACK
         LDA            PACK
         AND            #%00011111
         BEQ            :SP2
         ORA            #%11100000
:SP2     ORA            #%10100000
         JSR            :BF
         LDA            PACK+1
         AND            #%00011111
         BEQ            :SP3
         ORA            #%11100000
:SP3     ORA            #%10100000
:BF      CMP            #$FE
         BLT            :A0
         PHA
         LDY            #1
         LDA            (BUFPNT),Y
         TAX
         PLA
         CPX            #"="
         BEQ            :A0
         SEC
         SBC            #$FE-"-"
         PHA
         LDA            #5
         STA            TEMP
]LUP     PLA
         DEC            TEMP
         BEQ            :ORD
         PHA
         JSR            :ORD
         SEC
         BCS            ]LUP

:A0      CMP            #$A0
         BGE            :ORD
         CMP            #$90
         BLT            :ORD
         SBC            #$8E
         STA            TEMP
         CMP            #10
         BLT            :CRTAB
         SBC            #8
         STA            TEMP
]LUP     DEC            TEMP
         BEQ            :TAB
         JSR            :TAB
         SEC
         BCS            ]LUP

:JO      JSR            :ORD
:CRTAB   LDA            #$8D
         DEC            TEMP
         BNE            :JO
:TAB     LDA            #$89
:ORD     AND            #$7F
         JSR            WRITE
:CONT    LDA            KEY                       ;Key down?
         BPL            :RTN                      ;Loop if not
         BIT            STROBE
         CMP            #"C"&$9F
         BEQ            ABORT
:RTN     RTS

READ     LDY            #0
         LDA            BUFPNT
         CMP            BUFEND
         LDA            BUFPNT+1
         SBC            BUFEND+1
         BLT            :MORE
         CLC
         STY            RWGOT
         STY            RWGOT+1
         STY            BUFPNT
         STY            RWDATA
         STY            RWCOUNT
         LDA            STREND+1
         ADC            #5
         STA            RWDATA+1
         STA            BUFPNT+1
         LDA            BUFSIZ
         STA            RWCOUNT+1
         LDA            REF1
         STA            RWREFNUM
         DOS            read                      ;Read from source
         LDA            RWGOT
         STA            BUFEND
         ORA            RWGOT+1
         BEQ            DONE
         LDA            RWGOT+1
         ADC            BUFPNT+1
         STA            BUFEND+1
:MORE    LDA            (BUFPNT),Y
         INCD           BUFPNT
         RTS

WRITE    LDX            WBUFPNT
         STA            IN+$80,X
         INC            WBUFPNT
         BPL            WRET
FINWRITE LDA            #IN+$80
         STA            RWDATA
         LDA            WBUFPNT
         BEQ            WRET
         STA            RWCOUNT
         LDA            #0
         STA            WBUFPNT
         STA            RWCOUNT+1
         LDA            #>IN+$80
         STA            RWDATA+1
         LDA            REF2
         STA            RWREFNUM
         DOS            write
         BCS            ABORT
WRET     RTS

DONE     JSR            FINWRITE
ABORT    LDX            OURSTK
         TXS
         LDA            REF2
         STA            SREFNUM
         DOS            getmark
         BCS            :ERR
         DOS            seteof
:ERR     PHP
         JSR            CLOSE
         PLP
         RTS

COPEN    LDA            #4                        ;TXT
         STA            CRFILID
         LDA            #1
         STA            CRFKIND
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
