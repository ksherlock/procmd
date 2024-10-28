********************************
*                              *
*     HLOAD and HSAVE CMDS     *
*                              *
*   Glen E. Bredon   6/24/85   *
*                              *
********************************

         DATE

         REL                                      ;Generate a LNK file
         TR
         TR             ADR
         EXP            OFF

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"
         DO             SAVOBJ
         DSK            OBJECT/HLOAD.CMD
         FIN

* MLI call codes:

getinfo  =              $C4
open     =              $C8
read     =              $CA
write    =              $CB
close    =              $CC
getmark  =              $CF
seteof   =              $D0

* Switches:

STORE80  =              $C001
COL80OFF =              $C00C
COL80ON  =              $C00D
RDTEXT   =              $C01A
RDMIXED  =              $C01B
RD80COL  =              $C01F
GR       =              $C050
TEXT     =              $C051
FULL     =              $C052
MIXED    =              $C053
PAGE1    =              $C054
PAGE2    =              $C055
HIRES    =              $C057

* Applesoft stuff:

SHAPEL   =              $1A                       ;Used for clearing screen
SHAPEH   =              $1B
GBASL    =              $26
GBASH    =              $27
XSAV     =              $3C
HIMEM    =              $73
CHRGOT   =              $B7
TEMP     =              $D0
BYTE     =              $D1                       ;Screen dot being gathered
COUNT    =              $D2                       ;Count of repeated dots
COUNTDWN =              $D3                       ;Reverse of same
FLAG     =              $D4                       ;Compress mode flag
TYPE     =              FLAG                      ;Temp use for file type
STATE    =              $D5
HNDX     =              $E5
HPAG     =              $E6
REMSTK   =              $F8
IN       =              $200
DOWN     =              $F504
COUT     =              $FDED
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

* ProDOS BASIC interp location:

XTRNADDR =              $BE50
XLEN     =              $BE52
XCNUM    =              $BE53
PBITS    =              $BE54
FBITS    =              $BE56
GOSYSTEM =              $BE70
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
INFPARMS =              $BEB4
FILETYPE =              $BEB8
SREFNUM  =              $BEC7
OSYSBUF  =              $BECE
OREFNUM  =              $BED0
RWREFNUM =              $BED6
RWDATA   =              $BED7
RWCOUNT  =              $BED9
CFREFNUM =              $BEDE

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

* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP            PARSE
DOSEXIT  JMP            XRETURN                   ;To daisy chain commands
AMPEXIT  JMP            MONRTS                    ;This one to daisy chain & cmds
AMPENTRY BNE            AMPEXIT                   ;Other & cmds to next routine
         LDY            #0
:LOOP    LDA            CMDNAME,Y
         JSR            COUT
         INY
         CPY            #AMPEND-CMDNAME+1
         BLT            :LOOP
         JSR            CHRGOT
         BEQ            AMPEXIT

         DFB            20                        ;ID byte

MODE     BRK                                      ;SAVE/LOAD flag

CMDNAME  ASC            "HSAVE"
CMDEND   ASC            " or "
LDNAME   ASC            "HLOAD pathname"
AMPEND   HEX            8D

PARSE    LDY            #LDNAME-1
         LDA            IN+1
         AND            #%11011111
         EOR            #"L"
         STA            MODE
         BEQ            :ISL
         LDY            #CMDNAME-1
:ISL     STY            EO+1
         LDX            #CMDEND-CMDNAME-1
         STX            XLEN
         INX
ISIT     LDA            IN-1,X
         AND            #%11011111
EO       EOR            CMDNAME-1,X
         SEC
         BNE            DOSEXIT
         DEX
         BNE            ISIT
         STX            XCNUM
         INX
         STX            PBITS
         LDA            #%00000100                ;Allow S,D parms
         STA            PBITS+1
         STADR          DOSL;XTRNADDR
         CLC
         RTS

DOSL     LDA            FBITS                     ;File name given?
         LSR
         BCS            :GF
         LDA            #6                        ;Syntax error if not
         SEC
         RTS

:GF      TSX
         STX            REMSTK
         LDA            RD80COL                   ;Save machine state
         AND            #$80                      ; (only 80 col, text, mix)
         BIT            RDTEXT
         BMI            :OV
         ORA            #$40
:OV      BIT            RDMIXED
         BMI            :SS
         ORA            #$20
:SS      STA            STATE
         LDX            #0
         LDA            #$20
         STX            GBASL
         STA            GBASH
         STX            RWCOUNT
         STA            RWCOUNT+1
         STX            RWDATA
         STA            RWDATA+1
         STA            HPAG
         STA            STORE80                   ;Turn on double hires
         BIT            $C05E
         STA            COL80ON
         BIT            FULL
         BIT            HIRES
         BIT            GR
         BIT            PAGE2
         LDA            #10
         STA            INFPARMS
         DOS            getinfo
         BCS            MLIERR
         LDA            FILETYPE
         CMP            #6                        ;BIN type
         BEQ            :ST
         EOR            #$F7                      ;or this user type
         BEQ            :ST
         LDA            #13
         SEC
         BCS            MLIERR
:ST      STA            TYPE                      ;Save for branching
         LDA            HIMEM+1
         STA            OSYSBUF+1                 ;Set up buffer
         DOS            open
         BCS            MLIERR
         LDA            OREFNUM
         STA            RWREFNUM                  ;Set R/W ref
         STA            CFREFNUM                  ; close ref
         STA            SREFNUM                   ; seteof & getmark ref
         LDX            TYPE
         BNE            :ISBIN                    ;Branch if BIN file
         STX            RWCOUNT+1
         INX
         INX
         STX            RWDATA+1                  ;Set buffer to $280
         LDA            #$80
         STA            RWDATA
         STA            RWCOUNT                   ;Set for 128 byte read/write
:ISBIN   LDX            #0
         STX            HNDX
         LDY            TYPE
         BNE            BINLS                     ;Branch if no compress
         LDA            MODE
         BEQ            ISLOAD                    ;Branch if load cmd
         BIT            PAGE1
]LUP     JSR            GETBYTE                   ;Make byte to write
         STA            $280,Y
         BIT            FLAG
         BMI            :DONE
         INY
         BPL            ]LUP
:DONE    DOS            write                     ;Write it
         BCS            MLIERR
         LDY            #0
         BIT            FLAG
         BPL            ]LUP                      ;Loop till done
         DOS            getmark
         BCS            MLIERR
         DOS            seteof                    ;In case file is shorter
         BCC            CLOSE
MLIERR   LDX            REMSTK
         TXS
         BIT            PAGE1
         PHP
         PHA
         JSR            CLOSE
         PLA
         PLP
         RTS

ISLOAD   STY            SHAPEL
         JSR            CLRPAG                    ;Clear screen
         BIT            PAGE1
         JSR            CLRPAG
:READL   DOS            read                      ;Get $80 bytes
         BCS            MLIERR
]LUP     PHA                                      ;=0
         JSR            PLOTBYTE                  ;Plot it and its clones
         PLA
         BCS            CLOSE
         ADC            #1
         BPL            ]LUP                      ;Loop till done
         BMI            :READL

CLOSE    DOS            close
         PHA                                      ;Replace machine state
         LDA            #$20                      ; (not incl annunc & 80STORE)
         BIT            STATE
         BNE            :OV1
         STA            MIXED
:OV1     BVS            :OV2
         STA            TEXT
:OV2     BMI            :PULL
         STA            COL80OFF
:PULL    PLA
         RTS

BINLS    LDA            MODE
         BEQ            :ISLOAD
         LDA            #write
         BNE            :RW

:ISLOAD  LDA            #read
:RW      PHA
         JSR            GOSYSTEM                  ;R/W aux screen
         PLA
         BCS            MLIERR
         BIT            PAGE1
         JSR            GOSYSTEM                  ;then main screen
         BCS            MLIERR
         BCC            CLOSE

CLRPAG   LDX            #$20
         STX            SHAPEH
         TYA
:CLRL    STA            (SHAPEL),Y
         INY
         BNE            :CLRL
         INC            SHAPEH
         DEX
         BNE            :CLRL
         RTS

NEXT     INX                                      ;Point to next dot
         CPX            #7
         BLT            :CX4                      ;X is mod 7
         LDX            #0
         LDA            HNDX
         CMP            #39
         BLT            :IH                       ;Branch if no wrap needed
         STX            HNDX                      ;Wrap to left edge
         JSR            DOWN                      ; then move down
         LDA            GBASL
         BNE            :RET
         LDA            GBASH
         CMP            #$20
         BNE            :RET
         RTS                                      ;Carry set signals done
:CX4     CPX            #4                        ;Place where HNDX changes?
         BNE            :RET                      ;Branch if not
:IH      INC            HNDX
:RET     CLC
         RTS

GETBYTE  TYA
         PHA
         JSR            GETDOT                    ;Get screen dot
         STA            BYTE                      ; and save it
         JSR            HCOLOR                    ;Make offset table
         LDA            #$10
         STA            COUNTDWN
         LDA            #-1                       ;Init count
         STA            COUNT
:IC      INC            COUNT
         JSR            NEXT                      ;Point to next position
         BCS            :GOT                      ;Exit if all done
         DEC            COUNTDWN
         BEQ            :GOT                      ;Exit if max count
         LDY            HNDX
         LDA            (GBASL),Y
         AND            MASKM,X                   ;Part of screen dot in main
         CMP            COLM,X
         BNE            :GOTC                     ;Branch if no match
         CPX            #3
         BNE            :NI
         INY
:NI      BIT            PAGE2
         LDA            (GBASL),Y
         BIT            PAGE1
         AND            MASKA,X                   ;Part of dot in aux
         CMP            COLA,X
         BEQ            :IC                       ;Loop if same
:GOTC    CLC                                      ;Signal screen not done
:GOT     ROR            FLAG                      ;Flag done or not
         PLA
         TAY
         LDA            COUNT
         ASL                                      ;Count to high nibble
         ASL
         ASL
         ASL
         ORA            BYTE                      ;Add the color dot
         RTS

PLOTBYTE TAY
         LDA            $280,Y
         LSR
         LSR
         LSR
         LSR
         STA            COUNT                     ;Count of clones
         LDA            $280,Y
         AND            #%1111                    ;Color to plot
         BNE            :JHC
:JN      JSR            NEXT                      ;If black just move ptrs
         BCS            :RET
         DEC            COUNT
         BPL            :JN
         RTS
:JHC     JSR            HCOLOR                    ;Set up color masks
:DOPL    LDY            HNDX
         LDA            (GBASL),Y
         ORA            COLM,X                    ;Plot main mem part
         STA            (GBASL),Y
         CPX            #3
         BNE            :OV
         INY
:OV      BIT            PAGE2
         LDA            (GBASL),Y
         ORA            COLA,X
         STA            (GBASL),Y                 ; then aux mem part
         BIT            PAGE1
         JSR            NEXT                      ;Point to next position
         BCS            :RET                      ;Just in case file wrong
         DEC            COUNT
         BPL            :DOPL                     ;Loop till done
:RET     RTS

GETDOT   LDY            HNDX
         LDA            (GBASL),Y                 ;Get byte from screen
         AND            MASKM,X                   ;Isolate color dot
         BEQ            :AUX                      ;Skip if black
         LDY            SHFTM,X
         BMI            :SL
:SR      LSR                                      ;Shift to proper spot
         DEY
         BNE            :SR
         BEQ            :AUX
:SL      ASL
         INY
         BNE            :SL
:AUX     STA            TEMP                      ;Save main mem part of dot
         LDY            HNDX
         BIT            PAGE2
         CPX            #3
         BNE            :NI
         INY
:NI      LDA            (GBASL),Y
         BIT            PAGE1
         AND            MASKA,X
         BEQ            :OR
         LDY            SHFTA,X
         BEQ            :OR
         BMI            :SLF
:SRT     LSR
         DEY
         BNE            :SRT
         BEQ            :OR
:SLF     ASL
         INY
         BNE            :SLF
:OR      ORA            TEMP                      ;Add aux and main parts
         RTS

HCOLOR   STX            XSAV                      ;Must preserve X
         PHA
         LDX            #6                        ;Set color table according
:CLUP    LDY            INDX,X                    ; to accumulator (<$10)
         AND            #$7F                      ;Must strip high bit
         STA            COLA,Y
         ASL
         DEX
         BPL            :CLUP
         PLA
         LSR
         STA            COLM+5
         LSR
         STA            COLA+3
         LSR
         STA            COLM+1
         LDX            XSAV
         RTS

INDX     DFB            5,9,1,12,4,8,0

SHFTA    DFB            0,4,-1,-2,2,6,-1
SHFTM    DFB            -1,-3,1,5,-1,-1,3

COLA     DFB            %00001111
         DFB            %01110000
         DFB            %00000000
         DFB            %00000011
         DFB            %00111100
         DFB            %01000000
                                                  ;Last byte = first of:
COLM     DFB            %00000000
         DFB            %00000001
         DFB            %00011110
         DFB            %01100000
         DFB            %00000000
         DFB            %00000111
         DFB            %01111000

MASKA    DFB            %00001111
         DFB            %01110000
         DFB            %00000000
         DFB            %00000011
         DFB            %00111100
         DFB            %01000000
                                                  ;Last byte = first of:
MASKM    DFB            %00000000
         DFB            %00000001
         DFB            %00011110
         DFB            %01100000
         DFB            %00000000
         DFB            %00000111
         DFB            %01111000
