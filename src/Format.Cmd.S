********************************
*                              *
*            FORMAT            *
*                              *
*   Glen E. Bredon   1/23/88   *
*                              *
********************************

         DATE

         REL
SAVOBJ   KBD
         DO    SAVOBJ
         DSK   OBJECT/FORMAT.CMD
         FIN

         EXP   OFF
         TR
         TR    ADR

* MLI codes:

blkwrite =     $81
gettime  =     $82

* Apple & ProDOS stuff:

IN       =     $200
MLI      =     $BF00
DEVADR01 =     $BF10
DEVCNT   =     $BF31
DEVLST   =     $BF32
DATE     =     $BF90

* ProDOS BASIC interp locations:

PL       =     $D0
BUFPNT   =     $D2
TEMP     =     $D4
NUMTRAKS =     $D5

STREND   =     $6D
FRETOP   =     $6F
CHRGOT   =     $B7
XTRNADDR =     $BE50      ;External command vector
XLEN     =     $BE52      ;Length of cmd -1 put here
XCNUM    =     $BE53      ;Put 0 here for ext cmd
PBITS    =     $BE54
XRETURN  =     $BE9E
COUT     =     $FDED
MONRTS   =     $FFCB      ;Has RTS (for & linking)

STADR    MAC
         LDA   #]1
         STA   ]2
         LDA   #>]1
         STA   ]2+1
         <<<

DOS      MAC
         JSR   MLI
         DFB   ]1
         DA    ]2
         <<<

         AST   50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   PARSE
DOSEXIT  JMP   XRETURN
AMPEXIT  JMP   MONRTS
AMPENTRY BNE   AMPEXIT
         LDY   #0
:SN      LDA   CMDNAME,Y
         JSR   COUT
         INY
         CPY   #AMPEND-CMDNAME
         BLT   :SN
         JSR   CHRGOT
         BEQ   AMPEXIT

         DFB   33         ;Signature

CMDNAME  ASC   "FORMAT"
CMDEND   ASC   " volname,S#,D#"8D
AMPEND

PARSE    LDX   #CMDEND-CMDNAME
         SEC              ;In case we exit here
:ISIT    LDA   IN-1,X
         AND   #%11011111
         EOR   CMDNAME-1,X
         BNE   DOSEXIT    ;Support daisy chain
         DEX
         BNE   :ISIT
         LDY   #CREDATE-VOLNAME
         TXA
]LUP     STA   VOLNAME-1,Y
         DEY
         BNE   ]LUP
         STX   XCNUM      ;Signal external cmd
         STX   PBITS
         STX   PBITS+1
         STADR XRETURN;XTRNADDR
         LDA   #$60
         STA   UNIT
         LDX   #CMDEND-CMDNAME-1
         BNE   :SKP
]LUP     AND   #$7F
         CMP   #'/'
         BEQ   :SKP
         INY
         CPY   #$10
         BGE   :SYNERR
         STA   VOLNAME,Y
         TYA
         ORA   #$F0
         STA   VOLNAME
:SKP     JSR   GETIN
         CMP   #","
         BEQ   :PARM
         CMP   #$8D
         BNE   ]LUP
         BEQ   DOIT

:PARM    JSR   GETIN
         CMP   #"S"
         BEQ   :SLOT
         CMP   #"D"
         BNE   SYNERR
         ASL   UNIT
         JSR   GETIN
         SEC
         SBC   #"1"
         CMP   #2
:SYNERR  BGE   SYNERR
         LSR
         ROR   UNIT
         BCC   :NEXT      ;Always

:SLOT    JSR   GETIN
         EOR   #"0"
         BEQ   SYNERR
         CMP   #8
         BGE   SYNERR
         ASL
         ASL
         ASL
         ASL
         ASL
         ASL   UNIT
         ROR
         STA   UNIT
:NEXT    JSR   GETIN
         CMP   #$8D
         BEQ   DOIT
         CMP   #","
         BEQ   :PARM
SYNERR   LDA   #11        ;Invalid parameter
         HEX   2C
TOOL     LDA   #14
         HEX   2C
NOPATH   LDA   #6         ;Path not found error
         SEC
         RTS

GETIN    INX
         LDA   IN,X
         CMP   #" "
         BEQ   GETIN
         CMP   #$E0
         BLT   :RET
         AND   #%11011111
:RET     RTS

DOIT     DEX
         STX   XLEN
         LDA   VOLNAME
         BEQ   NOPATH
         LDA   FRETOP+1
         SEC
         SBC   STREND+1
         SBC   #$10
         BCC   TOOL
         LDX   STREND+1
         LDA   STREND
         BEQ   :NI
         INX
:NI      STX   BUFPNT+1
         STX   PL+1
         LDA   UNIT
         STA   $43
         ORA   #$B
         JSR   ISOK
         PHP
         LDA   #280
         LDX   #>280
         LDY   #280/8
         PLP
         BNE   :ISF
         LDA   #1600
         LDX   #>1600
         LDY   #1600/8
:ISF     STA   VOLSIZ
         STX   VOLSIZ+1
         STY   NUMTRAKS
         DOS   gettime;$EAEA
         LDY   #4
:MD      LDA   DATE-1,Y
         STA   CREDATE-1,Y
         DEY
         BNE   :MD
         STY   BUFPNT
         STY   PL
         LDX   #4
]LUP     LDA   BOOTCODE,Y
         CPX   #3
         BLT   :XA
         BNE   :ST
         LDA   BOOTCODE+$100,Y
         BGE   :ST
:XA      TXA
:ST      STA   (PL),Y
         INY
         BNE   ]LUP
         INC   PL+1
         DEX
         BNE   ]LUP
         LDY   #ENDBUF-BLK2-1
]LUP     LDA   BLK2,Y
         STA   (PL),Y
         DEY
         BPL   ]LUP
         LDY   #ENDBUF-BLK2
         TXA
         LDX   #10
:ZBUF    STA   (PL),Y
         INY
         BNE   :ZBUF
         INC   PL+1
         DEX
         BNE   :ZBUF
         LDA   BUFPNT+1
         CLC
         ADC   #2*3       ;blk3
         STA   PL+1
         LDA   #2
         STA   (PL),Y
         TAY
         LDA   #4
         STA   (PL),Y
         INC   PL+1
         INC   PL+1       ;blk4
         LDA   #5
         STA   (PL),Y
         LDY   #0
         LDA   #3
         STA   (PL),Y
         INC   PL+1
         INC   PL+1       ;blk5
         LDA   #4
         STA   (PL),Y
         INC   PL+1
         INC   PL+1       ;blk6
         LDA   #%00000001
         STA   (PL),Y
         LDY   NUMTRAKS
         DEY
         LDA   #$FF
:SBM     STA   (PL),Y
         DEY
         BNE   :SBM
         LDA   UNIT
         JSR   ISOK
         BNE   :UNI
         SEI
         TXA
         JSR   FORMAT
         BCS   :ERR
:WDOS    JSR   WRTDOS
         CLC
:ERR     CLI
:RET     RTS

:UNI     LDA   UNIT
         ORA   #$B
         JSR   ISOK
         BNE   IO
         STA   $42
         STA   $44
         STA   $46
         STA   $47
         LDA   #8
         STA   $45
         LDA   DEVADR01,Y
         STA   PL
         LDA   DEVADR01+1,Y
         STA   PL+1
         JSR   :INDIR
         CPX   #1600
         BNE   IO
         CPY   #>1600
         BNE   IO
         LDA   #3
         STA   $42
:INDIR   BIT   $C08B
         BIT   $C08B
         JSR   INDIR
         BIT   $C082
         BCS   IO
         LDA   $42
         BEQ   :RET
         BCC   :WDOS

WRTDOS   LDA   BUFPNT+1
         STA   WRTBUF+1
         LDA   #0
         STA   WRTBLK
:WRT     DOS   blkwrite;WRTPRMS
         BCS   :ERR
         INC   WRTBUF+1
         INC   WRTBUF+1
         INC   WRTBLK
         LDA   WRTBLK
         CMP   #7
         BLT   :WRT
         RTS

:ERR     PLA
         PLA
IO       LDA   #8
         SEC
         RTS

INDIR    JMP   (PL)

*-------------------------------

BLK2     DA    0
         DA    3
VOLNAME  HEX   F0
         DS    7
         DS    8
         DS    8
CREDATE  DS    4
         DFB   1
         DFB   0
         DFB   %01000001
         DFB   $27
         DFB   $D
         DA    0
         DA    6
VOLSIZ   DA    280

ENDBUF

*---------------------------
*   MLI parameter tables:
*---------------------------

WRTPRMS  DFB   3          ;Parms for block writing
UNIT     DFB   $60
WRTBUF   DA    0
WRTBLK   DA    0

*----------------------------------------------
* Routine to check if device in A is in DEVLST:
*----------------------------------------------

ISOK     LDY   DEVCNT     ;Count for device check
         TAX              ;Save device in X
]LUP     TXA
         EOR   DEVLST,Y
         BEQ   :OK        ;Accept if same
         DEY
         BPL   ]LUP       ;Else keep looking
:TX      TXA
:RET     RTS              ;Z-flag clear if not found

:OK      TXA
         AND   #$F0
         LSR
         LSR
         LSR
         TAY
         LDA   DEVADR01+1,Y
         EOR   #$D0
         ORA   DEVADR01,Y
         BEQ   :RET       :If Disk ][
         TXA
         AND   #$F
         BEQ   :TX
         EOR   #$B
         RTS

         PUT   FORMAT

BOOTCODE HEX   0138B0034C1C09788643C903088A2970
         HEX   4A4A4A4A09C08549A0FF844828C8B148
         HEX   D03AB00EA9038D0008E63DA54948A95B
         HEX   486085408548A05EB148999409C8C0EB
         HEX   D0F6A206BC3209BD390999F209BD4009
         HEX   9D7F0ACA10EEA9098549A986A000C9F9
         HEX   B02F85488460844A844C844E8447C884
         HEX   42C88446A90C8561854B202709B066E6
         HEX   61E661E646A546C90690EFAD000C0D01
         HEX   0CD052A904D002A54A186D230CA8900D
         HEX   E64BA54B4AB006C90AF071A004844AAD
         HEX   2009290FA8B14AD92009D0DB8810F6A0
         HEX   16B14A4A6D1F098D1F09A011B14A8546
         HEX   C8B14A8547A900854AA01E844B8461C8
         HEX   844D202709B035E661E661A44EE64EB1
         HEX   4A8546B14C8547114AD018A201A900A8
         HEX   9160C8D0FBE661E661CA10F438A561E9
         HEX   048561CE1F09D0CA584C00204C470902
         HEX   2650524F444F53A5608544A56185456C
         HEX   4800081E243F454776F4D7D1B64BB4AC
         HEX   A62B18604CBC092058FCA014B9580999
         HEX   B1058810F74C5509D5CEC1C2CCC5A0D4
         HEX   CFA0CCCFC1C4A0D0D2CFC4CFD3A55329
         HEX   032A052BAABD80C0A92CA211CAD0FDE9
         HEX   01D0F7A62B60A5462907C9042903080A
         HEX   282A853DA5474AA5466A4A4A85410A85
         HEX   51A5458527A62BBD89C020BC09E627E6
         HEX   3DE63DB00320BC09BC88C060A5400A85
         HEX   53A9008554A553855038E551F014B004
         HEX   E6539002C65338206D09A55018206F09
         HEX   D0E3A07F8452082838C652F0CE180888
         HEX   F0F50000000000
