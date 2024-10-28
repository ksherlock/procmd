********************************
*                              *
* CONVGR (hires -> doub hires) *
*                              *
*   Glen E. Bredon   3/22/85   *
*    Revised for RGB 3/19/86   *
********************************

         DATE

         TR
         EXP            OFF

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

* Switches:

STORE80  =              $C001
COL80OFF =              $C00C
COL80ON  =              $C00D
RDTEXT   =              $C01A
RDMIXED  =              $C01B
RD80COL  =              $C01F
GR       =              $C050
TEXT     =              $C051
FULL     =              $C052
MIXED    =              $C053
PAGE1    =              $C054
PAGE2    =              $C055
HIRES    =              $C057
DHIRES   =              $C05E
SHIRES   =              $C05F

TEMP     =              $1A
GBASL    =              $26
GBASH    =              $27
HPAG     =              $E6
STATE    =              $FF
DOWN     =              $F504

STADR    MAC
         LDA            #]1
         STA            ]2
         LDA            #>]1
         STA            ]2+1
         <<<

         ORG            $300

         LDA            RD80COL                   ;Save machine state
         AND            #$80                      ; (only 80 col, text, mix)
         BIT            RDTEXT
         BMI            :OV
         ORA            #$40
:OV      BIT            RDMIXED
         BMI            :SS
         ORA            #$20
:SS      STA            STATE
         STA            STORE80                   ;Turn on double hires
         BIT            HIRES
         BIT            FULL
         BIT            GR
         STA            COL80ON
         LDA            DHIRES
         LDA            SHIRES
         LDA            DHIRES
         LDA            SHIRES
         LDA            DHIRES
         STADR          $2000;GBASL
         STA            HPAG                      ;For DOWN routine
:NXLIN   LDY            #0
:LOOP    LDA            (GBASL),Y
         STA            TEMP                      ;To test high bit
         AND            #%1111
         TAX
         LDA            TABLE,X
         CLC
         BIT            TEMP
         BMI            :SA
         LSR
:SA      BIT            PAGE2
         ORA            #$80
         STA            (GBASL),Y
         BIT            PAGE1
         BCC            :LG
         DEY
         BMI            :YI
         LDA            (GBASL),Y
         ORA            #%11000000
         STA            (GBASL),Y
:YI      INY
:LG      LDA            TEMP
         LSR
         LSR
         LSR
         AND            #%1111                    ;Note mid bit overlaps
         TAX
         LDA            TABLE,X
         LSR                                      ;Adjust for main
         CLC
         BIT            TEMP
         BMI            :SM
         LSR
:SM      ORA            #$80
         STA            (GBASL),Y
         BCC            :IY
         BIT            PAGE2
         LDA            (GBASL),Y
         ORA            #%11000000
         STA            (GBASL),Y
         BIT            PAGE1
:IY      INY
         CPY            #40
         BLT            :LOOP
         JSR            DOWN
         LDA            GBASL
         BNE            :NXLIN
         LDA            GBASH
         CMP            #$20
         BNE            :NXLIN
         BIT            STATE
         BNE            :OV1
         STA            MIXED
:OV1     BVS            :OV2
         STA            TEXT
:OV2     BMI            :RET
         STA            COL80OFF
:RET     RTS

TABLE    DFB            %00000000
         DFB            %00000011
         DFB            %00001100
         DFB            %00001111
         DFB            %00110000
         DFB            %00110011
         DFB            %00111100
         DFB            %00111111
         DFB            %11000000
         DFB            %11000011
         DFB            %11001100
         DFB            %11001111
         DFB            %11110000
         DFB            %11110011
         DFB            %11111100
         DFB            %11111111

         ERR            \$3D0

         DO             SAVOBJ
         SAV            CONVGR
         FIN
