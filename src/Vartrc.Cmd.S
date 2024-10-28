********************************
*                              *
*       VARIABLE TRACER        *
*                              *
*  Glen E. Bredon    11/29/84  *
*                              *
********************************

         DATE

         REL                                      ;Generate a LNK file

         TR

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/VARTRC.CMD
         FIN

VALTYP   =              $11
DATAFLAG =              $13
VARPNT   =              $83
VPNT     =              $A0
CHRGOT   =              $B7
STACK    =              $100
IN       =              $200
SCREEN   =              $400
VERSION  =              $FBB3
COUT     =              $FDED
KEY      =              $C000
STORE80  =              $C001
RD80STR  =              $C018
RD80COL  =              $C01F
PAGE1    =              $C054
PAGE2    =              $C055

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters, 0 = none (2 bytes)
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

* Applesoft stuff:

TXTPTR   =              $B8
GDBUFS   =              $D539
BPARSE   =              $D56C
FRMEVL   =              $DD7B
FOUT     =              $ED34

* Data

VARLEN   =              29
         PAG
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
         CPY            #AMPEND-CMDNAME
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            6                         ;Signature

PARSE    LDX            #CMDEND-CMDNAME-1
         STX            XLEN
         INX
         SEC                                      ;In case we exit here
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
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
:FE      INX
         LDA            IN,X
         CMP            #$8D
         BNE            :FE
         JSR            GDBUFS
         LDA            TXTPTR
         PHA
         LDA            TXTPTR+1
         PHA
         LDX            #CMDEND-CMDNAME-1
         STX            DATAFLAG
         LDY            #CMDEND-CMDNAME+4
         JSR            BPARSE
         CPY            #CMDEND-CMDNAME+5
         BEQ            TRCOFF                    ;Branch if no formula
:DY      DEY
         CPY            #VARLEN
         BGE            :DY
:GETOUR  STA            OURVAR,Y
         LDA            IN+CMDEND-CMDNAME-1,Y
         DEY
         BPL            :GETOUR
         CLC
TRCOFF   PLA
         STA            TXTPTR+1
         PLA
         STA            TXTPTR
PUTCG    LDX            #OUREND-OURCHRG-1
:L       LDA            OURCHRG,X
         BCC            :ST
         LDA            CHRG,X
:ST      STA            $BA,X
         DEX
         BPL            :L
         CLC
         RTS

NEWCHRG  STA            CHR
         STY            YSAV
         LDY            #1
         LDA            (TXTPTR),Y
         BEQ            :SVX                      ;Act only if next call will
         CMP            #':'                      ; be end of statement.
         BEQ            :SVX
         JMP            :EXIT
:SVX     STX            XSAV
         LDX            #$BC-$50                  ;Save zp ($50-$BC)
:L       LDA            $50,X
         STA            ZPSAVE,X
         DEX
         BPL            :L
         LDX            #$1D-$D                   ;Save zp ($D-$1D)
:L2      LDA            $D,X
         STA            ZPSAVE2,X
         DEX
         BPL            :L2
         LDA            #OURVAR                   ;Point TXTPTR to trace variable
         STA            TXTPTR
         LDA            #>OURVAR
         STA            TXTPTR+1
         SEC                                      ;Force CHRGET fix
         JSR            PUTCG                     ;Defeat recursion
         JSR            FRMEVL                    ;Get var ptr
         BIT            VALTYP
         BMI            :ISSTR                    ;Branch if a string var
         JSR            FOUT                      ;Build string in STACK
         STA            VARPNT                    ;Points to STACK
         STY            VARPNT+1
         LDX            #-1
:IX      INX                                      ;Find length of string in stack
         LDA            STACK,X
         BNE            :IX
         BEQ            :LY0
:ISSTR   LDY            #0
         LDA            (VPNT),Y                  ;String length
         CMP            #40
         BLT            :LOK
         LDA            #40                       ;Truncate at 40
:LOK     TAX
         INY
         LDA            (VPNT),Y
         STA            VARPNT                    ;String address to VARPNT
         INY
         LDA            (VPNT),Y
         STA            VARPNT+1
:LY0     LDY            #0
:DX      DEX
         BMI            :SDON
         LDA            (VARPNT),Y                ;Put string on screen
         ORA            #$80
         STA            SCREEN,Y
         INY
         BNE            :DX
:SDON    JSR            BLANK                     ;Fill rest of line with blanks
         LDA            VERSION
         EOR            #6
         BNE            :DONE                     ;Branch if not //e or //c
         TAY
         LDA            RD80COL
         BPL            :DONE                     ;Branch if not 80 col mode
         LDA            RD80STR
         PHA                                      ;Save state of STORE80
         STA            STORE80
         STA            PAGE2
         JSR            BLANK                     ;Blank out "background"
         STA            PAGE1
         PLA
         BMI            :DONE
         STA            KEY                       ;Restore state of STORE80
:DONE    LDX            #$BC-$50
:R       LDA            ZPSAVE,X                  ;Restore zp ($50-$BC)
         STA            $50,X
         DEX
         BPL            :R
         LDX            #$1D-$D
:R2      LDA            ZPSAVE2,X                 ;Restore zp ($D-$1D)
         STA            $D,X
         DEX
         BPL            :R2
         LDX            XSAV
:EXIT    LDY            YSAV
         LDA            CHR
CHRG     CMP            #':'                      ;These three bytes are same
         BCS            RET                       ; as those at $BA in CHRGET
         JMP            $BE

SS       STA            SCREEN,Y
         INY
BLANK    LDA            #" "
         CPY            #40
         BLT            SS
RET      RTS

OURVAR   DS             VARLEN

XSAV     BRK
YSAV     BRK

OURCHRG  JMP            NEWCHRG
OUREND

CMDNAME  ASC            "VARTRC"
CMDEND   ASC            " formula"8D
AMPEND

ZPSAVE   DS             $BC-$50+1

ZPSAVE2  DS             $1D-$D+1

CHR      BRK
