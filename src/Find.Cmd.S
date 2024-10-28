******************************
*                            *
*       FIND BASIC CMD       *
*                            *
*  Glen E. Bredon  12/23/84  *
*                            *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/FIND.CMD
         FIN

         EXP            OFF
         TR

HIMEM    =              $73
CHRGOT   =              $B7
LEN      =              $E0
MARK     =              $E1                       ;3 bytes
TEMP     =              $E4
HEXFLAG  =              $E5
IN       =              $200
FILESTR  =              IN+$40
STRING   =              IN+$C0
KEY      =              $C000
STROBE   =              $C010
CROUT    =              $FD8E
PRBYTE   =              $FDDA
COUT     =              $FDED

* ProDOS MLI call codes:

getinfo  =              $C4
open     =              $C8
newline  =              $C9
read     =              $CA
close    =              $CC

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters
FBITS    =              $BE56                     ;Parameter bits found
VADDR    =              $BE58                     ;A param value
GOSYSTEM =              $BE70                     ;Call MLI routine
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
INFPARMS =              $BEB4                     ;GETINFO parm list
OSYSBUF  =              $BECE                     ;Buffer ptr for OPEN
OREFNUM  =              $BED0                     ;File ref # for OPEN
NEWLREF  =              $BED2                     ;Ref # for NEWLINE
NLINENBL =              $BED3                     ;NEWLINE enable (0=disable)
RWREFNUM =              $BED6                     ;Ref # for read/write
RWDATA   =              $BED7                     ;Buffer ptr for read/write
RWCOUNT  =              $BED9                     ;# of bytes to read/write
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

DOSENTRY JMP            PARSE                     ;These two jumps permit RELOC
DOSEXIT  JMP            XRETURN                   ; to daisy chain commands
AMPEXIT  JMP            MONRTS                    ;This one to daisy chain & cmds
AMPENTRY BNE            AMPEXIT                   ;Other & cmds to next routine
         LDY            #0
:SN      LDA            CMDNAME,Y                 ;Show our "list" of dos cmds
         CMP            #"!"
         BNE            :JC
         LDX            #EXTEND-EXT-1
:LX      LDA            EXT,X
         JSR            COUT
         DEX
         BPL            :LX
         LDA            #$8D
:JC      JSR            COUT                      ;If all modules have this
         INY                                      ; routine then &<RTN> will
         CPY            #AMPEND-CMDNAME
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

PARSE    LDX            #CMDEND-CMDNAME
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
         SEC                                      ;In case we exit here
         BNE            DOSEXIT                   ;Support daisy chain
         DEX
         BNE            :ISIT
         LDY            #CMDEND-CMDNAME+1
         LDA            IN+4
         EOR            #" "
         BEQ            :ASC
         EOR            #" "!"$"
         BNE            DOSEXIT
         ROR
         ROR
:ASC     STA            HEXFLAG                   ;V bit to test hex mode
:NX      LDA            IN,Y
         CMP            #","
         BEQ            :PARSED
         BIT            HEXFLAG
         BVC            :ISWILD
         JSR            ASCHEX
         BCS            :STORE
         BCC            DOSEXIT
:ISWILD  CMP            #"^"                      ;Wild card
         BNE            :UP
         LDA            #0
:UP      CMP            #$E0
         BLT            :STORE
         AND            #%11011111                ;-> upper case
:STORE   STA            STRING,X
         INX
         CPX            #$40
         BGE            DOSEXIT
         INY
         BNE            :NX                       ;Always
:PARSED  STX            LEN
         STY            XLEN
         LDA            #"X"                      ;Space or comma not liked
:FX      STA            IN,Y
         DEY
         BPL            :FX
         LDA            #0
         STA            XCNUM                     ;Signal external cmd
         STADR          DOFIND;XTRNADDR
         LDA            #%00000001                ;File name expected
         STA            PBITS
         LDA            #%10000100                ;Allow A,S,D params
         STA            PBITS+1
         CLC                                      ;Say we accept the cmd
         RTS

CMDNAME  ASC            "FIND"
CMDEND   ASC            "!FIND$ hex!"
AMPEND
EXT      REV            " string,pathname[,A offset]"
EXTEND

DOFIND   LDA            FBITS
         LSR                                      ;File name given?
         BCS            :F1
         LDA            #11                       ;Syntax error if not
:ERROR   SEC
:MLIERR  RTS

:F1      LDA            #10                       ;# of parms for GETINFO
         STA            INFPARMS
         DOS            getinfo
         BCS            :MLIERR
         LDA            HIMEM+1                   ;Address high of system buffer
         STA            OSYSBUF+1
         DOS            open                      ;Open the file
         BCS            :MLIERR
         LDA            OREFNUM                   ;Get file's ref #
         STA            RWREFNUM                  ; READ,
         STA            CFREFNUM                  ; and CLOSE.
         STA            NEWLREF
         LDX            #0
         STX            NLINENBL                  ;Defeat NEWLINE
         LDA            VADDR
         LDY            VADDR+1
         BIT            FBITS+1                   ;If A param given
         BMI            :SM                       ; then use it
         TXA                                      ;Else use 0
         TAY
:SM      STA            MARK
         STY            MARK+1
         STX            MARK+2
         STX            RWCOUNT+1
         LDX            LEN
         STX            RWCOUNT
         STADR          FILESTR;RWDATA
         DOS            newline
         BCS            :MLIERR

:READLUP DOS            read
         BCC            :ROK
         CMP            #5                        ;EOF?
         SEC
         BNE            :RET
:CLOSE   DOS            close
:RET     BIT            STROBE
         RTS

:ROK     LDA            #1                        ;This only needed 1st time
         STA            RWCOUNT
         LDX            LEN                       ;Init string index
         TXA
         ADC            #FILESTR-1
         STA            RWDATA                    ;Read to last character
:COMP    LDA            FILESTR-1,X
         BIT            HEXFLAG
         BVC            :ASC                      ;Branch if ascii mode
         CMP            STRING-1,X
         BEQ            :YES
         BNE            :NO
:ASC     ORA            #$80
         CMP            #$E0
         BLT            :EO
         AND            #%11011111                ;-> upper case
:EO      STA            TEMP
         EOR            STRING-1,X
         BEQ            :YES
         CMP            TEMP                      ;Wild?
         BNE            :NO
:YES     DEX
         BNE            :COMP
         LDX            #3
:PM      LDA            MARK-1,X
         JSR            PRBYTE                    ;Print file position
         DEX
         BNE            :PM
         BIT            HEXFLAG
         BVS            :CR                       ;Branch if hex mode
         LDA            #" "
         JSR            COUT
:PSTR    LDA            FILESTR,X
         ORA            #$80
         CMP            #" "
         BGE            :PRIT
         LDA            #"."                      ;Substitute for controls
:PRIT    JSR            COUT
         INX
         CPX            LEN
         BLT            :PSTR
:CR      JSR            CROUT
         LDA            KEY
         BPL            :NOK
:BST     BIT            STROBE
         CMP            #"C"&$9F
         BEQ            :CLOSE
         CMP            #" "
         BNE            :NOK
:WAIT    LDA            KEY
         BPL            :WAIT
:NO      LDA            KEY
         CMP            #"C"&$9F
         BEQ            :CLOSE
:NOK     INC            MARK
         BNE            :MV
         INC            MARK+1
         BNE            :MV
         INC            MARK+2
:MV      LDX            #0                        ;Make room for next byte
:MOVE    LDA            FILESTR+1,X
         STA            FILESTR,X
         INX
         CPX            LEN
         BLT            :MOVE
         JMP            :READLUP

NY       INY
         LDA            IN,Y
ASCHEX   CMP            #" "
         BEQ            NY
         JSR            :MAKNIB
         ASL
         ASL
         ASL
         ASL
         STA            TEMP
         INY
         LDA            IN,Y
         JSR            :MAKNIB
         ORA            TEMP
         SEC                                      ;Signal hex byte ok
         RTS

:MAKNIB  EOR            #"0"
         CMP            #10
         BLT            :GOTNIB
         ADC            #$88
         CMP            #$FA
         BGE            :GOTNIB
         PLA                                      ;Pop return to ASCHEX
         PLA                                      ; and get error
:GOTNIB  AND            #$F
         RTS
