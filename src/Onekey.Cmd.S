********************************
*                              *
*    ONEKEY   BASIC COMMAND    *
*                              *
*    Glen Bredon    6/25/85    *
*                              *
********************************

         DATE

         EXP   OFF
         TR
         REL              ;Generate a LNK file

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/ONEKEY.CMD
         FIN

* ProDOS BASIC interp locations:

PREGX    =     $BE3F
XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)
MONRTS   =     $FFCB      ;Has RTS (for & linking)

         AST   50

PROMPT   =     $33
CHRGOT   =     $B7
IN       =     $200
COUT     =     $FDED


         AST   50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   PARSE      ;These two jumps permit RELOC
DOSEXIT  JMP   XRETURN    ; to daisy chain commands
AMPEXIT  JMP   MONRTS     ;This one to daisy chain & cmds
AMPENTRY BNE   AMPEXIT    ;Other & cmds to next routine
         LDY   #0
:PA      LDA   AMPNAME,Y
         BEQ   :RET
         JSR   COUT
         INY
         BNE   :PA
:RET     JSR   CHRGOT     ;Reestablish A and status
         BEQ   AMPEXIT    ;Go to next routine (always)

         DFB   23         ;ID byte

AMPNAME  ASC   "One key commands: "
CMDNAMES ASC   "ARLEM"8D

         DS    12         ;Room for 11 more

PARSE    LDA   PROMPT     ;Ignore if not from
         CMP   #"]"       ; Applesoft
         SEC
         BNE   :EXIT
         LDA   IN+1
         CMP   #":"
:EXIT    BGE   DOSEXIT    ;Reject if more alpha
         LDX   #-1
:LOOK    INX
         LDA   CMDNAMES-1,X
         CMP   #$8D
         BEQ   DOSEXIT
         EOR   IN
         AND   #%11011111 ;Allow lc
         BNE   :LOOK
         TAY              ;=0
:FE      INY
         LDA   IN,Y       ;Find end of cmd
         CMP   #$8D
         BNE   :FE
         TXA              ;Protect cmd index
         PHA
         TYA              ;Length of cmd
         ADC   RESTPNT,X
         SBC   RESTPNT-1,X
         SBC   #2         ;Leaves carry set
         TAX
         STX   PREGX      ;Fake out BASIC.SYSTEM
:MV      LDA   IN,Y       ;Move cmd up
         STA   IN,X
         DEX
         DEY
         BNE   :MV
         PLA
         TAX              ;Restore cmd index
         LDY   RESTPNT-1,X ;Point to substitute
         LDX   #0
:RST     LDA   CMDS,Y
         BEQ   :EXIT      ;Command is never accepted
         STA   IN,X       ;Make full cmd
         INX
         INY
         BNE   :RST

RESTPNT  DFB   0,REN-CMDS,LIST-CMDS,EDIT-CMDS
         DFB   MON-CMDS,END-CMDS

         DS    11

CMDS     ASC   "AUTO"00
REN      ASC   "RENUMBER"00
LIST     ASC   "LIST"00
EDIT     ASC   "EDIT"00
MON      ASC   "CALL-151"00
END      DFB   0
         DS    END&END&$FF!$FF
