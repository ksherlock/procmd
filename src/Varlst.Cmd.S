********************************
*                              *
*       VARIABLE LISTER        *
*                              *
*  Glen E. Bredon     3/19/85  *
*                              *
*     Original  10/11/84       *
*                              *
********************************

         DATE

* Partially modeled on GARBAG routine

         REL                                      ;Generate a LNK file
         EXP            OFF

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/VARLST.CMD
         FIN

CHRGOT   =              $B7
IN       =              $200
KEY      =              $C000
STROBE   =              $C010
CROUT    =              $FD8E
COUT     =              $FDED

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters, 0 = none (2 bytes)
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

* Applesoft stuff:

INDEX    =              $5E
STREND   =              $6D
VARTAB   =              $69
ARYTAB   =              $6B
VARPNT   =              $83
ARYPNT   =              $94
DSCPTR   =              $A0
OUTSP    =              $DB57
OUTDO    =              $DB5C
INTVAL   =              $DEE9
ISLETC   =              $E07D
FREFAC   =              $E600
MOVFM    =              $EAF9
LINPRT   =              $ED24
PRNTFAC  =              $ED2E

* Our stuff:

NUM      =              $FD
POINTER  =              $FE

MOV      MAC
         LDA            ]1
         STA            ]2
         <<<

TRAX     MAC
         MOV            ]1;]2
         LDX            ]1+1
         STX            ]2+1
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
:SN      LDA            CMDNAME,Y                 ;Show our "list" of dos cmds
         JSR            COUT                      ;If all modules have this
         INY                                      ; routine then &<RTN> will
         CPY            #CMDEND-CMDNAME+1
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            5                         ;Signature

PARSE    LDX            #CMDEND-CMDNAME
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
         SEC                                      ;In case we exit here
         BNE            DOSEXIT                   ;Support daisy chain
         DEX
         BNE            :ISIT
         STX            XCNUM                     ;Signal external cmd
         STX            PBITS                     ;and no parameters
         STX            PBITS+1
         LDA            #XRETURN                  ;Point this to RTS since
         STA            XTRNADDR                  ; we are handling the
         LDA            #>XRETURN                 ; parameters (none).
         STA            XTRNADDR+1
         LDA            #CMDEND-CMDNAME-1
         STA            XLEN
         BNE            START                     ;Always

CMDNAME  ASC            "VARLST"
CMDEND   HEX            8D

START    LDA            NUM
         PHA
         LDA            POINTER
         PHA
         LDA            POINTER+1
         PHA
         JSR            CROUT
         JSR            CROUT
         TRAX           VARTAB;POINTER
:SVAR    LDY            #0
         CPX            ARYTAB+1
         BNE            :DVARS
         CMP            ARYTAB
         BEQ            :ARYVAR
:DVARS   LDA            (POINTER),Y
         TAX
         INY
         LDA            (POINTER),Y
         JSR            PRNAME
         JSR            PRVALUE
         LDA            #7
         CLC
         JSR            BUMP
         LDX            POINTER+1
         BNE            :SVAR                     ;Always

:ARYVAR  STA            ARYPNT
         STX            ARYPNT+1
:ARYVAR2 LDA            ARYPNT
         LDX            ARYPNT+1
         CPX            STREND+1
         BNE            :ARYVGO
         CMP            STREND
         BNE            :ARYVGO
         PLA
         STA            POINTER+1
         PLA
         STA            POINTER
         PLA
         STA            NUM
         CLC                                      ;Tell ProDOS ok
         RTS                                      ;All done

:ARYVGO  STA            POINTER
         STX            POINTER+1
         LDY            #0
         LDA            (POINTER),Y
         TAX                                      ;1st char of name
         INY
         LDA            (POINTER),Y
         JSR            PRNAME
         BPL            :GETDIM
         LDA            #"$"
         INX
         BPL            :ISS
         LDA            #"%"
:ISS     JSR            OUTDO
:GETDIM  CLC
         INY
         LDA            (POINTER),Y
         ADC            ARYPNT                    ;Set pointer to next
         STA            ARYPNT                    ; array
         INY
         LDA            (POINTER),Y
         ADC            ARYPNT+1
         STA            ARYPNT+1
         INY
         LDA            (POINTER),Y               ;# of dims
         STA            NUM                       ;Save for count
         ASL                                      ;Times 2
         ADC            #3                        ;Bypass header
         JSR            BUMP                      ;Point to last dim
         LDA            #"("                      ; (first in program DIM stmt)
:LOOP    JSR            OUTDO
         LDY            #1
         LDA            (POINTER),Y               ;Dimension low
         TAX
         DEY
         LDA            (POINTER),Y               ; and high
         TAY
         TXA                                      ;Decrease it so it
         BNE            :ND                       ; corresponds to the
         DEY                                      ; DIM statement in a
:ND      DEX                                      ; program
         TYA
         JSR            LINPRT
         DEC            NUM
         BEQ            :ARDONE
         LDA            POINTER                   ;Point to previous dim
         SEC
         SBC            #2
         STA            POINTER
         BCS            :NDC
         DEC            POINTER+1
:NDC     LDA            #","
         BNE            :LOOP                     ;Always
:ARDONE  LDA            #")"
         JSR            OUTDO
         JSR            CRKEY
         JMP            :ARYVAR2

PRNAME   STA            NUM
         TXA
         JSR            OUTDO
         LDA            NUM
         AND            #$7F
         BEQ            :SKIP
         JSR            OUTDO
:SKIP    LDA            NUM
         RTS

PRVALUE  CPX            #$80
         BGE            INTORFNC                  ;Branch if integer or fnc name
         ASL                                      ;Test sign
         BCS            STRING

* Real variable

         JSR            OUTSP
         JSR            EQUATE
         JSR            MOVFM
PRNUM    JSR            PRNTFAC
         JMP            CRKEY

STRING   LDA            #"$"
         JSR            OUTDO
         JSR            EQUATE
         JSR            FREFAC
         TAX
         LDY            #0
         INX
:NXCHR   DEX
         BEQ            CRKEY
         LDA            (INDEX),Y
         AND            #$7F                      ;Just in case
         CMP            #$20
         BGE            :SEND
         ADC            #'@'
         PHA
         LDA            #'^'
         JSR            OUTDO
         PLA
:SEND    JSR            OUTDO
         INY
         BNE            :NXCHR
CRKEY    JSR            CROUT
         LDA            KEY
         BPL            :BACK
:BS      BIT            STROBE
         CMP            #" "
         BNE            :BACK
:WAIT    LDA            KEY
         BPL            :WAIT
         CMP            #" "
         BNE            :BS
:BACK    RTS

INTORFNC ASL
         BCS            INTEGER

* Function

         LDA            #'('
         JSR            OUTDO
         LDY            #4
         LDA            (POINTER),Y
         STA            VARPNT
         INY
         LDA            (POINTER),Y
         STA            VARPNT+1
         DEC            VARPNT+1
         LDY            #$FE
         LDA            (VARPNT),Y
         JSR            ISLETC
         BCC            :BAD
         TAX
         INY
         LDA            (VARPNT),Y
         CMP            #0
         BEQ            :OK
         CMP            #'0'
         BLT            :BAD
         CMP            #'9'+1
         BLT            :OK
         JSR            ISLETC
         BCC            :BAD
:OK      JSR            PRNAME
:BAD     LDA            #')'
         JSR            OUTDO
         JMP            CRKEY

INTEGER  LDA            #"%"
         JSR            OUTDO
         JSR            EQUATE
         JSR            INTVAL
         JMP            PRNUM

EQUATE   JSR            OUTSP
         ASL            NUM
         BNE            :EQ
         JSR            OUTSP
:EQ      LDA            #"="
         JSR            OUTDO
         JSR            OUTSP
         CLC
         LDA            POINTER
         ADC            #2
         LDY            POINTER+1
         BCC            :BAK
         INY
:BAK     STA            DSCPTR
         STY            DSCPTR+1
         RTS

BUMP     ADC            POINTER
         STA            POINTER
         BCC            :BAK
         INC            POINTER+1
:BAK     RTS
