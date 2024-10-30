********************************
*                              *
* BASIC CMDS: POINTERS & RESET *
*------------------------------*
*   Glen E. Bredon  10/17/84   *
********************************

         DATE

         REL              ;Generate a LNK file

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/POINTERS.CMD
         FIN
         EXP   OFF

KSWL     =     $38
PNT      =     $9B
CHRGOT   =     $B7
IN       =     $200
AMPER    =     $3F5
PRNTAX   =     $F941
COUT     =     $FDED

* ProDOS BASIC interp locations:

AMPCMD   =     $BE03      ;Original & vector points here
EXTRNCMD =     $BE06      ;JMP to external DOS commands
XTRNADDR =     $BE50      ;External command vector
XLEN     =     $BE52      ;Length of cmd -1 put here
XCNUM    =     $BE53      ;Put 0 here for ext cmd
PBITS    =     $BE54      ;Parameters, 0 = none (2 bytes)
XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)
FREBUFR  =     $BEF8
BITMAP   =     $BF58
MONRTS   =     $FFCB      ;Has RTS (for & linking)

* Pointers

         DUMMY $67

TXTTAB   DA    0
VARTAB   DA    0
ARYTAB   DA    0
STREND   DA    0
FRETOP   DA    0
         DA    0          ;FRESPC not significant
MEMTOP   DA    0
         DUMMY $AF
PRGEND   DA    0

         DEND

DATA     MAC
         ASC   ']1'
         DFB   ]1
         <<<

         AST   50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   PARSE      ;These two jumps permit RELOC
DOSEXIT  JMP   XRETURN    ; to daisy chain commands
AMPEXIT  JMP   MONRTS     ;This one to daisy chain & cmds
AMPENTRY BNE   AMPEXIT    ;Other & cmds to next routine
         LDY   #PNTNAME
         JSR   PRINT
         JSR   CHRGOT     ;Reestablish A and status
         BEQ   AMPEXIT    ;Go to next routine (always)

PARSE    LDX   #RESETEND-RESETCMD-1
         LDY   #RESETCMD-1
         LDA   #%01011111
         AND   IN
         CMP   #'P'
         BNE   :SY
         LDY   #PNTNAME-1
         LDX   #PNTEND-PNTNAME-1
:SY      STY   EO+1
         STX   XLEN
         INX
ISRE     LDA   IN-1,X
         AND   #%01011111
EO       EOR   RESETCMD-1,X
         SEC              ;Prepare in case of exit
         BNE   DOSEXIT    ;Support daisy chaining
         DEX
         BNE   ISRE
         CPY   #RESETCMD-1
         STX   XCNUM      ;Signal external cmd
         STX   PBITS      ;and no parameters
         STX   PBITS+1
         LDY   #XRETURN   ;Point this to RTS since
         STY   XTRNADDR   ; we are handling the
         LDA   #>XRETURN  ; parameters (none).
         STA   XTRNADDR+1
         BLT   ISPNT
         STY   EXTRNCMD+1 ;Replace original
         STA   AMPER+2    ; ampersand vector
         STA   EXTRNCMD+2 ; and DOSCMD vector
         LDA   KSWL+1
         CMP   #$9A
         BGE   :NOMAC
         CMP   MEMTOP+1
         BLT   :NOMAC
         STA   PNT+1
         STX   PNT
         LDY   #$22
         LDA   (PNT),Y
         STA   KSWL
         INY
         LDA   (PNT),Y
         STA   KSWL+1
:NOMAC   LDX   #AMPCMD    ;=3
         STX   AMPER+1
:RL      LDA   $F113,X
         STA   $B9,X
         DEX
         BNE   :RL
         LDA   #$3F
         LDY   #19
:SB      STA   BITMAP,Y
         TXA              ;0
         DEY
         BNE   :SB
         JMP   FREBUFR

ISPNT    LDY   #TABLE
PRINT    LDA   DOSENTRY,Y
         BEQ   :BACK
         CMP   #TXTTAB
         BGE   :PPNT
         ORA   #$80
:JCO     JSR   COUT
         INY
         BNE   PRINT
:BACK    CLC              ;Tell interpreter we
         RTS              ; accepted command
:PPNT    TAX              ;Pointer index
         LDA   #"="
         JSR   COUT
         LDA   #"$"
         JSR   COUT
         LDA   1,X        ;High byte of pointer
         PHA
         LDA   0,X        ;Low byte of pointer
         TAX
         PLA
         JSR   PRNTAX
         LDA   #$8D
         BNE   :JCO

PNTNAME  ASC   'POINTERS'
PNTEND   HEX   0D
RESETCMD ASC   'RESET'
RESETEND HEX   0D00

TABLE    HEX   0D0D
         DATA  TXTTAB
         DATA  VARTAB
         DATA  ARYTAB
         DATA  STREND
         DATA  FRETOP
         DATA  MEMTOP
         DATA  PRGEND

         ERR   *-DOSENTRY-$100
