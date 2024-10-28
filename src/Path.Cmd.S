******************************
*                            *
*       PATH BASIC CMD       *
*----------------------------*
*  Glen E. Bredon   1/17/87  *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/PATH.CMD
         FIN

         EXP            OFF
         TR

HIMEM    =              $73
KEYBLK   =              $D0
LEN      =              $D2
COUNT    =              $D3
PATHPNT  =              $D4
PNT      =              $E0
TYPEFLAG =              $E2
CHRGOT   =              $B7
IN       =              $200
COUT     =              $FDED

* ProDOS MLI call codes:

blkread  =              $80
setpfx   =              $C6

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters
FBITS    =              $BE56                     ;Parameter bits found
VSLOT    =              $BE61
VDRIV    =              $BE62
VTYPE    =              $BE6A                     ;T parameter value
VPATH1   =              $BE6C                     ;Pathname addrs
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
MLI      =              $BF00
DEVNUM   =              $BF30
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

MOVD     MAC
         LDA            ]1
         STA            ]2
         LDA            ]1+1
         STA            ]2+1
         <<<

STADR    MAC
         LDA            #]1
         STA            ]2
         LDA            #>]1
         STA            ]2+1
         <<<

DOS      MAC
         JSR            MLI
         DFB            ]1
         DA             ]2
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
         CPY            #AMPEND-CMDNAME
         BLT            :SN                       ; give list of all dos cmds.
         JSR            CHRGOT                    ;Reestablish A and status
         BEQ            AMPEXIT                   ;Go to next routine (always)

         DFB            30                        ;Signature

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
         LDX            #%100                     ;Allow S,D
         STX            PBITS+1
         LDX            #%101                     ;T allowed, filename expected
         STX            PBITS                     ;File name expected
         STADR          DOPATH;XTRNADDR
         CLC                                      ;Say we accept the cmd
         RTS

CMDNAME  ASC            "PATH"
CMDEND   ASC            " filename [,T type,S#,D#]"8D
AMPEND

READBLK  DOS            blkread;BLKPARMS
         BCC            RTN
         PLA
         PLA
         BCS            IOERR

DOPATH   LDA            FBITS
         LSR                                      ;Found file name?
         BCS            T1                        ;Branch if so
NOTFND   LDA            #6                        ;Path not found error
         SEC
RTN      RTS

FOUND    DOS            setpfx;PFXPARMS
         BCC            RTN
IOERR    LDA            #8
         SEC
         RTS

T1       LSR
         LSR
         ROR            TYPEFLAG                  ;Type specified if -
         LDA            #2
         STA            BLOCK
         LDY            #0
         STY            BLOCK+1                   ;Do here for reentry
         LDA            HIMEM+1
         STA            BLKBUF+1
         LDA            FBITS+1
         AND            #%100
         BNE            :DEV                      ;Branch if S,D params given
         LDA            DEVNUM                    ; else use current device
         BNE            :SETDEV
:DEV     LDA            VSLOT
         ASL
         ASL
         ASL
         ASL
         ASL                                      ;slot * $20
         PHA
         LDA            VDRIV
         LSR
         LSR                                      ;Drive bit 1 to carry
         PLA
         ROR                                      ;Rotate drive into slot
:SETDEV  STA            BLKUNIT
         MOVD           VPATH1;PATHPNT
         STY            IN+$80                    ;=0
         LDA            (PATHPNT),Y
         STA            LEN
         TAY
:FINDSL  DEY
         BEQ            :MOVNAM
         LDA            (PATHPNT),Y               ;If S,D given we must isolate
         CMP            #'/'
         BNE            :FINDSL                   ; the filename from the vol name
:MOVNAM  LDX            #0
:MN      INX
         INY
         LDA            (PATHPNT),Y
         STA            IN+$40,X                  ;Put the search name here
         CPY            LEN
         BLT            :MN
         STX            IN+$40                    ; with length
:DIRLOOP JSR            READBLK
         MOVD           BLOCK;KEYBLK              ;Save header blk this dir
         LDY            #4
         LDA            (HIMEM),Y                 ;Get dir name length
         AND            #$F
         BEQ            IOERR                     ;Safety check
         STA            LEN
         LDX            IN+$80
         LDA            #'/'
:IX      INX                                      ;Append to current prefix
         STA            IN+$80,X
         INY
         LDA            (HIMEM),Y
         DEC            LEN
         BPL            :IX
         STX            IN+$80                    ; and set new length
:LOOP    LDA            #1                        ;Set to look at next file
:LUP     STA            COUNT                     ; or the one in this location
         TAY
         JSR            LOOK                      ;Returns
         BCS            :SUB                      ; CS if a subdir
         LDY            #2                        ; CC if not on this block
         LDA            (HIMEM),Y
         STA            BLOCK                     ;Get next dir block
         INY
         LDA            (HIMEM),Y
         STA            BLOCK+1
         ORA            BLOCK
         BEQ            :POP                      ;If link 0 then pop a level
         JSR            READBLK                   ; else read next block
         BCC            :LOOP                     ;Always

:SUB     LDY            #$11
         LDA            (PNT),Y                   ;Key pointer of subdir
         STA            BLOCK
         INY
         LDA            (PNT),Y
         STA            BLOCK+1
         JMP            :DIRLOOP

:POP     LDX            IN+$80                    ;Not in this dir, so pop level
:PP      DEX
         BEQ            :RET
         LDA            IN+$80,X
         CMP            #'/'
         BNE            :PP
         DEX
         BEQ            :RET
         STX            IN+$80                    ;Reset name length
         MOVD           KEYBLK;BLOCK
         JSR            READBLK                   ;Get key block this dir
         LDY            #$27
         LDA            (HIMEM),Y                 ;Parent block
         STA            BLOCK
         INY
         LDA            (HIMEM),Y
         STA            BLOCK+1
         INY
         LDA            (HIMEM),Y                 ;Parent entry #
         STA            COUNT
         JSR            READBLK                   ;Read the parent
         LDY            #-1                       ;Set Y neg for branch flag
         LDX            COUNT
         INX                                      ;Next count (preserved by:)
         JSR            LOOK                      ;Just to position PNT
         LDY            #$25
         LDA            (PNT),Y
         STA            KEYBLK                    ;Get header block of previous
         INY                                      ; directory for next POP
         LDA            (PNT),Y
         STA            KEYBLK+1
         TXA
         BPL            :LUP                      ;Process next entry in prev dir
:RET     JMP            NOTFND

LOOK     LDA            HIMEM+1                   ;Set PNT->block buffer+4
         STA            PNT+1
         LDA            #4
:ADD     STA            PNT
         DEC            COUNT                     ;Count down entry number
         BEQ            :LOOK
:NEXT    LDA            PNT
         CLC
         ADC            #$27                      ;Bump be entry length
         BCC            :NC
         INC            PNT+1
:NC      CMP            #$FF                      ;Test last one of block
         BNE            :ADD
         CLC                                      ;Signal block finished
:RET     RTS
:LOOK    TYA
         BMI            :RET                      ;Return if from POP
         LDY            #1
         STY            COUNT                     ;Prepare to look at next entry
         DEY
         LDA            (PNT),Y
         AND            #$F
         BEQ            :NEXT                     ;Skip if inactive
         TAX
         LDA            (PNT),Y
         AND            #$F0
         CMP            #$D0
         BEQ            :RET                      ;Return CS if subdir
         TXA                                      ;Get length again
         EOR            IN+$40
         AND            #$F
         BNE            :NEXT                     ;Skip if not correct length
         BIT            TYPEFLAG
         BPL            :IY                       ;Branch if type not given
         LDA            (PNT),Y
         AND            #%11100000
         CMP            #$E0                      ;In case it is header
         BNE            :NOTH
         LDA            #$F
         BNE            :TSTT                     ;Branch if looking at DIR
:NOTH    LDY            #$10
         LDA            (PNT),Y                   ;Get current file type
:TSTT    EOR            VTYPE                     ;Test against desired type
         BNE            :NEXT                     ;Skip if different
         TAY                                      ;=0
:IY      INY
         LDA            (PNT),Y
         EOR            IN+$40,Y                  ;Check if name is same
         AND            #%01011111                ;Sign and case insensitive
         BNE            :NEXT                     ;Skip if not the same
         DEX
         BNE            :IY
         PLA                                      ;Else pop stack and
         PLA
         JMP            FOUND                     ; go set prefix & back.

BLKPARMS DFB            3
BLKUNIT  DFB            $70
BLKBUF   DA             $9400
BLOCK    DA             2

PFXPARMS DFB            1
         DA             IN+$80
