
* Disk ][ formatter:

FMASK    =              $3C
TRKCNT   =              $3D
SECTCNT  =              $3E
CHKB     =              $3F
SPEED    =              $40
RETRYH   =              $42
CHKSUM   =              $43
SECTOR   =              $44
TIMECNT  =              $45

         DUM            $240

SECFLAGS DS             $10
FSLOT    BRK
CURTRK   BRK
RETRYCNT BRK
TRACK    BRK
TEMP0    BRK
TEMP1    BRK

         DEND

FORMAT   PHA                                      ;A has unit #
         AND            #$70
         STA            FSLOT
         TAX
         TAY
         PLA
         BPL            :DRIVEON
         INY
:DRIVEON LDA            $C08A,Y                   ;Select drive
         LDA            $C089,X                   ;Spin
         LDA            #$D7
         STA            TIMECNT+1
         LDA            #$50
         STA            CURTRK
         JSR            MYSEEK0                   ;Posn to trk 0
]LUP     LDA            TIMECNT+1                 ;Wait for speed up
         BEQ            :1
         JSR            FTIME
         JMP            ]LUP

:1       LDA            #$AA
         STA            FMASK                     ;Always
         LDX            SLOWEST
         INX
         INX
         STX            SPEED                     ;Set speed too slow
         LDA            #0                        ;-> track 0
         STA            TRKCNT
]LUP     LDX            FSLOT                     ;A has TRKCNT
         JSR            MYSEEK                    ;Seek trk to format
         LDA            $C08D,X
         LDA            $C08E,X                   ;Write prot
         TAY
         LDA            $C08E,X                   ;Select read mode
         LDA            $C08C,X
         TYA
         BMI            WPERR
         JSR            FMTTRK
         LDY            SPEED
         BCS            IOERR
         CPY            FASTEST
         BLT            IOERR
         CPY            SLOWEST
         BGE            IOERR
         LDA            RETRIES
         JSR            FIND0
         BCC            ]LUP
         BCS            DRIVEOFF

]LUP     LDX            FSLOT                     ;A has TRKCNT
         JSR            MYSEEK
         LDA            $C08E,X                   ;Read mode
         LDA            $C08C,X
         LDA            RETRIES
         ASL
         JSR            FIND0
         BCC            ]LUP
DRIVEOFF LDX            FSLOT
         LDA            $C088,X                   ;Motor off
MYSEEK0  LDA            #0
MYSEEK   ASL
         ASL            CURTRK
         JSR            SEEKABS                   ;Position head on trk
         LSR            CURTRK
         RTS                                      ;CC

FIND0    STA            RETRYCNT
:RTRY    DEC            RETRYCNT
         BEQ            :IOERR
         JSR            READADR
         BCS            :RTRY
         LDA            TIMECNT                   ;This holds the trk
         EOR            TRKCNT                    ; if not track looked for
         ORA            SECTOR                    ; or if not sector 0
         BNE            :RTRY                     ; then try again
         JSR            READSEC                   ;Read sector 0 data
         BCS            :RTRY
         INC            TRKCNT
         LDA            TRKCNT                    ;(This helps reposn
         CMP            #35                       ; formatting for fast
         RTS                                      ; access of next track.)

:IOERR   PLA
         PLA
IOERR    LDA            #8
         HEX            2C
WPERR    LDA            #4
         PHA
         LDX            FSLOT
         LDA            $C088,X
         PLA
         SEC
         RTS

         CYC
READSEC  LDX            FSLOT
         LDY            #$20                      ;Y: 32 attempts
:1       DEY
         BEQ            ERR
]LUP     LDA            $C08C,X
         BPL            ]LUP
:FINDD5  EOR            #$D5
         BNE            :1
         NOP
]LUP     LDA            $C08C,X
         BPL            ]LUP
         CMP            #$AA
         BNE            :FINDD5
         LDY            #$57                      ;For $157 nibbles
]LUP     LDA            $C08C,X                   ;D5,AA,AD seq?
         BPL            ]LUP
         CMP            #$AD
         BNE            :FINDD5                   ;Try again if not
         BIT            WAITRTS                   ;Set V
         BVS            :READDAT
:CV      CLV                                      ;Clear V for 2nd go
:READDAT LDA            $C08C,X                   ;Check $157
         BPL            :READDAT                  ; nibbles = $96
         CMP            #$96
         BNE            ERR
         DEY
         BNE            :READDAT
         BVS            :CV
]LUP     LDA            $C08C,X                   ;Check for DE,AA
         BPL            ]LUP
         CMP            #$DE
         BNE            ERR
         NOP
]LUP     LDA            $C08C,X
         BPL            ]LUP
         CMP            #$AA
         BEQ            OKRET
ERR      SEC
         RTS

READADR  LDX            FSLOT
         LDY            #$FC
         STY            $DC
:1       INY
         BNE            :2
         INC            $DC
         BEQ            ERR
:2       LDA            $C08C,X                   ;Find D5,AA,96 seq
         BPL            :2
:GETD5   CMP            #$D5
         BNE            :1
         NOP
]LUP     LDA            $C08C,X
         BPL            ]LUP
         CMP            #$AA
         BNE            :GETD5
         LDY            #3                        ;4 headers
]LUP     LDA            $C08C,X
         BPL            ]LUP
         CMP            #$96
         BNE            :GETD5
         LDA            #0
:3       STA            $DB
]LUP     LDA            $C08C,X                   ;Decode 4 bytes
         BPL            ]LUP
         ROL
         STA            $DD
]LUP     LDA            $C08C,X
         BPL            ]LUP
         AND            $DD
         STA            CHKSUM,Y
         EOR            $DB
         DEY
         BPL            :3
         TAY
         BNE            ERR                       ;Err if bad chksum
]LUP     LDA            $C08C,X                   ;Check DE,AA tail
         BPL            ]LUP
         CMP            #$DE
         BNE            ERR
         NOP
]LUP     LDA            $C08C,X
         BPL            ]LUP
         CMP            #$AA
         BNE            ERR
OKRET    CLC
         RTS

SEEKABS  STA            TRACK                     ;Save trk, X=slot
         CMP            CURTRK                    ;If have it,rtn
         BEQ            :RET
         LDA            #0
         STA            TEMP0                     ;Clear step cnter
:1       LDA            CURTRK
         STA            TEMP1                     ;Save cur track #
         SEC
         SBC            TRACK                     ;Calculate diff
         BEQ            :4                        ;If there, exit
         BCS            :STEPDWN                  ;If want lower,
         EOR            #$FF                      ; down, else up
         INC            CURTRK
         BCC            :STEPUP
:STEPDWN ADC            #-2
         DEC            CURTRK
:STEPUP  CMP            TEMP0
         BCC            :2                        ;BRA if A < step cnt
         LDA            TEMP0
:2       CMP            #$C                       ;If < $C then
         BCS            :3
         TAY                                      ; put A in Y
:3       SEC                                      ;Set C for phase on
         JSR            :STEP
         LDA            TIMTBL1,Y                 ;Get time
         JSR            FTIME                     ; & wait
         LDA            TEMP1                     ;Get previous trk
         CLC                                      ;CC for phase off
         JSR            :STEP1
         LDA            TIMTBL2,Y
         JSR            FTIME
         INC            TEMP0                     ;Increment step ctr
         BNE            :1                        ;Always

:4       JSR            FTIME                     ;Wait
         CLC                                      ;Prepare: phase off
:STEP    LDA            CURTRK                    ;Get current track
:STEP1   AND            #3                        ; mod 4
         ROL                                      ; *2, carry to bit 0
         ORA            FSLOT                     ;Add slot offset
         TAX
         LDA            $C080,X                   ;Step
         LDX            FSLOT                     ;Restore slot #
:RET     RTS

WRITESEC JSR            WAITRTS
         LDA            $C08D,X                   ;Sense write prot
         LDA            $C08E,X
         LDA            #$FF                      ;Prepare to write
         STA            $C08F,X                   ;Turn on write mode
         CMP            $C08C,X                   ; and write one (?)
         PHA
         PLA
         NOP
         LDY            #4                        ;4 more of them
:1       PHA
         PLA
         JSR            WR_NBL2                   ;Write self syncs
         DEY
         BNE            :1
         LDA            #$D5                      ;Write data field
         JSR            WR_NBL1                   ; header D5,AA,AD
         LDA            #$AA
         JSR            WR_NBL1
         LDA            #$AD
         JSR            WR_NBL1
         BIT            WAITRTS                   ;Set V
         NOP
         LDY            #$57                      ;Prepare count to
         BNE            :2                        ; write $157 $96's

:CV      CLV
         PHA
         PLA
         BVC            :3

]LUP     JSR            WAITRTS
:2       NOP
:3       NOP
         LDA            #$96
         STA            $C08D,X
         CMP            $C08C,X
         DEY
         BNE            ]LUP
         BVS            :CV
         LDA            #$DE                      ;Tail DE,AA,EB,FF
         JSR            WR_NBL1
         LDA            #$AA
         JSR            WR_NBL1
         LDA            #$EB
         JSR            WR_NBL1
         LDA            #$FF
         JSR            WR_NBL1
         LDA            $C08E,X                   ;Read
         LDA            $C08C,X
         RTS

WRTADR   EOR            TRKCNT                    ;A has SECTCNT
         EOR            #1                        ;Volume
         STA            CHKB                      ;Save to wrt later
         LDA            $C08D,X                   ;Sense write prot
         LDA            $C08E,X
         LDA            #$FF                      ;Prepare to write
         STA            $C08F,X                   ; self syncs
         CMP            $C08C,X
         PHA
         PLA
:1       JSR            WAITRTS                   ;Count is in SPEED
         JSR            WAITRTS
         STA            $C08D,X                   ;Write self sync
         CMP            $C08C,X
         NOP
         DEY
         BNE            :1
         LDA            #$D5                      ;Header D5,AA,96
         JSR            WR_NBL1
         LDA            #$AA
         JSR            WR_NBL1
         LDA            #$96
         JSR            WR_NBL1
         LDA            #$AA                      ;Nibbles of VOL
         JSR            WR_NBL1
         LDA            #$AB
         JSR            WR_NBL1
         LDA            TRKCNT                    ;Track #
         JSR            WRTBYTE
         LDA            SECTCNT                   ;Sector #
         JSR            WRTBYTE
         LDA            CHKB                      ;Checksum
         JSR            WRTBYTE
         LDA            #$DE
         JSR            WR_NBL1                   ;Tail DE,AA,EB
         LDA            #$AA
         JSR            WR_NBL1
         LDA            #$EB
         JSR            WR_NBL1
         CLC                                      ;Success
         LDA            $C08E,X                   ;Read mode
         LDA            $C08C,X
         RTS

WRTBYTE  PHA
         LSR                                      ;Shift and mask
         ORA            FMASK
         STA            $C08D,X                   ;Write nibble
         CMP            $C08C,X
         PLA
         ORA            FMASK
         PHA
         PLA
WR_NBL1  NOP
WR_NBL2  PHA
         PLA
         STA            $C08D,X                   ;Write nibble
         CMP            $C08C,X
         RTS

FTIME    LDX            #$11
]LUP     DEX
         BNE            ]LUP
         INC            TIMECNT
         BNE            :NI
         INC            TIMECNT+1
:NI      SEC
         SBC            #1
         BNE            FTIME
         RTS

FMTTRK   LDA            RETRIESH                  ;Retry count for
         STA            RETRYH                    ; tot trk reformat
FMTTRACK LDY            #$80                      ;# of sync codes
         LDX            FSLOT
         LDA            #0                        ;Sector 0
         STA            SECTCNT
         HEX            2C
:1       LDY            SPEED                     ;# syncs to use
         JSR            WRTADR                    ;Write adrs
         JSR            WRITESEC                  ;Write data
         INC            SECTCNT                   ;Next sector
         LDA            SECTCNT
         CMP            #$10
         BCC            :1
         LDY            #$F
         STY            SECTCNT
]LUP     STA            SECFLAGS,Y                ;Sector flags +
         DEY
         BPL            ]LUP
         LDA            RETRIES
         STA            RETRYCNT
         LDA            SPEED
         SBC            #5
         TAY
:DELAY   JSR            WAITRTS
         JSR            WAITRTS
         PHA
         PLA
         NOP
         NOP
         DEY
         BNE            :DELAY
         JSR            READADR                   ;Read adrs field
         BCS            :2                        ;Br if cannot
         LDA            SECTOR
         BEQ            :RDDATA                   ;Br if found sec 0
         DEC            SPEED                     ;If can't, speed up
         LDA            SPEED
         CMP            FASTEST
         BGE            :2
         SEC                                      ;Too fast
         RTS

         CYC            OFF
:NXADR   JSR            READADR                   ;Read next address field
         BCS            :RETRY
:RDDATA  JSR            READSEC                   ; & data field
         BCS            :RETRY
         LDY            SECTOR                    ;Point to sector read
         LDA            SECFLAGS,Y
         BMI            :RETRY                    ;Retry if this was done
         LDA            #$FF
         STA            SECFLAGS,Y                ;Flag as done
         DEC            SECTCNT                   ;Countdwn 16 sectors
         BPL            :NXADR                    ;Loop till all checked
         CLC
         RTS

:RETRY   DEC            RETRYCNT
         BNE            :NXADR                    ;Try again
         DEC            RETRYH                    ;If track reformatted
         BEQ            :GIVUP                    ; 3 times, give up
:2       LDA            RETRIES
         ASL
         STA            RETRYCNT
:GETF    JSR            READADR                   ;Find sector 15
         BCS            :TRYMORE
         LDA            SECTOR
         CMP            #$F
         BEQ            GOTF
:TRYMORE DEC            RETRYCNT
         BNE            :GETF
:GIVUP   SEC                                      ;Give up if no 15
WAITRTS  RTS                                      ; or if retries used up

GOTF     LDX            #$D6                      ;Format bad but found
]LUP     JSR            WAITRTS                   ; sector 15,
         JSR            WAITRTS                   ; then reformat track
         BIT            $00                       ; (3 tries)
         DEX
         BNE            ]LUP
         JMP            FMTTRACK

FASTEST  HEX            0E
SLOWEST  HEX            1B
RETRIESH HEX            03
RETRIES  HEX            10

TIMTBL1  HEX            01,30,28,24,20,1E,1D,1C,1C,1C,1C,1C

TIMTBL2  HEX            70,2C,26,22,1F,1E,1D,1C,1C,1C,1C,1C
