******************************
*                            *
*       DATE BASIC CMD       *
*                            *
*----------------------------*
* Assemble, then use the     *
* RELOC  utility to convert  *
* to a relocating CMD file.  *
*----------------------------*
*  Glen E. Bredon   12/7/84  *
*                            *
******************************

         DATE

         REL                                      ;Generate a LNK file
         TR
         TR             ADR

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/DATESTR.CMD
         FIN

gettime  =              $82
MLI      =              $BF00
DATE     =              $BF90
TIME     =              DATE+2

FLAG     =              $1D
MONTH    =              $3B
DAY      =              $3C
SUM      =              $3D
YEAR     =              $3E
LEAP     =              $3F
FORPNT   =              $85
CHRGET   =              $B1
CHRGOT   =              $B7
STACK    =              $100
IN       =              $200
MEMERR   =              $D410
PUTSTR   =              $DA7B
PTRGET   =              $DFE3
STR      =              $E3CF
COUT     =              $FDED
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters, 0 = none (2 bytes)
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)

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
         CPY            #AMPEND-AMPNAME
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            7                         ;Signature

PARSE    LDX            #CMDEND-CMDNAME-1
         STX            XLEN
         SEC
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
         BNE            DOSEXIT                   ;Support daisy chain
         DEX
         BNE            :ISIT
         LDA            IN+4
         EOR            #"$"
         STA            FLAG
         BEQ            :SEX
         EOR            #"#"!"$"
         BEQ            :SEX
         EOR            #"#"!"%"
         BNE            DOSEXIT
:SEX     LDY            #PBITS-XTRNADDR+1
:SETUP   STA            XTRNADDR,Y
         LDA            DATA-1,Y
         DEY
         BPL            :SETUP
         CLC
         RTS

START    PLA                                      ;Comes back here
         TAX                                      ;Allow ProDOS to parse the
         PLA                                      ; string (setting TXTPTR)
         TAY                                      ; but force it to pass control
         LDA            #>DATESTR-1               ; back to us.
         PHA
         LDA            #DATESTR-1
         PHA
         TYA
         PHA
         TXA
         PHA
         CLC                                      ;Tell ProDOS all is well
         RTS

DATESTR  TSX
         CPX            #$20
         BGE            :MEMOK
         JMP            MEMERR

:MEMOK   JSR            MLI
         DFB            gettime
         NOP
         NOP
         JSR            CHRGET                    ;Point to 1st char of formula
         JSR            PTRGET
         STA            FORPNT
         STY            FORPNT+1
         LDA            DATE
         STA            STACK-1
         BEQ            :BMAK
         PHA
         AND            #%11111
         STA            DAY
         LDY            #0
         STY            STACK+14
         STY            STACK+17
         JSR            PR2DIG
         LDA            #'-'
         STA            STACK+1
         STA            STACK+5
         LDA            DATE+1
         LSR
         STA            YEAR
         PHP
         LDY            #7
         JSR            PRBYTDEC
         PLP
         PLA
         ROR
         AND            #$F0
         LSR
         LSR
         STA            MONTH
         TAX
         LDY            #3
:PM      LDA            MONTHS-4,X
         STA            STACK+1,Y
         INX
         DEY
         BNE            :PM
         LDA            MONTHS-4,X
         STA            SUM
         LDA            FLAG
         CMP            #"$"!"%"
         BEQ            :DAYOFW
         LDA            #' '
         STA            STACK+8
         LDA            TIME+1
         LDY            FLAG
         BEQ            :LY10
         SEC
:DIV     SBC            #12
         BCS            :DIV
:ADD     CLC
         ADC            #12
         BEQ            :ADD
:LY10    LDY            #10
         JSR            PR2DIG
         LDA            #':'
         STA            STACK+11
         LDA            TIME
         LDY            #13
         JSR            PRBYTDEC
         LDA            FLAG
:BMAK    BEQ            :MAKS
         LDA            #' '
         STA            STACK+14
         LDA            #'M'
         STA            STACK+16
         LDA            #'A'
         LDY            TIME+1
         BEQ            :APM
         CPY            #12
         BLT            :APM
         LDA            #'P'
:APM     STA            STACK+15
:MAKS    JSR            STR
         JMP            PUTSTR

:DAYOFW  LDX            YEAR
         TXA
         SEC
         SBC            #85
         LSR
         LSR
         CLC
         ADC            YEAR
         SBC            #83
         JSR            MOD7
         TAY
         TXA
         LDX            #0
         AND            #3
         BEQ            :OVR
         DEX
:OVR     STX            LEAP
         TYA
         CLC
         ADC            SUM
         ADC            DAY
         LDY            MONTH
         CPY            #3*4
         BLT            :MOD
         ADC            LEAP
:MOD     JSR            MOD7
         TAY
         LDX            DAYOFF,Y
         LDY            #0
:PD      LDA            SUN,X
         BMI            :DAY
         STA            STACK-1,Y
         BEQ            :MAKS
         INY
         INX
         BNE            :PD
:DAY     LDX            #DAYWRD-SUN
         BNE            :PD

PRBYTDEC LDX            #'0'-1
         SEC
:L       INX
         SBC            #10
         BCS            :L
         ADC            #'0'+10
CPD      STA            STACK,Y
         TXA
         STA            STACK-1,Y
         RTS

PR2DIG   CMP            #10
         BGE            PRBYTDEC
         LDX            #' '
         ORA            #'0'
         BNE            CPD

MOD7     SEC
]LUP     SBC            #7
         BCS            ]LUP
         ADC            #7
         RTS

MONTHS   REV            'Jan'
         DFB            0
         REV            'Feb'
         DFB            3
         REV            'Mar'
         DFB            3
         REV            'Apr'
         DFB            6
         REV            'May'
         DFB            1
         REV            'Jun'
         DFB            4
         REV            'Jul'
         DFB            6
         REV            'Aug'
         DFB            2
         REV            'Sep'
         DFB            5
         REV            'Oct'
         DFB            0
         REV            'Nov'
         DFB            3
         REV            'Dec'
         DFB            5

SUN      ASC            'Sun'ff
MON      ASC            'Mon'ff
TUE      ASC            'Tues'ff
WED      ASC            'Wednes'ff
THU      ASC            'Thurs'ff
FRI      ASC            'Fri'ff
SAT      ASC            'Satur'
DAYWRD   ASC            'day'00

DAYOFF   DFB            SUN-SUN
         DFB            MON-SUN
         DFB            TUE-SUN
         DFB            WED-SUN
         DFB            THU-SUN
         DFB            FRI-SUN
         DFB            SAT-SUN

DATA     DA             START,0
         DFB            0

AMPNAME  ASC            !"!
CMDNAME  ASC            "DATE$"
CMDEND   ASC            !":X$, "DATE#":X$!
         ASC            ! or "DATE%":X$!8D
AMPEND
