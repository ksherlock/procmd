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
         DSK   OBJECT/RND.CMD
         FIN

         EXP   OFF
         TR
         TR    ADR

* ProDOS BASIC interp locations:

USRJMP   =     $A
FAC      =     $9D
FACSGN   =     $A2
EXTRA    =     $AC
SEED     =     $C9
CHRGOT   =     $B7
IN       =     $200
XTRNADDR =     $BE50      ;External command vector
XLEN     =     $BE52      ;Length of cmd -1 put here
XCNUM    =     $BE53      ;Put 0 here for ext cmd
PBITS    =     $BE54
XRETURN  =     $BE9E
COUT     =     $FDED
MONRTS   =     $FFCB      ;Has RTS (for & linking)

SIGNIF   =     $E82E

AD       MAC
         LDA   FAC+]1
         ADC   SEED+]1
         STA   FAC+]1
         <<<

ROT      MAC
         LDA   SEED+]1
         ROL
         STA   FAC+]1
         <<<

STADR    MAC
         LDA   #]1
         STA   ]2
         LDA   #>]1
         STA   ]2+1
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

         DFB   34         ;Signature

CMDNAME  ASC   "RND"
CMDEND   HEX   8D
AMPEND

PARSE    LDX   #CMDEND-CMDNAME-1
         STX   XLEN
         INX
         SEC              ;In case we exit here
:ISIT    LDA   IN-1,X
         AND   #%11011111
         EOR   CMDNAME-1,X
         BNE   DOSEXIT    ;Support daisy chain
         DEX
         BNE   :ISIT
         STX   XCNUM      ;Signal external cmd
         STX   PBITS
         STX   PBITS+1
         STADR XRETURN;XTRNADDR
         LDA   $4E
         STA   SEED+1
         STA   SEED+3
         LDA   $4F
         STA   SEED+2
         STA   SEED+4
         LDA   #$80
         STA   SEED
         LDA   #$4C
         STA   USRJMP
         STADR RANDOM;USRJMP+1
         CLC
         RTS

********************************
*                              *
*           RANDOM             *
*                              *
*   Glen E. Bredon    4/4/85   *
*                              *
*(2^25+2^16+5)*X + 1 (mod 2^32)*
*                              *
********************************

* To use: Set up USR address to point here.
* (The routine is completely relocatable.)
* Issue USR(1) wherever you would use RND(1).
* The routine uses the usual RND seed, so it
* can be seeded with RND(-R), etc.

RANDOM   LDA   SEED+4     ;Seed * 2 to fac
         ASL
         STA   FAC+4
         ROT   3
         ROT   2
         ROT   1
         SEC              ;To add 1
         ROL   FAC+4      ;Seed * 4 + 1
         ROL   FAC+3
         ROL   FAC+2
         ROL   FAC+1
         CLC
         AD    4          ;Seed * 5 + 1
         TAX
         AD    3
         TAY
         AD    2
         AD    1
         CLC
         LDA   FAC+2      ;Seed * 5 + 1 + seed * 2^16
         ADC   SEED+4     ; = seed * (2^16+5) + 1
         STA   SEED+2
         STA   FAC+2
         LDA   FAC+1
         ADC   SEED+3
         ASL   SEED+4     ;Remove these
         CLC              ; lines for the
         ADC   SEED+4     ; multiplier 2^16+5
         STA   SEED+1
         STA   FAC+1
         STY   SEED+3
         STX   SEED+4
         LDA   #$80
         STA   FAC        ;Normalize < 1
         ASL
         STA   EXTRA
         STA   FACSGN
         JMP   SIGNIF     ;Float and return
