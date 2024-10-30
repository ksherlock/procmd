********************************
*                              *
*           Quicksort          *
*                              *
*      Revision:  5/27/86      *
*                              *
********************************
*                              *
*   Calling syntax:            *
*                              *
*"SORT":A$(0,-),I%(0),A,B[,0]  *
* where A$= dimd string array, *
* I% = 1-dimd integer array,   *
* A=start,B=end of sort range. *
*                              *
* The first dim of A$ should   *
* match the dim of I%, eg.,    *
* DIM A$(1000,3),I%(1000)      *
*                              *
* The syntax                   *
*"SORT":A$(0,-,-),I%(0),A,B,1  *
* gives a numerical sort.      *
*                              *
********************************

         DATE

*----------------------------------------
* Assemble, then use the RELOC utility to
* convert to a relocating CMD file.
*----------------------------------------

         EXP   OFF
         TR
         REL              ;Generate a LNK file

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/SORT.CMD
         FIN

CHRGET   =     $B1
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

VALTYP   =     $11        ;$FF = string, 0 = real
INTFLAG  =     $12        ;$80 = integer, 0 if not
END      =     $3C        ;Last element of sort range
BEGIN    =     $3E        ;First element of sort range
LINNUM   =     $50
FINDEX   =     $5E
VARPNT   =     $83
LOWTR    =     $9B
KEY      =     $C000
MEMERR   =     $D410
FRMNUM   =     $DD67
CHKCOM   =     $DEBE
SYNERR   =     $DEC9
PTRGET   =     $DFE3
IQERR    =     $E199
DOVAL    =     $E70A
COMBYTE  =     $E74C
GETADR   =     $E752
MOVFM    =     $EAF9
MOVMF    =     $EB2B
FCOMP    =     $EBB2

         DUMMY $E5
ZP                        ;Zero page area
INDX2    DA    0          ;Pointer to index right
INDX1    DA    0          ;Pointer to index left
INDXR    DA    0          ;Pointer to index right div
INDXL    DA    0          ;Pointer to index left div
DSC1     DA    0          ;Pointer to descriptor 1
DSCR     DA    0          ;Pointer to descriptor R
DSCL     DA    0          ;Pointer to descriptor L
LEN1     DFB   0          ;Length of string 1
STRNG1   DA    0          ;Pointer to string 1
         DA    0          ;Reserved to simplify real mode
LENL     DFB   0          ;Length of string L
STRNGL   DA    0          ;Pointer to string L
LENR     DFB   0          ;Length of string R
STRNGR   DA    0          ;Pointer to string R
TEMP     DA    0          ;Scratch
         ERR   TEMP/$FF

         DUMMY $280
FPLOC    DS    5          ;Save for FP #1
PAR      DFB   0          ;Parity of index array loc
SORTARY  DA    0          ;Sort array pointer
INDXARY  DA    0          ;Index array pointer
NUMODE   DFB   0          ;$=10-, $N=11-, %=01-, Real=00-
STKPNT   DFB   0          ;Stack pointer save on entry
TRYS     DFB   16         ;Number of stack ovflow retrys
SAVEZP   DS    $100-ZP    ;Zero page save area
         DEND

         AST   50

COMPR    MAC
         LDA   ]1
         CMP   ]2
         LDA   ]1+1
         SBC   ]2+1
         <<<

INCD     MAC
         INC   ]1
         BNE   NC
         INC   ]1+1
NC       <<<

MOV      MAC
         LDA   ]1
         STA   ]2
         <<<

MOVD     MAC
         MOV   ]1;]2
         MOV   ]1+1;]2+1
         <<<

SWAP     MAC
         LDA   ]1
         TAX
         MOV   ]2;]1
         TXA
         STA   ]2
         <<<

POINT    MAC
         LDA   #]1
         LDY   #>]1
         <<<

STFAC    MAC
         LDX   #]1
         LDY   #>]1
         JSR   MOVMF
         <<<

COMPARE  MAC
         POINT ]1
         JSR   FCOMP
         <<<

VAL      MAC
         MOVD  STRNG]1;FINDEX
         LDA   LEN]1
         JSR   DOVAL
         <<<

GETNUM   MAC
         LDA   DSC]1
         LDY   DSC]1+1
         JSR   MOVFM
         <<<

CPRUP    MAC
         LDA   ]2
         CMP   #$60
         BLT   OK1
         AND   #%01011111
OK1      STA   TEMP
         LDA   ]1
         CMP   #$60
         BLT   OK2
         AND   #%01011111
OK2      CMP   TEMP
         <<<

PUSH     MAC
         LDA   ]1+1
         PHA
         LDA   ]1
         PHA
         <<<

PULL     MAC
         PLA
         STA   ]1
         PLA
         STA   ]1+1
         <<<

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
         CPY   #AMPEND-AMPNAME
         BLT   :SN        ; give list of all dos cmds.
         JSR   CHRGOT     ;Reestablish A and status
         BEQ   AMPEXIT    ;Go to next routine (always)

         DFB   4          ;Signature

PARSE    LDX   #CMDEND-CMDNAME
:ISIT    LDA   IN-1,X
         AND   #%11011111
         EOR   CMDNAME-1,X
         SEC              ;In case we exit here
         BNE   DOSEXIT    ;Support daisy chain
         DEX
         BNE   :ISIT
         STX   XCNUM      ;Signal external cmd
         STX   PBITS      ; and no parms
         STX   PBITS+1
         LDA   #START
         STA   XTRNADDR
         LDA   #>START
         STA   XTRNADDR+1
         LDA   #CMDEND-CMDNAME-1
         STA   XLEN
         CLC              ;Tell interpreter we
         RTS              ; accepted command

AMPNAME  DFB   """
CMDNAME  ASC   "SORT"
CMDEND   ASC   !":A[$%](0,-),I%(0),start,end[,1]!8D
AMPEND

START    PLA              ;Pull ProDOS rtn addr
         TAX
         PLA
         TAY
         LDA   #>:CONT-1
         PHA
         LDA   #:CONT-1
         PHA              ;Set up rtn address so that
         TYA              ;ProDOS will hand it back.
         PHA
         TXA
         PHA
         CLC              ;Tell ProDOS we accept and
         RTS              ; please get out of the way

:JSYN    JMP   SYNERR     ;Get syntax error if not

:CONT    LDA   #0
         STA   BEGIN      ;Init count for setting
         STA   BEGIN+1    ; index array
         JSR   CHRGET
         JSR   PTRGET
         LDA   INTFLAG
         BMI   :OVR
         LDA   VALTYP
:OVR     STA   NUMODE     ;$=FF, %=80, Real=0
         MOVD  VARPNT;SORTARY
         JSR   CHKCOM     ;Check syntax
         JSR   PTRGET     ;Get pointer to index array
         MOVD  VARPNT;INDXARY
         LDY   #4
         LDA   (LOWTR),Y  ;Get # of dims of index array
         CMP   #1         ;Is it 1?
         BNE   :JSYN      ;Get syntax error if not
         BIT   INTFLAG    ;Integer array?
         BPL   :JSYN      ;Error if not
         INY
         LDA   (LOWTR),Y  ;Get array size
         STA   END+1
         INY
         LDA   (LOWTR),Y
         STA   END
         LDA   #0
         LDX   #4         ;Look at 1st 2 entries
:LK      INY
         ORA   (LOWTR),Y
         DEX
         BNE   :LK
         TAY
         BNE   :SKIP      ;Skip if array already inited
         LDA   LOWTR
         PHA
         LDA   LOWTR+1
         PHA
         TYA
         LDY   #7
:SETINDX STA   (LOWTR),Y
         TXA
         INY
         BNE   :NI
         INC   LOWTR+1
:NI      STA   (LOWTR),Y
         INY
         BNE   :ISET?
         INC   LOWTR+1
:ISET?   INCD  BEGIN
         LDX   BEGIN
         LDA   BEGIN+1
         CMP   END+1
         BNE   :SETINDX
         CPX   END
         BNE   :SETINDX
         PLA
         STA   LOWTR+1
         PLA
         STA   LOWTR

:SKIP    ASL   END        ;Set END one past index array
         ROL   END+1
         LDA   LOWTR
         LDX   LOWTR+1
         ADC   #7
         BCC   :NC
         INX
         CLC
:NC      ADC   END
         STA   END
         TXA
         ADC   END+1
         STA   END+1
         JSR   CHKCOM     ;Comma next?
         JSR   FRMNUM     ;Find beginning of range to sort
         JSR   GETADR     ;Convert to integer in LINNUM
         JSR   CHKCOM     ;Check syntax
         LDA   LINNUM
         ASL
         ROL   LINNUM+1
         ADC   INDXARY
         STA   BEGIN      ;Address of start of sort range
         LDA   LINNUM+1
         ADC   INDXARY+1
         STA   BEGIN+1
         JSR   FRMNUM     ;Find end of range to sort
         JSR   GETADR     ;Convert to integer in LINNUM
         JSR   CHRGOT
         CMP   #','
         BNE   :CF
         JSR   COMBYTE
         LDY   NUMODE
         INY
         BNE   :CF        ;Branch if not string
         CPX   #1
         BEQ   :SF
:CF      CLC
:SF      ROR   NUMODE
         BCC   :NOTSTR
         ROR   NUMODE     ;$=10-, $N=11-, %=01-, Real=00-
:NOTSTR  LDA   LINNUM
         ASL
         ROL   LINNUM+1
         ADC   INDXARY
         TAX
         LDA   LINNUM+1
         ADC   INDXARY+1
         TAY              ;Compare actual end of array
         CPX   END        ; to specified end of sort
         SBC   END+1
         BGE   :IQ
         STX   END
         TYA
         STA   END+1
         CPX   BEGIN      ;Begin<=end?
         SBC   BEGIN+1
         BGE   :OK
:IQ      JMP   IQERR      ;Illegal quantity
:OK      TXA
         AND   #1
         STA   PAR
         LDA   #16        ;Set for 16 attempts
         STA   TRYS       ; (7 have always sufficed)
         TSX
         STX   STKPNT
         LDX   #$FF-ZP
:SAVE    LDA   ZP,X       ;Save Applesoft pointers
         STA   SAVEZP,X   ; to free some zero page
         DEX              ; for our use.
         BPL   :SAVE

JTS      JSR   DOSORT     ;Do the sort

RESTORE  LDX   #$FF-ZP
:REST    LDA   SAVEZP,X   ;Replace Applesoft pointers
         STA   ZP,X
         DEX
         BPL   :REST
RET      RTS

NOMEM    LDX   STKPNT
         TXS
         DEC   TRYS
         BNE   JTS        ;Try again, 16 times
         JSR   RESTORE
         JMP   MEMERR

DOSORT   LDX   #3
:L       LDA   END,X      ;BEGIN -> INDX1
         STA   INDX2,X    ;END -> INDX2
         DEX
         BPL   :L

*------------------------
* Recursive sort routine:
*------------------------

SORT     COMPR INDX1;INDX2
         BGE   RET        ;Do while REC1 < REC2
         TSX
         CPX   #$10
         BLT   NOMEM
         JSR   DIVIDE     ;Partition range REC1,REC2

* First, sort left partition

         PUSH  INDX2      ;Save ptrs for right
         PUSH  INDXR      ; hand side of partition
         LDX   INDXR+1
         SEC
         SBC   #2
         BCS   :NC
         DEX
:NC      STA   INDX2      ;Set INDX2=INDXR-2
         STX   INDX2+1
         JSR   SORT       ;Do range REC1 to RECR-1

* Next, sort right partition

         TSX
         PLA              ;Retrieve ptrs from stack
         CLC
         ADC   #2
         STA   INDX1      ;Set INDX1=old INDXR+2
         PLA
         ADC   #0
         STA   INDX1+1
         PULL  INDX2
         TXS              ;Allow stack ovflo for bad case
         JSR   SORT       ;Do range RECR+1 to REC2
         LUP   4
         PLA
         --^
         RTS

GOBACK   LDX   STKPNT
         TXS
         JMP   RESTORE

*-------------------------------------------------
* Divide INDX1,INDX2 at INDXR and swap to achieve
* RECR >= things to left; <= things to right.
* This is done by swapping REC1 with something in
* the middle, finding a position "R" such that
* things to left of R are <= REC1, things to right
* are >= REC1.  The routine ends by swapping REC1
* and RECR.
*-------------------------------------------------

DIVIDE   LDA   KEY
         CMP   #"C"&$9F
         BEQ   GOBACK
         CLC              ;Set INDXR to median of
         LDA   INDX1      ; INDX1 & INDX2
         ADC   INDX2
         AND   #%11111100
         PHA              ;  1.....R.....2
         LDA   INDX1+1
         ADC   INDX2+1
         ROR
         STA   INDXR+1
         PLA
         ROR
         ORA   PAR        ;Parity must match array
         STA   INDXR
         JSR   SWAP1R     ;Swap ptrs INDX1 <-> INDXR
         LDX   #3         ;Move INDX1->INDXL, INDX2->INDXR
:L       LDA   INDX2,X
         STA   INDXR,X
         DEX
         BPL   :L
         JSR   GETDSC1R
         LDY   #4         ;5 byte move in case real mode
:L2      LDA   (DSC1),Y
         STA   LEN1,Y
         STA   FPLOC,Y    ;For real mode
         DEY
         BPL   :L2
         BIT   NUMODE
         BVC   RIGHT      ;Branch if ord string or real
         BMI   :EVAL      ;Branch if string num mode
         EOR   #$80       ;Fix high byte of integer
         STA   LEN1
         BVS   RIGHT      ;Always
:EVAL    VAL   1          ;Evaluate string for num mode
         STFAC FPLOC

* Division sort:

RIGHT    LDA   INDXL      ;Move L pointer right, starts at
         CLC              ; 1L...........R
         ADC   #2
         STA   INDXL
         BCC   :NC
         INC   INDXL+1
:NC      JSR   GETDSCL
DIVLOOP  LDY   #2
:L       LDA   (DSCL),Y
         STA   LENL,Y
         LDA   (DSCR),Y
         STA   LENR,Y
         DEY
         BPL   :L
         BIT   NUMODE
         BPL   :RI1       ;Branch if real or int
         INY              ;A has LENR here
         CMP   LEN1       ;Get minumum length
         BLT   :D1        ; of REC1, RECR
         LDA   LEN1
:D1      TAX
         BEQ   :D3
         BVC   :D2        ;Branch if ord string
         VAL   R          ;Evaluate string R
:CF1     COMPARE FPLOC      ;Leaves A=-1,0,1 as
         CMP   #1         ; STRNG1 <=> STRNGR
         BNE   :CR
:LEFT    JSR   DCRR
         JMP   DIVLOOP

:RI1     BVS   :INT1
         GETNUM R          ;FP # R to FAC
         JMP   :CF1       ;Compare it to FP # 1

:INT1    EOR   #$80       ;A has LENR
         STA   LENR
         LDA   LEN1+1
         CMP   LENR+1
         LDA   LEN1
         SBC   LENR
         JMP   :D3

:D2      CPRUP (STRNG1),Y;(STRNGR),Y
         BNE   :D3        ;REC1 >= RECR?
         INY
         DEX
         BNE   :D2        ;Loop till done
         CPY   LENR
:D3      BLT   :LEFT      ;If REC1 < RECR then
                          ;1...L..R.. -> 1...L.R...
                          ;Else if INDXL => INDXR
                          ;  then swap 1,R and exit (done)
:CR      COMPR INDXL;INDXR
         BGE   SWAP1R
         BIT   NUMODE
         BPL   RI2        ;Branch if real or int
         LDA   LEN1       ;Get minimum length
         CMP   LENL       ; of REC1, RECL
         BLT   :D4
         LDA   LENL
:D4      TAX
         BEQ   D6
         BVC   CMP1L
         VAL   L          ;Evaluate string L
CF2      COMPARE FPLOC      ;Leaves A=-1,0,1 as
         BPL   SWAPLR     ; STRNGL <=> STRNG1
         JMP   RIGHT

SWAP1R   LDY   #1         ;2nd byte of indices
:SW      SWAP  (INDX1),Y;(INDXR),Y
         DEY              ;1st byte of indices
         BEQ   :SW
         RTS

RI2      BVS   INT2
         GETNUM L          ;FP # L to FAC
         JMP   CF2        ;Compare to FP # 1

INT2     LDA   LENL+1
         CMP   LEN1+1
         LDA   LENL
         EOR   #$80       ;Adjust high byte of int
         SBC   LEN1
         JMP   D6

CMP1L    LDY   #0
:C1L     CPRUP (STRNGL),Y;(STRNG1),Y
         BNE   D6         ;Is RECL >= REC1
         INY
         DEX
         BNE   :C1L       ;Loop till done
         CPY   LEN1
D6       BCC   JDIV0      ;If RECL < REC1 then
                          ;1..L...R.. -> 1...L..R..
                          ;Else swap L,R and
                          ;  1..L...R.. -> 1..L..R...
SWAPLR   LDY   #1
:SW      SWAP  (INDXL),Y;(INDXR),Y
         MOV   DSCR,Y;DSCL,Y
         DEY
         BEQ   :SW
         JSR   DCRR       ;Move R ptr left and
JDIV0    JMP   RIGHT      ;Move L ptr right and continue

DCRR     LDA   INDXR      ;Move R pointer left
         SEC
         SBC   #2
         STA   INDXR
         BCS   GETDSCR    ;Get new descriptor
         DEC   INDXR+1
         BCC   GETDSCR    ;Always

*---------------------------------
* Routines to get descriptor ptrs
* (or array ptrs) from indices.
*---------------------------------

GETDSC1R LDY   #0         ;Get descriptor ptr DSC1 =
         LDA   (INDX1),Y  ; SORTARY + 2,3,5 * (INDX1)
         TAX
         INY
         LDA   (INDX1),Y
         JSR   MULT
         ADC   SORTARY
         STA   DSC1
         TXA
         ADC   SORTARY+1
         STA   DSC1+1
                          ;Fall into GETDSCR
GETDSCR  LDY   #0         ;DSCR = SORTARY + 2,3,5*(INDXR)
         LDA   (INDXR),Y
         TAX
         INY
         LDA   (INDXR),Y
         JSR   MULT
         ADC   SORTARY
         STA   DSCR
         TXA
         ADC   SORTARY+1
         STA   DSCR+1
         RTS

GETDSCL  LDY   #0         ;DSCL = SORTARY + 2,3,5*(INDXL)
         LDA   (INDXL),Y
         TAX
         INY
         LDA   (INDXL),Y
         JSR   MULT
         ADC   SORTARY
         STA   DSCL
         TXA
         ADC   SORTARY+1
         STA   DSCL+1
         RTS

MULT     STA   TEMP       ;A,X times 2,3,5 to A,X
         STX   TEMP+1
         ASL              ;x2
         PHA
         TXA
         ROL
         TAX
         PLA
         BIT   NUMODE
         BMI   :STR       ;Branch if string array
         BVS   :RET       ;Exit if integer array
         ASL
         PHA              ;x4
         TXA
         ROL
         TAX
         PLA
:STR     ADC   TEMP       ;+orig
         PHA
         TXA
         ADC   TEMP+1
         TAX
         PLA
:RET     RTS
