******************************
*                            *
*     "USING" BASIC CMD      *
*                            *
*----------------------------*
* Assemble, then use the     *
* RELOC  utility to convert  *
* to a relocating CMD file.  *
*----------------------------*
*  Glen E. Bredon   5/18/85  *
*                            *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"
         EXP            OFF
         TR

         DO             SAVOBJ
         DSK            OBJECT/USING.CMD
         FIN

FILL     =              $1A                       ;Fill character
FORML    =              $1B                       ;Slots left of dp
FORMR    =              $1C                       ;Slots right of dp
TEMP     =              $1D
DIGCNT   =              $1E                       ;Total slots
TPNT     =              $1F                       ;Pointer in template
PLUS     =              FORMR                     ;Final printing, initial +
SIGN     =              FORML                     ; ", number's sign
DOLLAR   =              TEMP                      ; ", $ flag
IN       =              $200
FPTEMP   =              $210
KEEPFP   =              $218                      ;# with dp removed & rounded
SAVEFP   =              $220                      ;Actual number to be formatted
TEMPLATE =              $260                      ;Previous byte used
COUT     =              $FDED

* Applesoft stuff:

FAC      =              $9D
FACSGN   =              $A2
CHRGET   =              $B1
CHRGOT   =              $B7
OUTDO    =              $DB5C
FRMEVL   =              $DD7B
FSUB     =              $E7A7
FADD     =              $E7BE
TEN      =              $EA50
DIV10    =              $EA55
MUL10    =              $EA39
MOVFM    =              $EAF9
MOVMF    =              $EB2B
FCOMP    =              $EBB2
QINT     =              $EBF2
FINT     =              $EC23
PRINTFAC =              $ED2E

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters, 0 = none (2 bytes)
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

STFAC    MAC
         LDX            #]1
         LDY            #>]1
         JSR            MOVMF
         <<<

POINT    MAC
         LDA            #]1
         LDY            #>]1
         <<<

GETNUM   MAC
         POINT          ]1
         JSR            MOVFM
         <<<

SUBFROM  MAC
         POINT          ]1
         JSR            FSUB
         <<<

ADDTO    MAC
         POINT          ]1
         JSR            FADD
         <<<

COMPARE  MAC
         POINT          ]1
         JSR            FCOMP
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
:SN      LDA            AMPNAME,Y                 ;Show our "list" of dos cmds
         JSR            COUT                      ;If all modules have this
         INY                                      ; routine then &<RTN> will
         CPY            #AMPEND-AMPNAME+1
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            8                         ;Signature

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
         LDA            #START                    ;Point this to RTS since
         STA            XTRNADDR                  ; we are handling the
         LDA            #>START                   ; parameters (none).
         STA            XTRNADDR+1
         STX            FORML                     ;Init digit count left
         STX            FORMR                     ; and right
         LDY            #CMDEND-CMDNAME-1
         LDA            #' '                      ;Default fill char
:STFILL  STA            FILL
:GETTEM  INY
         LDA            IN,Y                      ;Bypass leading spaces
         CMP            #" "
         BEQ            :GETTEM
         CMP            #"^"                      ;Fill desired?
         BNE            :LUP                      ;Skip if not
         INY
         LDA            IN,Y                      ;Get fill character
         CMP            #$8D
         BEQ            :FORMDUN                  ;Safety exit
         AND            #$7F                      ;Fill is + to distinguish
         BPL            :STFILL                   ;Always
:LUP     CMP            #"."
         BEQ            :SETRGHT                  ;Count right digits after dp
         CMP            #$8D
         BEQ            :FORMDUN                  ;Exit if template done
         CMP            #"#"
         BNE            :SETLEFT
         INC            FORML                     ;Count left digits
:SETLEFT STA            TEMPLATE,X
         INX
         INY
         LDA            IN,Y
         BNE            :LUP
:SETRGHT STA            TEMPLATE,X
         INX
         INY
         LDA            IN,Y
         CMP            #$8D
         BEQ            :FORMDUN                  ;Exit if template done
         CMP            #"#"
         BNE            :SETRGHT
         INC            FORMR                     ;Count right digits
         BNE            :SETRGHT                  ;Always
:FORMDUN STY            XLEN
         LDA            #0
         STA            TEMPLATE,X                ;Signal end of template
:CC      CLC                                      ;For ProDOS
:RET     RTS

START    PLA                                      ;Comes back here
         TAX                                      ;Allow ProDOS to parse the
         PLA                                      ; string (setting TXTPTR)
         TAY                                      ; but force it to pass control
         LDA            #>USING-1                 ; back to us.
         PHA
         LDA            #USING-1
         PHA
         TYA
         PHA
         TXA
         PHA
         CLC                                      ;Tell ProDOS all is well
         RTS

USING    JSR            CHRGET                    ;Point to 1st char of formula
         JSR            FRMEVL                    ;Get # to be formatted
         STFAC          SAVEFP                    ;Save in case format won't fit
         LDX            FORMR
         STX            TEMP
         BEQ            :DPMVD                    ;Branch if no dp
:LP      JSR            MUL10                     ;Move dp to right of formatted #
         DEC            TEMP
         BNE            :LP
:DPMVD   LDA            FORML
         CLC
         ADC            FORMR
         BEQ            :PRORD                    ;Exit if no slots
         STA            TEMP                      ;Save total # digits
         STA            DIGCNT
         LDA            FACSGN
         PHA                                      ;Save sign
         LSR            FACSGN                    ;Take absolute value
         ADDTO          HALF                      ;Round it
         STFAC          KEEPFP                    ; and save it
         LDY            #-1
:FS      INY
         LDA            TEMPLATE,Y                ;Find first slot
         CMP            #"#"
         BNE            :FS
         STY            TPNT
:DT      DEC            TEMP
         BEQ            :SIZE
         JSR            DIV10                     ;Move dp just to right of
         JMP            :DT                       ; 1st digit in format form
:SIZE    COMPARE        TEN                       ;Is there an overflow?
         BMI            :DPM                      ;Ok if < 10
         PLA                                      ;Overflow: use Applesoft format
:PRORD   GETNUM         SAVEFP                    ;Retrieve original #
         JMP            PRINTFAC                  ;Let Applesoft deal with it

:DPM     LDA            DIGCNT                    ;Get current digit pointer
         STA            TEMP                      ;Keep it for countdown
         GETNUM         KEEPFP                    ;Get normalized number
:DTM     DEC            TEMP
         BEQ            :ND
         JSR            DIV10                     ;Dp to right of current digit
         JMP            :DTM
:ND      JSR            FINT                      ;Strip fractional part
         STFAC          FPTEMP                    ;Save it
         JSR            DIV10                     ;Dp to left of current digit
         JSR            FINT                      ;Strip current digit
         JSR            MUL10                     ;Dp back to right of digit
         SUBFROM        FPTEMP                    ;Isolate digit
         JSR            QINT                      ;Form digit
         LDA            FAC+4                     ;Here it is
         ORA            #"0"                      ;In ascii
         LDY            TPNT
         STA            TEMPLATE,Y
:NY      INY
         LDA            TEMPLATE,Y                ;Move to next slot
         BEQ            :TDONE
         CMP            #"#"
         BNE            :NY
         STY            TPNT
         DEC            DIGCNT                    ;Point to next digit
         BNE            :DPM                      ;Loop till done
:TDONE   LDY            #-1
:FF      INY
         LDA            TEMPLATE,Y
         BEQ            :DY
         CMP            #"."                      ;Look at formatted # until dp
         BEQ            :DY                       ;Allow one 0 before dp
         EOR            #"0"                      ; or a digit
         BEQ            :FF
         CMP            #10
         BGE            :FF
         INY
:DY      DEY
         BPL            :DOLL
         INY
:DOLL    LDA            TEMPLATE                  ;Get first char (in case $ or +)
         STA            PLUS                      ;In case + leading format string
         CMP            #"+"
         BNE            :STT                      ;Branch if not "+" option
         LDA            TEMPLATE+1                ;If "+" option, look for "$"
:STT     STA            DOLLAR                    ;Save it
         PLA                                      ;Get sign
         STA            SIGN                      ;Remember it
         BPL            :ISP                      ;Skip if # is positive
         LDA            PLUS                      ;If "+" option
         CMP            #"+"
         BEQ            :ISP                      ; then don't place "-" in string
         LDA            #"-"                      ;Else put - sign in string
         HEX            2C
:ISP     LDA            FILL                      ;Use fill if # +, or "+" option
         STA            TEMPLATE-1,Y
         DEY
         BPL            :ISP                      ;Fill all other slots to left
         INY                                      ;=0
         LDA            PLUS
         CMP            #"+"
         BNE            :PRNT                     ;Branch if not "+" option
         INY                                      ;Skip unused slot for "+" option
         BIT            SIGN
         BPL            :JO                       ;Print "+" if # positive
         LSR            SIGN                      ;Avoid appending second "-"
         LDA            #"-"
         BNE            :JO                       ;Print "-" if # negative
:PRNT    LDA            TEMPLATE-1,Y
         BEQ            :ALLDONE
         CMP            FILL
         BNE            :JO                       ;Branch if past the fill
         CMP            TEMPLATE,Y                ;Two fill chars in row?
         BEQ            :JO                       ;Branch if so
         LDA            DOLLAR                    ;# is next, do we want a $
         CMP            #"$"
         BNE            :FILL                     ;Branch if not
         BIT            SIGN
         BPL            :JO                       ;Print "$" if # positive
         INY                                      ;Set to skip following "-"
         LDA            #"-"                      ; in template, print a "-"
         JSR            OUTDO
         LDA            #"$"                      ; then set to print the "$"
         BNE            :JO
:FILL    LDA            FILL                      ;Print fill character
:JO      JSR            OUTDO
         INY
         BNE            :PRNT                     ;Back for next char, always
:ALLDONE RTS

HALF     HEX            7F7FFFFFFF                ;1/2 - epsilon
                                                  ; gives better results than
                                                  ; does 1/2 on the nose!

AMPNAME  ASC            """
CMDNAME  ASC            "USING"
CMDEND   ASC            ! [^fill][+][$]#,###.##":formula!
AMPEND   HEX            8D
