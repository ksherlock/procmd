******************************
*                            *
* COMPARE & PASTE BASIC CMDS *
*                            *
*  Glen E. Bredon   2/12/87  *
*                            *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/COMPARE.CMD
         FIN

         EXP            OFF
         TR
         TR             ADR

INVFLG   =              $32
CSWH     =              $37
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
CURH     =              $EC                       ;Cursor horizontal
CURV     =              $ED                       ;Cursor vertical
TEMP     =              $EE                       ;Compare/paste and misc
POS1     =              $93                       ;4,5
POS2     =              POS1+4                    ;7,8,9
BUFSIZ   =              $A0                       ;1
OFFSET   =              $FA                       ;B,C
FLAG     =              $FD                       ;When to print data
IN       =              $200
KEY      =              $C000
STROBE   =              $C010
OPENAP   =              $C061
CLSDAP   =              $C062
PRNTAX   =              $F941
CROUT    =              $FD8E
PRBYTE   =              $FDDA
COUT     =              $FDED
OUTPORT  =              $FE95

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

         DFB            31                        ;Signature

PARSE    LDX            #CMDEND-CMDNAME-1
         LDY            #CMDEND-CMDNAME-1
         LDA            IN
         AND            #%11011111
         CMP            #"P"
         BNE            :PAR
         DEX
         DEX
         LDY            #CMDEND2-CMDNAME-1
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

CMDNAME  ASC            "COMPARE"
CMDEND   ASC            " or "
         ASC            "PASTE"
CMDEND2  ASC            " pathname1, pathname2"8D
AMPEND

TITLE    ASC            "ESC: exit,  RTN: next difference,  "
         HEX            9B8F
         ASC            "@"988E
         ASC            "# or "9B8F
         ASC            "A"988E
         ASC            "#: adjust offset, ^P: print,"8D
         HEX            9B8F
         ASC            "H"988E
         ASC            ": back one line,  "
         HEX            9B8F
         ASC            "U"988E
         ASC            ": forward one line,"8D
         HEX            9B8F
         ASC            "K"988E
         ASC            ": back 8 lines,   "
         HEX            9B8F
         ASC            "J"988E
         ASC            ": forward 8 lines."8D00

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
         BNE            :HOK                      ;Branch if paste
         LDA            #3
         JSR            OUTPORT                   ;PR#3 for compare
         LDA            #0
:HOK     STA            BUFSIZ+1
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
         DOS            setmark                   ;In case of PASTE cmd
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
         STA            FLAG
         STA            BUFPNT
         LDA            STREND+1
         ADC            #5
         STA            RWDATA+1
         STA            BUFPNT+1
         LDA            TEMP
         BEQ            :RLUP                     ;Branch if compare cmd

* Append routine:

         ASL            BUFSIZ                    ;=0
]LUP     LDX            #4
         JSR            READIT                    ;Read 1/4 block from file 2
         BCS            :ERR
         LDA            GOT2
         ORA            GOT2+1
         BEQ            :PDONE
         LDA            REF1                      ; and write to file 1
         STA            RWREFNUM
         DOS            write
         BCS            :ERR
         LDA            POS2+1
         ADC            BUFSIZ+1
         STA            POS2+1
         BCC            ]LUP
         INC            POS2+2
         BCS            ]LUP
:PDONE
:ERR     PHP
         JSR            CLOSE
         PLP
         RTS

* Compare routine:

:RLUP    LDX            #0
         JSR            READITC                   ;Read 1/4 block file 1
         BCS            :CLSERR
         LDX            #4
         JSR            READITC                   ;Same for file 2
         BCS            :CLSERR
         LDA            GOT1
         CMP            GOT2
         BNE            :SHOWIT                   ;Display if not same got
         TAY
         BEQ            :JDONE                    ;Exit if both empty
         LDA            FLAG
         BMI            :SHOWIT                   ;Show if arrow, etc cmds
:CMP     DEY
         LDA            (BUFPNT),Y                ;Get byte, file 1
         TAX                                      ;Keep in X
         TYA
         ORA            #$80
         TAY                                      ;Point to buf 2
         TXA
         CMP            (BUFPNT),Y
         BNE            :SHOWIT                   ;If different then show
:NXT     TYA                                      ; this block.
         AND            #$7F                      ;Point back to buf 1
         TAY
         BNE            :CMP
         JMP            :NXTBLK                   ;If same then read next

:JDONE   JMP            :DONE

:SHOWIT  LDA            CSWH
         CMP            #$C3
         BNE            :PRTR                     ;No FF if printer
         LDA            #"L"&$9F
         JSR            COUT
:PRTR    LDY            #0
         STY            CURV
         LDX            IN+$C0
         CPX            #80
         BGE            :NN1
:NY1     INY
         LDA            IN+$C0,Y                  ;Print name of file 1
         ORA            #$80
         JSR            COUT
         DEX
         BNE            :NY1
:NN1     JSR            DOCR
         LDY            #0
         LDA            GOT1
         BEQ            :PART2                    ;Skip if past file
:SH1     CLC
         JSR            PRPOS
:S1      TYA
         JSR            PUTBUF
         TAX                                      ;Save byte
         LDA            #-1
         STA            (BUFPNT),Y                ;Signal same
         CPY            GOT2
         BGE            :INV                      ;Not same if past file 2
         TYA
         ORA            #$80
         TAY
         TXA                                      ;Retrieve byte
         CMP            (BUFPNT),Y                ;Compare to file 2 byte
         BEQ            :SAME
:INV     LDA            #$3F
         STA            INVFLG
         TYA
         AND            #$7F
         TAY
         STA            (BUFPNT),Y                ;Signal different
:SAME    TXA
         JSR            BYTEOUT
         DEC            GOT1
         BEQ            :SHOW2
         TYA
         AND            #$F
         BNE            :S1
         JSR            PRASC
         BCS            :SH1                      ;Always

:SHOW2   JSR            PRASC
:PART2   TYA
         BMI            :TAB
:FLG     STA            (BUFPNT),Y
         INY
         BPL            :FLG
:TAB     LDA            #10
         JSR            TABV
         LDY            #0
         LDX            IN+$80
         CPX            #80
         BGE            :NN2
:NY2     INY
         LDA            IN+$80,Y                  ;Put ascii in buffer
         ORA            #$80
         JSR            COUT
         DEX
         BNE            :NY2
:NN2     JSR            DOCR
         LDA            GOT2
         BEQ            :ZFLG
         LDY            #0
:SH2     SEC
         JSR            PRPOS
:S2      LDA            (BUFPNT),Y                ;If this + then different
         BMI            :NORM
         LSR            INVFLG
:NORM    TYA
         ORA            #$80
         TAY
         JSR            PUTBUF                    ;Save for ascii
         JSR            BYTEOUT                   ; and print byte
         DEC            GOT2                      ;Count down bytes got
         BEQ            :PTD
         TYA
         AND            #$F
         BNE            :S2                       ;Loop for 16 bytes
         JSR            PRASC                     ; then do ascii part
         BCS            :SH2                      ;Always

:PTD     JSR            PRASC                     ;Do ascii for short line
:ZFLG    LDA            CSWH
         CMP            #$C3
         BEQ            :L20
         JSR            DOCR                      ;CR if printer
         LDA            #3                        ;Then do PR#3
         JSR            OUTPORT
         JMP            :RLUP                     ;Reprint if was printer

:L20     LDA            #20                       ;If screen then print keys
         JSR            TABV
         LDY            #0
:PT      LDA            TITLE,Y                   ;Show commands on screen
         BEQ            :GK                       ; mode only
         JSR            COUT
         INY
         BNE            :PT

:GK      LDA            KEY                       ;Get a command
         BPL            :GK
         LSR            FLAG                      ;Set show flag to off
         BIT            STROBE
         CMP            #"["&$9F
         BEQ            :DONE                     ;Exit on ESC
         CMP            #$8D
         BEQ            :NXTBLK                   ;Next difference if RTN
         STA            FLAG                      ;Force screen print
         CMP            #"P"&$9F
         BEQ            :PRTRON                   ;Printer on if ^P
         CMP            #"U"&$9F
         BNE            :DOWN
         LDA            #$10
         BNE            :ADPOS                    ;Down 1 line on right arrow

:PRTRON  LDA            #"Y"&$9F                  ;Home screen curs for echo
         JSR            COUT
         LDA            #1
         JSR            OUTPORT                   ;Printer on
         JMP            :RLUP

:DOWN    CMP            #"J"&$9F
         BEQ            :NXTBLK                   ;Down 8 lines on down arrow
         CMP            #"K"&$9F
         BNE            :ISBS
         LDA            POS1                      ;Up 8 lines on up arrow
         SBC            #$80
         CLV
         BVC            :REPOS

:DONE    JSR            CLOSE
         CLC
         RTS

:ISBS    CMP            #$88
         BEQ            :BS                       ;Up 1 line on left arrow
         CMP            #"0"
         BLT            :GK
         EOR            #"0"
         BNE            :NOTEN
         LDA            #10                       ;Translate 0 to 10
:NOTEN   CMP            #11
         BGE            :GK                       ;Branch if not a command
         LDY            #0
         LDX            #-3
         BIT            CLSDAP
         BMI            :ADD                      ;Add to offset if CA-#
         BIT            OPENAP
         BPL            :GK                       ;Illegal if no Apple key
         DEY                                      ;= -1
         EOR            #-1                       ;Set to subtract # if OA
         SEC
:ADD     ADC            OFFSET+3,X                ;Add or sub to offset
         STA            OFFSET+3,X
         TYA
         INX
         BNE            :ADD
         BEQ            :CC

:BS      LDA            POS1
         SBC            #$10
:REPOS   STA            POS1
         LDA            POS1+1
         SBC            #0
         STA            POS1+1
         LDA            POS1+2
         SBC            #0
         STA            POS1+2
         BCS            :CC
         LDA            #$80                      ;On overflow pin at
         STA            POS1                      ; position 0
:NXTBLK  LDA            #$80
:ADPOS   CLC
         ADC            POS1
         STA            POS1
         LDA            POS1+1
         ADC            #0
         STA            POS1+1
         BCC            :NC
         INC            POS1+2
:CC      CLC
:NC      LDA            POS1
         ADC            OFFSET
         STA            POS2
         LDA            POS1+1
         ADC            OFFSET+1
         STA            POS2+1
         LDA            POS1+2
         ADC            OFFSET+2
         STA            POS2+2
         JMP            :RLUP

READITC  TXA                                      ;Point to low buffer for
         BEQ            :SD                       ; file 1
         LDA            #$80                      ;High buffer for file 2
:SD      STA            RWDATA
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
         LDA            CSWH
         CMP            #$C1
         BNE            :NO                       ;Branch if not printer
         LDA            #3                        ; (eg for PASTE)
         JSR            OUTPORT                   ;Else printer off
:NO      LDA            #0
         STA            CFREFNUM
         DOS            close                     ;Close both files
         PLA                                      ;Retrieve error code
         RTS

PRPOS    LDA            #$8D                      ;Put CR at end of ascii
         LDX            #$10                      ; buffer
:ZB      STA            IN+$30,X                  ;And then fill with spaces
         LDA            #" "
         DEX
         BPL            :ZB
         ROL
         ASL
         ASL
         TAX
         TYA
         CLC
         ADC            POS1,X                    ;Add Y to posn of byte 0
         STA            TEMP
         LDA            POS1+1,X
         ADC            #0
         PHA
         LDA            POS1+2,X
         ADC            #0
         JSR            PRBYTE                    ;Show file position
         PLA
         LDX            TEMP
         JSR            PRNTAX
         LDA            #7
         STA            CURH                      ;Init cur horiz
         LDA            #":"
         JMP            COUT

PRASC    LDA            #58
         SEC
         SBC            CURH
         TAX
:SP      LDA            #" "
         JSR            COUT                      ;Tab to ascii part
         DEX
         BNE            :SP
         STX            CURH                      ;CR is done at end
]LUP     LDA            IN+$30,X
         JSR            COUT                      ;Print ascii buffer
         INX
         CPX            #$11                      ;Space for ending CR
         BLT            ]LUP
         INC            CURV                      ;Count this line
         RTS

PUTBUF   AND            #$F
         TAX
         LDA            (BUFPNT),Y
         ORA            #$80
         CMP            #" "
         BGE            :PRIT
         LDA            #"."                      ;Substitute . for controls
:PRIT    STA            IN+$30,X                  ;Put in ascii buffer
         LDA            (BUFPNT),Y
         RTS

BYTEOUT  JSR            PRBYTE                    ;Print byte
:SP      LDA            #" "
         BIT            INVFLG
         BMI            :TY                       ;Branch if bytes same
         LDA            #-1
         STA            INVFLG                    ;Fix inv flag
         LDA            CSWH
         CMP            #$C3
         BEQ            :SP
         LDA            #"<"                      ;Send a < if printer
:TY      JSR            COUT
         INC            CURH                      ;Count three chars
         INC            CURH
         INC            CURH
         TYA
         AND            #$7F                      ;Point back to low buffer
         TAY
         INY
         RTS

TABV     SEC
         SBC            CURV
         BEQ            :RET
         TAX
]LUP     JSR            DOCR                      ;Do vert tab with CRs in
         DEX                                      ; case of printer
         BNE            ]LUP
:RET     RTS

DOCR     INC            CURV                      ;Count vert line
         LDA            #0
         STA            CURH                      ; and set CURH 0 on a CR
         JMP            CROUT
