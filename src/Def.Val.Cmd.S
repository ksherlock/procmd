*****************
*               *
*    DEF&VAL    *
*               *
*  Glen Bredon  *
*               *
*    2/1/85     *
*               *
* Orig: 9/15/80 *
*               *
*****************

         DATE

         REL              ;Generate a LNK file
         TR
         EXP   OFF

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/DEF.VAL.CMD
         FIN

* "&DEF A$" will tokenize A$ and append a zero.
* After A$ has been altered (once is enough)
* by &DEF then "&VAL A$ TO V" (any real
* variable) will compute the value of A$
* [even with arithmetic operations, functions
* (SIN, etc.) and variables (eg. PI)] and then
* place the result in V.

* "&VAL A$" does not change A$ as does "&DEF A$".

*****   EXAMPLE   *****

* 10 PI=3.1416
* 20 INPUT F$:REM:say "SIN(X)"
* 30 &DEF F$
* 40 X=PI/2
* 50 &VAL F$ TO Y
* 60 PRINT Y

* Results in Y=1 (=SIN(PI/2))

****************************

* Data (tokens):

to       =     193
def      =     184
val      =     229

* Applesoft usage, etc:

DATAFLG  =     $13        ;Used by parser
FRETOP   =     $6F        ;Start of string space
VARPNT   =     $83        ;Variable pointer
CHRGET   =     $B1
CHRGOT   =     $B7
TXTPTR   =     $B8
IN       =     $200
PARSE    =     $D56C
FRMNUM   =     $DD67
CHKSTR   =     $DD6C
PTRGET   =     $DFE3
GETSPA   =     $E452
MOVSTR   =     $E5E2
MOVMF    =     $EB2B
MONRTS   =     $FFCB      ;Has RTS (for & linking)
XRETURN  =     $BE9E      ;Has RTS (for dos cmd linking)


         AST   50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   DOSEXIT
DOSEXIT  JMP   XRETURN    ;To daisy chain commands
AMPEXIT  JMP   MONRTS     ;This one to daisy chain & cmds
AMPENTRY BEQ   AMPEXIT    ;Other & cmds to next routine
         PHP              ;Carry is set by any token
         CMP   #val
         BEQ   GETPTR
         CMP   #def
         CLC
         BEQ   DEF
         PLA
         JSR   CHRGOT
         BNE   AMPEXIT

         DS    2          ;Filler

         DFB   $FE        ;Signature

DEF      PLA              ;Pop status from stack
         PHP              ;Remember carry status
GETPTR   JSR   CHRGET     ;Move TXTPTR to string variable
         JSR   PTRGET     ;Get pointer to descriptor
         JSR   CHKSTR     ;Make sure it is a string
         PLP              ;Recall mode (used for BCC later)
         LDA   TXTPTR     ;Save TXTPTR
         PHA
         LDA   TXTPTR+1
         PHA
         LDY   #2
         LDA   (VARPNT),Y ;Pick up address of string
         STA   TXTPTR+1   ;Put it in TXTPTR
         DEY
         LDA   (VARPNT),Y
         STA   TXTPTR
         BCC   DEFTOK     ;Branch if a & DEF
         JSR   FRMNUM     ;Evaluate formula
         PLA              ;Retrieve TXTPTR
         STA   TXTPTR+1
         PLA
         STA   TXTPTR
         JSR   CHRGOT     ;Get next token
         CMP   #to        ;Syntax check
         BNE   BACK       ;Get syntax error if not
         JSR   CHRGET     ;Get destination variable
         JSR   PTRGET     ;Find its pointer, or make one
         TAX              ;Pointer now in X,Y
         JMP   MOVMF      ;Move value to variable
                          ; and return to caller.

DEFTOK   DEY              ;Y now has 0
         LDA   (VARPNT),Y ;Get length of string
         TAY
         LDA   #0
         STA   IN,Y       ;Put 0 at end of string
         DEY
MOVE     LDA   (TXTPTR),Y
         STA   IN,Y       ;Move string to input buffer
         DEY
         BPL   MOVE
         LDY   #4         ;Set Y for parse routine
         STY   DATAFLG    ;Init DATAFLG to +
         LDX   #$FF       ;Init X
         JSR   PARSE      ;Use Applesoft parser
         TYA              ;Get new length (+4)
         SEC
         SBC   #4         ;Fix it
         JSR   GETSPA     ;Make room for new string
         LDY   #>IN       ;Point to it
         LDX   #<IN
         PHA              ;Save length
         JSR   MOVSTR     ;Move to string space
         LDY   #0         ;Change descriptor to point
         PLA              ; to new string:
         STA   (VARPNT),Y ;Store new length
         LDA   FRETOP     ; and new address
         INY
         STA   (VARPNT),Y
         LDA   FRETOP+1
         INY
         STA   (VARPNT),Y
         PLA              ;Retrieve TXTPTR
         STA   TXTPTR+1   ; and exit
         PLA
         STA   TXTPTR
BACK     RTS
