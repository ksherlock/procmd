******************************
*                            *
*       DATE BASIC CMD       *
*                            *
*----------------------------*
* Assemble, then use the     *
* RELOC  utility to convert  *
* to a relocating CMD file.  *
*----------------------------*
*  Glen E. Bredon   12/7/84  *
*                            *
******************************

         DATE

         REL              ;Generate a LNK file
         TR

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/DATE.CMD
         FIN

gettime  =     $82
MLI      =     $BF00
DATE     =     $BF90
TIME     =     DATE+2

TEMP     =     $4E        ;Scratch
CHRGOT   =     $B7
IN       =     $200
COUT     =     $FDED

* ProDOS BASIC interp locations:

XTRNADDR =     $BE50      ;External command vector
XLEN     =     $BE52      ;Length of cmd -1 put here
XCNUM    =     $BE53      ;Put 0 here for ext cmd
PBITS    =     $BE54      ;Parameters, 0 = none (2 bytes)
XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)
MONRTS   =     $FFCB      ;Has RTS (for & linking)

         AST   50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   PARSE      ;These two jumps permit RELOC
DOSEXIT  JMP   XRETURN    ; to daisy chain commands
AMPEXIT  JMP   MONRTS     ;This one to daisy chain & cmds
AMPENTRY BNE   AMPEXIT    ;Other & cmds to next routine
         LDY   #0
:SN      LDA   CMDNAME,Y  ;Show our "list" of dos cmds
         JSR   COUT       ;If all modules have this
         INY              ; routine then &<RTN> will
         CPY   #AMPEND-CMDNAME
         BLT   :SN        ; give list of all dos cmds.
         JSR   CHRGOT     ;Reestablish A and status
         BEQ   AMPEXIT    ;Go to next routine (always)

         DFB   7          ;Signature

PARSE    LDX   #CMDEND-CMDNAME-1
         STX   XLEN
         INX
:ISIT    LDA   IN-1,X
         AND   #%11011111
         EOR   CMDNAME-1,X
         SEC              ;In case we exit here
         BNE   DOSEXIT    ;Support daisy chain
         DEX
         BNE   :ISIT
         STX   XCNUM      ;Signal external cmd
         STX   PBITS      ;and no parameters
         STX   PBITS+1
         LDA   #XRETURN
         STA   XTRNADDR
         LDA   #>XRETURN
         STA   XTRNADDR+1
         JSR   MLI
         DFB   gettime
         NOP
         NOP
         LDA   DATE
         BNE   :PRDATE
         LDY   #NDEND-NODATE-1
:LP      LDA   NODATE,Y
         JSR   COUT
         DEY
         BPL   :LP
         BMI   :OVER
:PRDATE  PHA
         AND   #%11111
         JSR   PR2DIG
         LDA   #"-"
         JSR   COUT
         LDA   DATE+1
         LSR
         STA   TEMP
         PLA
         ROR
         AND   #$F0
         LSR
         LSR
         TAX
         LDY   #4
:PM      LDA   MONTHS-4,X
         JSR   COUT
         INX
         DEY
         BNE   :PM
         LDA   TEMP
         JSR   PRBYTDEC
:OVER    LDA   #" "
         JSR   COUT
         JSR   COUT
         LDA   TIME+1
         JSR   PR2DIG
         LDA   #":"
         JSR   COUT
         LDA   TIME
PRBYTDEC JSR   DIV10
CPD      PHA
         TXA
         JSR   COUT
         PLA
         JSR   COUT
         CLC              ;Tell interpreter we
         RTS              ; accepted command

PR2DIG   CMP   #10
         BGE   PRBYTDEC
         LDX   #" "
         ORA   #"0"
         BNE   CPD

DIV10    LDX   #"0"-1
         SEC
:L       INX
         SBC   #10
         BCS   :L
         ADC   #"0"+10
         RTS

MONTHS   ASC   "JAN-"
         ASC   "FEB-"
         ASC   "MAR-"
         ASC   "APR-"
         ASC   "MAY-"
         ASC   "JUN-"
         ASC   "JUL-"
         ASC   "AUG-"
         ASC   "SEP-"
         ASC   "OCT-"
         ASC   "NOV-"
         ASC   "DEC-"

NODATE   REV   "DD-MMM-YY"
NDEND

CMDNAME  ASC   "DATE"
CMDEND   HEX   8D
AMPEND
