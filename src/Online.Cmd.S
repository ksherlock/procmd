******************************
*                            *
*      ONLINE BASIC CMD      *
*----------------------------*
*  Glen E. Bredon   6/25/85  *
******************************

         DATE

         REL                                      ;Generate a LNK file
         TR

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/ONLINE.CMD
         FIN

MEMTOP   =              $73
CHRGOT   =              $B7
IN       =              $200
CROUT    =              $FD8E
COUT     =              $FDED

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters, 0 = none (2 bytes)
GOSYSTEM =              $BE70
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
SUNIT    =              $BEC7
SBUF     =              $BEC8
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

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
         CPY            #CMDEND-CMDNAME+1
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            0                         ;Signature

PARSE    LDX            #CMDEND-CMDNAME-1
         STX            XLEN
         INX
         SEC                                      ;In case we exit here
:ISIT    LDA            IN-1,X
         AND            #%11011111
:EC      EOR            CMDNAME-1,X
         BNE            DOSEXIT                   ;Support daisy chain
         DEX
         BNE            :ISIT
         STX            XCNUM                     ;Signal external cmd
         STX            PBITS                     ;and no parameters
         STX            PBITS+1
         LDA            #:DOIT
         STA            XTRNADDR
         LDA            #>:DOIT
         STA            XTRNADDR+1
         STX            SUNIT
         STX            SBUF
         LDA            MEMTOP+1
         STA            SBUF+1
         CLC
         RTS

:DOIT    LDA            #$C5
         JSR            GOSYSTEM
         BCC            SHOWIT
         RTS

CMDNAME  ASC            "ONLINE"
CMDEND   HEX            8D

SHOWIT   JSR            CROUT
         JSR            CROUT
         LDY            #0
SHOWLOOP LDA            (MEMTOP),Y                ;Length and slot, drive
         TAX
         AND            #$F                       ;Get length
         BEQ            NXT                       ;Skip if 0
         PHA                                      ;Save length
         TXA
         LSR                                      ;Get high nibble
         LSR
         LSR
         LSR
         CMP            #8                        ;Distinguish drives
         AND            #7
         TAX                                      ;Save slot
         LDA            #"1"
         ADC            #0                        ;Drive number
         PHA
         TYA                                      ;Must protect Y
         PHA
         LDY            #0
:L1      LDA            SLOT,Y
         BEQ            :L2
         JSR            COUT
         INY
         BNE            :L1
:L2      TXA
         ORA            #"0"
         JSR            COUT                      ;Print slot #
         LDY            #0
:L3      LDA            DRIVE,Y
         BEQ            :L4
         JSR            COUT
         INY
         BNE            :L3
:L4      PLA                                      ;Retrieve Y
         TAY
         PLA                                      ;Drive #
         JSR            COUT
         LDX            #0
:PN      LDA            NAME,X
         BEQ            :NP
         JSR            COUT
         INX
         BNE            :PN
:NP      PLA                                      ;Length of vol name
         TAX
:LI      INY
         LDA            (MEMTOP),Y
         ORA            #$80
         JSR            COUT                      ;Print vol name
         DEX
         BNE            :LI
         JSR            CROUT
NXT      TYA
         AND            #$F0                      ;Point to next one
         CLC
         ADC            #$10
         TAY
         BNE            SHOWLOOP                  ;Loop till done
         CLC                                      ;Signal command accepted
         RTS                                      ;Return to ProDOS

SLOT     ASC            "SLOT "00
DRIVE    ASC            ", DRIVE "00
NAME     ASC            ", NAME: "00
