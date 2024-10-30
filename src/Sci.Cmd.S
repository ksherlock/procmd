******************************
*                            *
*      "SCI" BASIC CMD       *
*                            *
*----------------------------*
* Assemble, then use the     *
* RELOC  utility to convert  *
* to a relocating CMD file.  *
*----------------------------*
*  Glen E. Bredon   8/26/85  *
*                            *
******************************

         DATE

         REL              ;Generate a LNK file

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"
         EXP   OFF
         TR

         DO    SAVOBJ
         DSK   OBJECT/SCI.CMD
         FIN

FORML    =     $1B        ;Check slots left of dp
IN       =     $200
TEMPLATE =     $260
COUT     =     $FDED

* Applesoft stuff:

FACSGN   =     $A2
CHRGET   =     $B1
CHRGOT   =     $B7
STACK    =     $100
STROUT   =     $DB3A
FRMEVL   =     $DD7B
FOUT     =     $ED34

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
:SN      LDA   AMPNAME,Y  ;Show our "list" of dos cmds
         JSR   COUT
         INY
         CPY   #AMPEND-AMPNAME+1
         BLT   :SN
         JSR   CHRGOT     ;Reestablish A and status
         BEQ   AMPEXIT    ;Go to next routine (always)

PARSE    SEC              ;Signature = $38
         LDX   #CMDEND-CMDNAME
:ISIT    LDA   IN-1,X
         AND   #%11011111
         EOR   CMDNAME-1,X
         BNE   DOSEXIT    ;Support daisy chain
         DEX
         BNE   :ISIT
         LDY   #PBITS-XTRNADDR+1
:SETUP   STA   XTRNADDR,Y
         LDA   DATA,Y
         DEY
         BPL   :SETUP
         STA   FORML
         BIT   FORML      ;Set V
         LDY   #CMDEND-CMDNAME-1
:GETTEM  INY
         LDA   IN,Y       ;Bypass leading spaces
         BVC   :LUP       ;Branch if over them
         CMP   #" "
         BEQ   :GETTEM
         CLV              ;Clear leading space flag
:LUP     CMP   #"."
         BNE   :ISRET
         ASL   FORML      ;Make it 0 for correct format
:ISRET   EOR   #$8D
         BEQ   :FORMDUN   ;Exit if template done
         CMP   #"#"!$8D
         BNE   :SETLEFT
         ASL   FORML
         BCS   RET        ;Error if format wrong
:SETLEFT EOR   #$8D
:FORMDUN STY   XLEN       ;Needed for last one
         STA   TEMPLATE,X
         BEQ   CC         ;Branch when parsing done
         INX
         BNE   :GETTEM

START    PLA              ;Comes back here
         TAX              ;Allow ProDOS to parse the
         PLA              ; string (setting TXTPTR)
         TAY              ; but force it to pass control
         LDA   #>USING-1  ; back to us.
         PHA
         LDA   #USING-1
         PHA
         TYA
         PHA
         TXA
         PHA
CC       CLC              ;Tell ProDOS all is well
RET      RTS

USING    JSR   CHRGET     ;Point to 1st char of formula
         JSR   FRMEVL     ;Get # to be formatted
         LDA   #' '
         BIT   FACSGN
         BPL   :STT
         LDA   #'-'
:STT     STA   TEMPLATE-1
         LSR   FACSGN     ;Take absolute value
         LDY   #$93-FOUT
         LDA   #$60       ;Insert an RTS
:MVROM   STA   $280,Y     ;Move part of FOUT to ram
         LDA   FOUT-1,Y
         DEY
         BPL   :MVROM
         JSR   $280       ;Do part of formatting
         CPX   #0
         BEQ   :NOMOR     ;Branch for # = 0
         JSR   $ED9E      ;Remainder of FOUT
:FNDZ    INY
         LDA   STACK-1,Y  ;Find end of string and put
         BNE   :FNDZ      ; E+00 after it, in case
:NOMOR   LDA   #'+'       ; no exponent
         JSR   $EE36      ;Part of FOUT that puts the
         LDX   #-1        ; exponent in
         LDY   #-1
:FS      INX
         LDA   TEMPLATE,X ;Find first slot
         BEQ   :IX
         CMP   #"#"
         BNE   :FS
:DPM     INY
         LDA   STACK,Y
         BEQ   :EMPTY     ;Pin Y if at end mark
         CMP   #'.'
         BEQ   :DPM       ;Skip the dp
         CMP   #'E'       ;Pin Y if at E
         BNE   :LT
:EMPTY   DEY              ;Substitute trailing 0's
         LDA   #'0'       ; when needed
:LT      STA   TEMPLATE,X
         BNE   :FS

:IX      INY              ;Find the E
         LDA   STACK,Y    ;It may be our fake one
         CMP   #'E'
         BNE   :IX
:STM     INX
         INY
         LDA   STACK,Y    ;Get the exp sign & 2 digits
         STA   TEMPLATE-1,X
         BNE   :STM
         LDA   #TEMPLATE-1
         LDY   #>TEMPLATE-1
         JMP   STROUT

DATA     DFB   $40
         DA    START,0
         DFB   0

AMPNAME  ASC   """
CMDNAME  ASC   "SCI"
CMDEND   ASC   !#.##E":expr!
AMPEND   HEX   8D
