********************************
*                              *
*    INTERRUPT DRIVEN CLOCK    *
*                              *
*         for PROCMD           *
*                              *
*   Glen E. Bredon   3/24/85   *
*                              *
********************************

         DATE

         REL
         TR
SAVOBJ   KBD            "Save object code? (1=yes, 0=no)"

VERSION  KBD            "12 or 24 hour display (12/24)?"
         DO             VERSION-12
         ERR            VERSION-24
         FIN
TWELVE   =              VERSION-24

         DO             SAVOBJ
         DO             TWELVE
         DSK            /GRAPHICS/OBJECT/CLOCK.12.CMD
         ELSE
         DSK            /GRAPHICS/OBJECT/CLOCK.24.CMD
         FIN
         FIN

TEMP     =              $2E
MEMTOP   =              $73
CHRGOT   =              $B7
IN       =              $200
LINE1    =              $400
ONSCREEN =              LINE1+32
KEY      =              $C000
STROBE   =              $C010
PAGE1    =              $C054
PAGE2    =              $C055
CLSAPPLE =              $C062
MOUSEBUT =              $C063
MOUSE    =              $C400                     ;Mouse = slot 4
SETMOUSE =              MOUSE+$3D                 ;Address corrected
SERVMOUS =              MOUSE+$FC                 ; "
INITMOUS =              MOUSE+$BC                 ;"
IDBYTE   =              $FBB3
IDBYTE2  =              $FBC0
HOME     =              $FC58
COUT     =              $FDED

* ProDOS stuff:

JCLOCK   =              $BDE1
XTRNADDR =              $BE50
XLEN     =              $BE52
XCNUM    =              $BE53
PBITS    =              $BE54
MLI      =              $BF00
DATE     =              $BF90
MINUTES  =              DATE+2
HOURS    =              MINUTES+1

* PROCMD stuff:

XRETURN  =              $BE9E
MONRTS   =              $FFCB

         AST            50

DOSENTRY JMP            PARSE
DOSEXIT  JMP            XRETURN
AMPEXIT  JMP            MONRTS
AMPENTRY BNE            AMPEXIT
         LDY            #0
:SN      LDA            AMPNAME,Y
         JSR            COUT
         INY
         CPY            #AMPEND-AMPNAME
         BLT            :SN
         JSR            CHRGOT
         BEQ            AMPEXIT

         DFB            21

AMPNAME
CMDNAME  ASC            "CLOCK"
CMDEND   ASC            " DD/MMM/YY"8D
AMPEND

PARSE    LDX            #CMDEND-CMDNAME
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
         SEC
         BNE            DOSEXIT
         DEX
         BNE            :ISIT
         STX            XCNUM
         STX            PBITS
         STX            PBITS+1
         LDA            #START
         STA            XTRNADDR
         LDA            #>START
         STA            XTRNADDR+1
         LDX            #CMDEND-CMDNAME-1
:IX      INX
         LDA            IN,X
         CMP            #" "
         BEQ            :IX
         JSR            MAKBYT
         BEQ            BAD
         CMP            #32
         BGE            BAD
         STA            TEMP
         INX
         LDY            #1
:LIN     LDA            IN,X
         AND            #%11011111
         CMP            MONTHS1-1,Y
         BNE            :NY
         LDA            IN+1,X
         AND            #%11011111
         CMP            MONTHS2-1,Y
         BNE            :NY
         LDA            IN+2,X
         AND            #%11011111
         CMP            MONTHS3-1,Y
         BEQ            :YA
:NY      INY
         CPY            #12+1
         BLT            :LIN
         RTS

:YA      TYA
         ASL
         ASL
         ASL
         ASL
         ASL
         PHP
         ORA            TEMP
         STA            DATE
         INX
         INX
         INX
         INX
         JSR            MAKBYT
         CMP            #100
         BGE            PBAD
         PLP
         ROL
         STA            DATE+1
         DEX
         STX            XLEN
         RTS

PBAD     PLA
BAD      SEC
         LDA            #16                       ;Syntax err if not //c
         RTS

MAKBYT   LDA            #0
:LOOP    STA            TEMP
         LDA            IN,X
         EOR            #"0"
         CMP            #10
         BGE            :GOT
         PHA
         ASL            TEMP
         LDA            TEMP
         ASL
         ASL
         ADC            TEMP
         STA            TEMP
         PLA
         ADC            TEMP
         INX
         BNE            :LOOP
:GOT     LDA            TEMP
         RTS

START    LDA            IDBYTE                    ;Check for Apple //c or //e
         EOR            #6
         ORA            IDBYTE2
         BNE            BAD
         SEI
         LDA            AIPARMS+1                 ;Already allocated?
         BNE            :SA                       ;Branch if so
         JSR            MLI                       ;Allocate interrupt
         DFB            $40
         DA             AIPARMS
:SA      LDY            #PATCHEND-JCLOCK
:MP      LDA            PATCH,Y
         STA            JCLOCK,Y
         DEY
         BPL            :MP
         LDA            AIPARMS+1
         STA            DIPARMS+1
         JSR            HOME

*--------------------------
*       Time editor:
*--------------------------
         JSR            SHOWTIME
         LDX            #0
LOOP     LDA            ONSCREEN,X
         PHA                                      ;Save screen char
         AND            #$3F                      ;Make cursor
         STA            ONSCREEN,X
:GK      LDY            KEY                       ;Wait for key
         BPL            :GK
         BIT            STROBE
         PLA
:RPLC    STA            ONSCREEN,X                ;Replace screen chr
         CPY            #$8D
         BEQ            :DONE                     ;Exit on CR
         CPY            #$88                      ;Backspace
         BEQ            :BS
         CPY            #"U"&$9F                  ;->
         BNE            :ISDIG
         LDA            :TABLE,X                  ;Table for forward two
         TAX                                      ; places, overlaps by
:BS      LDA            :TABLE+5,X                ; three bytes with that
         TAX                                      ; for back one place.
                                                  ;Drop through to BLT LOOP
:ISDIG   CPY            #"0"                      ;Is it a digit
         BLT            LOOP
         CPY            #"9"+1
         BGE            LOOP                      ;We don't check for over
         TYA                                      ; 60 on minutes, etc.;
         STA            TIME,X                    ; we assume user intelligence!
         LDY            #"U"&$9F
         BLT            :RPLC                     ;Always taken

:TABLE   DFB            3,4,0,6,7,7,0,1,1,3,4,4,6

:DONE    LDX            TIME                      ;Convert ascii time
         LDA            TENSTBL-"0",X
         CLC
         ADC            TIME+1                    ; to hex and give
         STA            HOURS                     ; it to ProDOS

         DO             TWELVE

         TAY
         JSR            FIXTIME                   ;Change afternoon time

         FIN

         LDX            TIME+3
         LDA            TENSTBL-"0",X
         CLC
         ADC            TIME+4
         STA            MINUTES
         LDA            MOUSE+$19
         STA            JINIT+1
         LDA            MOUSE+$13                 ;Get offset of SERVEMOUSE
         STA            JSERVE+1                  ; routine.
         LDA            MOUSE+$12                 ;Same for SETMOUSE
         STA            JSET+1
         LDX            #>MOUSE
         LDY            #MOUSE/$100*$10
JINIT    JSR            INITMOUS
         LDA            #8                        ;Turn on interrupts
JSET     JSR            SETMOUSE                  ; also does a CLI
         CLC
         RTS

]TENS    =              0
TENSTBL                                           ;Multiples of 10 less "0"
         LUP            10
         DFB            ]TENS-"0"
]TENS    =              ]TENS+10
         --^

AIPARMS  DFB            2
         BRK
         DA             JCLOCK

PATCH    ORG            JCLOCK
         CLD
         LDA            INCMIN+1                  ;Must hold a 3
         CMP            #3
         BNE            :ABORT
         ADC            MEMTOP+1
         CMP            #>CLOCK
         BGE            :ABORT
         JMP            CLOCK
:ABORT   LDA            #0
         JSR            MOUSE
         JSR            MLI
         DFB            $41
         DA             DIPARMS
         RTS
DIPARMS  DFB            1
PATCHEND BRK
         ORG

*--------------------------------------------------------
*             Main clock interrupt handler:
*
* If you wish to use (say) the open apple button instead
* of the mouse button, then change MOUSEBUT to $C061 and
* change the line   BMI :NOBUT   to   BPL :NOBUT.
*--------------------------------------------------------

CLOCK
JSERVE   JSR            SERVMOUS                  ;Was it our interrupt?
         BCS            :EX                       :Pass it on if not
         BIT            MOUSEBUT                  ;Mouse button down?
         BMI            :NOBUT                    ;Branch if not
         BIT            CLSAPPLE                  ;Closed apple also pressed?
         BMI            :DOINC                    ;Fast update if so
         BIT            BUTFLAG                   ;Waiting for button release?
         BMI            :NOACT                    ;Branch if so
:DOINC   JSR            INCMIN                    ;Bump minutes if not and set
         SEC                                      ; flag to wait for release.
:NOBUT   ROR            BUTFLAG
:NOACT   JSR            SHOWTIME                  ;Print time on screen
         LDA            ONSCREEN
         CMP            #"0"                      ;Always sets carry
         BNE            :OK
         LDA            #" "                      ;Blank leading "0"
         STA            ONSCREEN
:OK      JSR            INCTIME                   ;Add 1/60 th second to time
         CLC                                      ;Signal interrupt claimed
:EX      RTS

INCMIN   LDY            #3                        ;Force carry to minutes
         LDA            #"9"
]LOOP    STA            TIME+6,Y
         DEY
         BPL            ]LOOP                     ;Carry is clear here
INCTIME  ROR            SETFLAG                   ;Carry is set for usual entry
:LY10    LDY            #10
]LOOP    LDA            TIME-1,Y
         CLC
         ADC            #1                        ;Bump digit
         CMP            MAX-1,Y                   ;Carry needed?
         BLT            :OUT                      ;Branch if not
         LDA            FIRST-1,Y                 ;Get correct one
:OUT     STA            TIME-1,Y
         DEY
         BGE            ]LOOP
         CPY            #6                        ;Add 1/60th second every
         BEQ            :LY10                     ; 10 seconds (approx.)
         BGE            RET                       ;Exit if no carry to minutes
         LDY            MINUTES                   ;Bump ProDOS time
         INY
         CPY            #60                       ;Need to bump hours?
         BLT            STMIN                     ;Branch if not
         LDY            HOURS
         INY

         DO             TWELVE

FIXTIME  TYA
         BNE            :C13
         LDA            #24                       ;For call from time edit
:C13     CMP            #13
         BLT            :C10
         SBC            #12                       ;Get PM time
:C10     CMP            #10                       ;Past 10 PM?
         BLT            :OV                       ;Branch if not
         SBC            #10                       ;Get low digit
:OV      ORA            #"0"
         STA            TIME+1
         LDA            #"0"
         ADC            #0                        ;Carry set if >= 9 PM
         STA            TIME                      ;Set hi digit

         FIN

         CPY            #24                       ;Need to bump days?
         BLT            :STHRS                    ;Branch if not

         DO             TWELVE
         ELSE

         LDA            #"0"
         STA            TIME                      ;Zero time at new day
         STA            TIME+1                    ; for 24 hour clock

         FIN

         BIT            SETFLAG
         BPL            :STHRS0                   ;Exit if setting time
         LDA            DATE                      ;Bump day
         PHA
         AND            #%11111                   ;Get day bits
         STA            DAY                       ;Save them
         LSR            DATE+1                    ;Month hi to carry
         PLA
         ROR                                      ;Month to high nibble
         AND            #%11110000
         LSR                                      ;Shift to low nibble
         LSR
         LSR
         LSR
         TAY                                      ;Save month in Y
         LDA            DAY
         ADC            #1                        ;Bump day
         CMP            MAXDAYS-1,Y
         BLT            :STDAY                    ;Branch if same month
         INY                                      ;Next month
         CPY            #13
         BLT            :MONOK                    ;Branch if same year
         INC            DATE+1                    ;Increase year
         LDY            #1                        ;Its January
:MONOK   LDA            #1                        ;First day of month
:STDAY   STA            DAY
         TYA
         ASL
         ASL
         ASL
         ASL
         ASL                                      ;Month hi to carry
         ROL            DATE+1                    ;Pack with year
         ORA            DAY                       ;Add month*$20 to day
         STA            DATE                      ;That's it
:STHRS0  LDY            #0                        ;Witching hour
:STHRS   STY            HOURS
         LDY            #0
STMIN    STY            MINUTES
RET      RTS

SHOWTIME LDY            #7
         STA            KEY+1                     ;Allow page 2 switch to
         STA            PAGE2                     ; use aux memory
         LDA            #" "
]LOOP    STA            ONSCREEN,Y                ;Get rid of in between
         DEY                                      ; stuff in case we are
         BPL            ]LOOP                     ; in 80-columns
         STA            PAGE1
         LDY            #8
]LOOP    LDA            TIME-1,Y
         STA            ONSCREEN-1,Y
         DEY
         BPL            ]LOOP
         RTS                                      ;Rom routine should take
                                                  ; care of resetting switches
MONTHS1  ASC            "JFMAMJJASOND"
MONTHS2  ASC            "AEAPAUUUECOE"
MONTHS3  ASC            "NBRRYNLGPTVC"

DAY      BRK

MAXDAYS  DFB            32,29,32,31,32,31,32,32,31,32,31,32

         ASC            " "
TIME     ASC            "00:00:0000"
MAX      ASC            ":::6::6:6:"
FIRST    ASC            "00:00:0000"
SETFLAG  BRK
BUTFLAG  BRK                                      ;Flag to read button only once
