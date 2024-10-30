******************************
*                            *
*       POP  BASIC CMD       *
*----------------------------*
*  Glen E. Bredon    6/7/85  *
******************************

         DATE

         REL              ;Generate a LNK file
         TR

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/POP.CMD
         FIN

PNT      =     $9E        ;= FAC+1
CHRGOT   =     $B7
IN       =     $200
COUT     =     $FDED

* ProDOS BASIC interp locations:

XTRNADDR =     $BE50      ;External command vector
XLEN     =     $BE52      ;Length of cmd -1 put here
XCNUM    =     $BE53      ;Put 0 here for ext cmd
PBITS    =     $BE54      ;Parameters, 0 = none (2 bytes)
GOSYSTEM =     $BE70
XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)
SSGPFX   =     $BEAC
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
         JSR   COUT       ;If all modules have this
         INY              ; routine then &<RTN> will
         CPY   #AMPEND-AMPNAME+1
         BLT   :SN        ; give list of all dos cmds.
         JSR   CHRGOT     ;Reestablish A and status
         BEQ   AMPEXIT    ;Go to next routine (always)

         DFB   24         ;Signature

PARSE    LDX   #CMDEND-CMDNAME-1
         STX   XLEN
         INX
         SEC
         LDA   IN+3
         EOR   #$8D
         BEQ   :ISONE     ;Use 1 for POP alone
         INC   XLEN       ;Space for digit
         EOR   #$8D!"0"
         BEQ   DOSEXIT    ;Reject 0
         CMP   #10
         BGE   DOSEXIT    ;Must be 1-9
         LDA   IN+4
         CMP   #$8D
         SEC
         BNE   DOSEXIT    ;Reject extra chars
         BCS   :SETNUM
:ISONE   LDA   #1
:SETNUM  STA   NUM        ;Save # of pops
:ISIT    LDA   IN-1,X
         AND   #%11011111
         EOR   CMDNAME-1,X
         BNE   DOSEXIT    ;Support daisy chain
         DEX
         BNE   :ISIT
         STX   XCNUM      ;Signal external cmd
         STX   PBITS      ;and no parameters
         STX   PBITS+1
         LDA   #:DOIT
         STA   XTRNADDR
         LDA   #>:DOIT
         STA   XTRNADDR+1
:RET     CLC
:BACK    RTS

:DOIT    LDA   #$C7       ;Get prefix
         JSR   GOSYSTEM
         BCS   :BACK
         LDA   SSGPFX+1   ;Get pointer to prefix
         STA   PNT
         LDA   SSGPFX+2
         STA   PNT+1
         LDY   #0
         LDA   (PNT),Y    ;Get length
         TAY
:DY      DEY              ;Examine pfx backwords
         BMI   :RET       ;Exit if none; safety
         BEQ   :CLRPFX    ;Branch if nothing left
         LDA   (PNT),Y
         ASL              ;Accept + or - ascii
         CMP   #"/"*2
         BNE   :DY        ;Loop till a /
         DEC   NUM
         BNE   :DY        ;Loop NUM times
         TYA              ;New pfx length
:SPFX    LDY   #0
         STA   (PNT),Y
         LDA   #$C6       ;Set prefix
         JMP   GOSYSTEM

:CLRPFX  LDA   #1         ;Set null prefix
         BNE   :SPFX

AMPNAME
CMDNAME  ASC   "POP"
CMDEND   ASC   "[#] (levels of prefix)"
AMPEND   HEX   8D

NUM      BRK
