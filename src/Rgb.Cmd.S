********************************
*                              *
* RGB  (DOUBLE HIRES ROUTINES) *
*                              *
*   Glen E. Bredon   3/05/86   *
*                              *
********************************

* Ampersand commands:
*
* &HGR and &HGR2   = color mode double hires
* &&HGR and &&HGR2 = mono mode double hires
* &GR              = mixed mode double hires
* &TEXT  = graphics off
* &CLEAR = clear gr screen (& set HCOLOR = 7)
*
* &HCOLOR is passed with a return to fix tbl.

         DATE

         REL                                      ;Generate a LNK file
         TR
         EXP            OFF

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/RGB.CMD
         FIN

* Tokens:

gr       =              $88
text     =              $89
hgr2     =              $90
hgr      =              $91
hcolor   =              $92
amper    =              $AF
clear    =              $BD

* Switches:

STORE80  =              $C001
GR       =              $C050
FULL     =              $C052
PAGE1    =              $C054
PAGE2    =              $C055
HIRES    =              $C057
DBL_ON   =              $C05E
DBL_OFF  =              $C05F

* Applesoft stuff:

SHAPEL   =              $1A
SHAPEH   =              $1B
PNT      =              SHAPEL
CHRGET   =              $B1
CHRGOT   =              $B7
TXTPTR   =              $B8
HCOLORZ  =              $E4
HPAG     =              $E6
IN       =              $200
INIT     =              $FB2F
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

* ProDOS BASIC interp location:

XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)

         AST            50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP            DOSEXIT
DOSEXIT  JMP            XRETURN                   ;To daisy chain commands
AMPEXIT  JMP            MONRTS                    ;This one to daisy chain & cmds
AMPENTRY BEQ            AMPEXIT                   ;Other & cmds to next routine
         CMP            #amper
         BEQ            AMPER
         CMP            #text
         BEQ            ISTXT
         CMP            #clear
         BEQ            CLRSCRN
         CMP            #gr
         BEQ            MIXED
         BNE            OVER

SIG      DFB            26
         ERR            SIG-$801D

OVER     EOR            #hgr2
         CMP            #2
         BEQ            CALLCOL                   ;&HCOLOR command
         BGE            NO
HGR      JSR            SETGR                     ;& HGR and & HGR2 commands
         STA            $C00D                     ;Turn on "80 col"
         JSR            SWITCHES
JCHRGET  LDA            DBL_ON
         JMP            CHRGET

ISTXT    LDA            DBL_OFF                   ;&TEXT command
         STA            $C00C                     ;80 col off
         JSR            INIT
GETCHR   JMP            CHRGET

CLRSCRN  JSR            CLEAR                     ;&CLEAR command
         BEQ            GETCHR

AMPER    LDY            #1                        ;&&HGR and &&HGR2 commands
         LDA            (TXTPTR),Y
         EOR            #hgr2
         CMP            #2
         BGE            NO
         JSR            SETGR
         STA            $C00C                     ;80 col off
         JSR            SWITCHES
         STA            $C00D                     ;80 col on
         JSR            CHRGET                    ;Pass the 2nd &
         JMP            JCHRGET

CALLCOL  LDA            #>CONT-1
         PHA
         LDA            #CONT-1
         PHA
NO       JSR            CHRGOT
         BNE            AMPEXIT                   ;Always
CONT     JSR            FIXTBL
         JMP            CHRGOT

MIXED    LDA            #0                        ;& GR command
         JSR            SETGR
         JSR            FIXTBL
         STA            $C00C                     ;80 col off
         JSR            SW2
         STA            $C00D                     ;80 col on
         JSR            SW2
         JMP            JCHRGET

SWITCHES JSR            SW2
SW2      LDA            DBL_ON
         LDA            DBL_OFF
         RTS

SETGR    TAX                                      ;Use as index to adrs tbl
         LDA            FULL,X
         STA            STORE80
         BIT            HIRES
         BIT            GR
CLEAR    LDY            #-1
         STY            HCOLORZ
         INY
         STY            SHAPEL
         STY            IN
         BIT            PAGE2
         JSR            :CLRPAG
         BIT            PAGE1
:CLRPAG  LDX            #$20
         STX            HPAG
         STX            SHAPEH
         TYA
:CLRLUP  STA            (SHAPEL),Y
         INY
         BNE            :CLRLUP
         INC            SHAPEH
         DEX
         BNE            :CLRLUP
         RTS

FIXTBL   LDA            #>AMPEXIT
         STA            PNT+1
         LDY            #0
         STY            PNT
:LOOK    LDY            #SIG
         LDA            (PNT),Y
         CMP            #14                       ;Is it the HGR module
         BEQ            :GOT
         LDY            #5
         LDA            (PNT),Y
         STA            PNT+1
         CMP            #$98
         BLT            :LOOK
         RTS
:GOT     LDA            PNT+1
         ADC            #1                        ;Carry is set
         STA            PNT+1
         LDY            #$EB
         LDA            (PNT),Y
         EOR            #7
         ASL
         BNE            :NOGO
         STY            PNT
         LDY            #13
:SETHI   LDA            (PNT),Y
         ORA            #$80
         STA            (PNT),Y
         DEY
         BNE            :SETHI
:NOGO    RTS
