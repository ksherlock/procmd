******************************
*                            *
*       TIME BASIC CMD       *
*  Just calls clock driver   *
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
         DSK   OBJECT/TIME.CMD
         FIN

gettime  =     $82
MLI      =     $BF00

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

         DFB   $F1        ;Signature

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
         CLC              ;Tell interpreter we
         RTS              ; accepted command

CMDNAME  ASC   "TIME"
CMDEND   HEX   8D
AMPEND
