******************************
*                            *
*       DUMP BASIC CMD       *
*----------------------------*
*  Glen E. Bredon  11/12/84  *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/DUMP.CMD
         FIN

         EXP            OFF
         TR

PNT      =              $4E
HIMEM    =              $73
CHRGOT   =              $B7
IN       =              $200
KEY      =              $C000
STROBE   =              $C010
PRNTAX   =              $F941
CROUT    =              $FD8E
PRBYTE   =              $FDDA
COUT     =              $FDED

* ProDOS MLI call codes:

getinfo  =              $C4
open     =              $C8
read     =              $CA
close    =              $CC

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters
FBITS    =              $BE56                     ;Parameter bits found
VADDR    =              $BE58                     ;A parameter
VENDA    =              $BE5D                     ;E parameter
VLNTH    =              $BE5F                     ;L param
GOSYSTEM =              $BE70                     ;Call MLI routine
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
INFPARMS =              $BEB4                     ;GETINFO parm list
FIAUX    =              $BEB9                     ;Aux field of file info
OSYSBUF  =              $BECE                     ;Buffer ptr for OPEN
OREFNUM  =              $BED0                     ;File ref # for OPEN
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
         JSR            COUT                      ;If all modules have this
         INY                                      ; routine then &<RTN> will
         CPY            #AMPEND-CMDNAME
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            3                         ;Signature

PARSE    LDX            #CMDEND-CMDNAME
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
         SEC                                      ;In case we exit here
         BNE            DOSEXIT                   ;Support daisy chain
         DEX
         BNE            :ISIT
         STX            XCNUM                     ;Signal external cmd
         STADR          DODUMP;XTRNADDR
         LDA            #CMDEND-CMDNAME-1
         STA            XLEN                      ;Tell BASIC interp length of cmd
         LDA            #%00010001                ;File name optional
         STA            PBITS
         LDA            #%10110100                ;Allow A,E,L,S,D params
         STA            PBITS+1
         CLC                                      ;Say we accept the cmd
         RTS

CMDNAME  ASC            "DUMP"
CMDEND   ASC            " ,A(start),E(end)[,L(#bytes/line)]"8D
         ASC            "DUMP"
         ASC            " pathname [,L(#bytes/line dflt=16)]"8D
AMPEND

DODUMP   LDA            FBITS
         LSR                                      ;File name given?
         ROR            FIFLAG                    ;Flag it
         BMI            :D1                       ;Branch if so
         LDA            FBITS+1
         AND            #%10100000
         CMP            #%10100000                ;A and E parms got?
         BEQ            :MDMP                     ;Branch if so
         LDA            #11                       ;Syntax error if not
:ERROR   SEC
:MLIERR  RTS

:MDMP    LDA            VADDR                     ;Get adrs param
         LDX            VADDR+1
         STA            FIAUX                     ;Set up fake aux adrs
         STX            FIAUX+1
         SEC
         SBC            #1                        ;Back up one
         BCS            :NB
         DEX
:NB      STA            PNT                       ;Set pntr for mem mode
         STX            PNT+1
:D1      LDA            FBITS+1
         AND            #$10                      ;L param got?
         BEQ            :L16                      ;Branch if not
         LDA            VLNTH                     ;Get L specified
         BEQ            :L16                      ;Use 16 if not valid
         CMP            #33
         BLT            :LOK
:L16     LDA            #16
:LOK     STA            LENGTH
         BIT            FIFLAG
         BPL            :DLOOP                    ;Branch if mem mode
         LDA            #10                       ;# of parms for GETINFO
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
         LDX            #0
         STX            RWCOUNT+1                 ;Set to read 1 byte at a time
         INX
         STX            RWCOUNT
         STADR          IN+$80;RWDATA
:DLOOP   JSR            CROUT
         LDX            FIAUX
         LDA            FIAUX+1
         JSR            PRNTAX                    ;Print adrs
         LDA            #":"
         JSR            COUT
         LDA            LENGTH
         TAX
         CLC
         ADC            FIAUX
         STA            FIAUX                     ;Set up next adrs of line
         BCC            :RDBYT
         INC            FIAUX+1
         CLC                                      ;Signal not done
:RDBYT   BCS            :NOR
         BIT            FIFLAG
         BPL            :MEM                      ;Branch if mem mode
         DOS            read                      ;Read a byte
         BCC            :GETBUF
         BIT            STROBE                    ;Clear strobe if error
         CMP            #5                        ;End of file?
         BEQ            :NOR
         SEC                                      ;Signal dos err
         RTS
:CLOSE   CLC                                      ;In case in mem mode
         BIT            FIFLAG
         BPL            :BAK                      ;Skip close if mem mode
         DOS            close                     ;Close file
:BAK     RTS

:NOR     LDY            #3
:NL      LDA            #" "
         STA            IN+$80,X                  ;Blank out unread bytes
         JSR            COUT
         DEY
         BNE            :NL
         SEC
         BCS            :DX

:MEM     LDY            #0
         LDA            PNT
         CMP            VENDA
         LDA            PNT+1
         SBC            VENDA+1                   ;Past end of range?
         INC            PNT
         BNE            :NI
         INC            PNT+1
         BNE            :NI
         CLC                                      ;In case A0
:NI      LDA            PNT+1
         EOR            #$C0
         BEQ            :NOR                      ;Don't read switches
         LDA            (PNT),Y
         STA            IN+$80
         BCS            :NOR                      ;Branch if range done
:GETBUF  LDA            IN+$80                    ;Get byte read
         PHA
         ORA            #$80
         CMP            #" "
         BGE            :STI
         LDA            #"."                      ;Substitute "." for controls
:STI     STA            IN+$80,X                  ;Save for printing later
         PLA
         JSR            PRBYTE                    ;Print hex byte
         LDA            #" "
         JSR            COUT
         CLC
:DX      DEX
         BNE            :RDBYT                    ;Loop if line not done
         PHP
         LDX            LENGTH
:PAS     LDA            IN+$80,X
         JSR            COUT
         DEX
         BNE            :PAS
         PLP
         BCS            :CLOSE                    ;Branch if all done
         LDA            KEY                       ;Key down?
         BPL            :JLOOP                    ;Loop if not
         BIT            STROBE
         CMP            #"C"&$9F
         BEQ            :CLOSE                    ;Abort on ^C
         CMP            #" "
         BNE            :JLOOP                    ;Loop if not space
:WAIT    LDA            KEY                       ;Wait for another key
         BPL            :WAIT
:JLOOP   JMP            :DLOOP                    ;Don't clear strobe yet

LENGTH   DFB            16
FIFLAG   BRK                                      ;+ if mem mode
