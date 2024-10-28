********************************
*                              *
*    HEXDEC   BASIC COMMAND    *
*                              *
*    Glen Bredon     6/24/85   *
*                              *
********************************

         DATE

         EXP            OFF
         TR
         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/HEXDEC.CMD
         FIN

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

LINNUM   =              $50
FAC      =              $9D
CHRGOT   =              $B7
TXTPTR   =              $B8
IN       =              $200
FRMNUM   =              $DD67
GETADR   =              $E752
PRFAC    =              $ED28
PRNTAX   =              $F941
COUT     =              $FDED

ACCUM    =              FAC+1

         AST            50

STADR    MAC
         LDA            #]1
         STA            ]2
         LDA            #>]1
         STA            ]2+1
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
:PA      LDA            AMPNAME,Y
         JSR            COUT
         INY
         CPY            #AMPEND-AMPNAME
         BLT            :PA
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            22                        ;ID byte

PARSE    LDA            IN
         AND            #%11011111
         BIT            MONRTS                    ;Set V
         EOR            #"D"
         BEQ            :ISOURS
         EOR            #"D"!"H"
:DOSEX   SEC
         BNE            DOSEXIT
         CLV                                      ;V clear for hex mode
:ISOURS  TAX                                      ;=0
         TAY
:NY      INY
:NX      INX
         BMI            :DOSEX
         LDA            IN,X
         CMP            #"-"
         BNE            :ISRTN
         BVC            DOSEXIT                   ;Reject - for hex
         LDA            #$C9                      ;Token for -
         CLC
         BCC            :STOR
:ISRTN   EOR            #$8D
         BEQ            :GOTIT
         EOR            #" "!$8D
         BEQ            :NX
         EOR            #"0"!" "
         CMP            #10
         BLT            :OR
         BVS            DOSEXIT                   ;Reject if decimal mode
         ADC            #$88
         ORA            #$20                      ;Allow lc input
         CMP            #$FA
         BLT            :DOSEX                    ;Reject if not hex digit
         CLC
         CLV                                      ;Signal hex mode
:OR      ORA            #'0'                      ;Applesoft format & avoid 0
:STOR    STA            IN+$80,Y
         BLT            :NY                       ;Always

:GOTIT   STA            IN+$80,Y
         DEX
         STX            XLEN                      ;Claim total string
         STA            XCNUM                     ;Signal external cmd
         STA            PBITS
         STA            PBITS+1
         STADR          START;XTRNADDR
         RTS                                      ;Carry is clear

AMPNAME  ASC            "D<dec #> or H<hex #>"8D
AMPEND

START    PLA
         TAX
         PLA
         TAY
         LDA            #>CONT-1
         PHA
         LDA            #CONT-1
         PHA
         TYA
         PHA
         TXA
         PHA
         CLC
         RTS

CONT     LDX            #0
         LDA            IN
         AND            #%11011111
         CMP            #"D"
         BEQ            DECHEX                    ;Branch if decimal mode
         STX            ACCUM+1
         STX            ACCUM
:MAKADR  LDA            IN+$81,X                  ;Get an ascii digit
         BEQ            :GOT
         ASL                                      ;Move to high nibble
         ASL
         ASL
         ASL
         LDY            #4
:ROT     ASL                                      ;Rotate digit into ACCUM
         ROL            ACCUM+1                   ;NOTE: order used by
         ROL            ACCUM                     ; Applesoft
         DEY
         BNE            :ROT
         INX
         BNE            :MAKADR                   ;Always

:GOT     JSR            PRFAC                     ;Print decimal address
BACK     LDA            #$8D                      ;Needed?
         NOP                                      ;To enable subst: JSR CROUT
         LDX            #0
         STA            IN
         RTS

DECHEX   LDA            TXTPTR                    ;Save TXTPTR
         PHA
         LDA            TXTPTR+1
         PHA
         LDA            #>IN+$81                  ;Point to our decimal string
         STA            TXTPTR+1
         LDA            #IN+$81
         STA            TXTPTR
         JSR            FRMNUM                    ;Float it
         JSR            GETADR                    ;Make integer in LINNUM
         PLA                                      ;Restore TXTPTR
         STA            TXTPTR+1
         PLA
         STA            TXTPTR
         LDA            #"$"
         JSR            COUT
         LDA            LINNUM+1                  ;Print the hex #
         LDX            LINNUM
         JSR            PRNTAX
         JMP            BACK
