* Target assembler: Merlin 16 / QAsm
* 6502bench SourceGen v1.9.0

         xc off
         dsk reloc

STREND   equ   $6d
FRETOP   equ   $6f
MEMSIZ   equ   $73
INBUF    equ   $0200
AMP_VECTOR equ $03f5
CMD_DOSEXIT equ $4103
CMD_AMPEXIT equ $4106
CMD_ID   equ   $411d
WARMDOS  equ   $be00
EXTRNCMD equ   $be06
MERLIN_ADDRESS equ $be08
PRINTERR equ   $be0c
MERLIN_FILETYPE equ $be37
MERLIN_AUXTYPE equ $be38
MERLIN_PATH equ $be80
GETBUFR  equ   $bef5
P8_MEMTABL equ $bf58      ;memory map of lower 48K
SETSTDZP equ   $c008      ;W use main stack and zero page
SETALTZP equ   $c009      ;W use aux stack and zero page
IWM_PH0_OFF equ $c080     ;IWM phase 0 off
IWM_PH1_OFF equ $c082     ;IWM phase 1 off
ROM_AUXMOVE equ $c311
CLEARC   equ   $d66c
MON_HOME equ   $fc58      ;clear screen and reset text output to top-left
MON_GETLN1 equ $fd6f      ;GETLN with no prompt char

         org   $3e80
         pla
         tax
         pla
         bit   $be79      ;merlin stuff?
         sta   SETALTZP
         bvc   L3E8E
         sta   SETSTDZP
L3E8E    pha
         txa
         pha
         bit   IWM_PH0_OFF
         lda   $e002
         cmp   #$e2
         beq   :L3E9F
         cmp   #$e1
         bne   :L3EA6
:L3E9F   lda   $e000
         cmp   #$2d
         beq   :L3EAD
:L3EA6   sta   SETSTDZP
         bit   IWM_PH1_OFF
         rts

:L3EAD   lda   $0a
         sta   $0e
         lda   $0b
         sta   $0f
         jsr   MON_HOME
         jsr   $e033
         asc   "Pathname of LNK file to load: ",00

         jsr   MON_GETLN1
         stx   MERLIN_PATH ;merlin path?
         txa
         bne   :L3EE4
         rts

:L3EE4   lda   INBUF,x
         cmp   #$e0
         bcc   :L3EED
         and   #$df       ;lowercase -> uppercase
:L3EED   sta   MERLIN_PATH+1,x
         dex
         bpl   :L3EE4
         lda   #$00
         sta   MERLIN_ADDRESS
         lda   #$41       ;load file at $4100
         sta   MERLIN_ADDRESS+1
         lda   #$f8       ;$f8 = rel file
         jsr   $b224      ;merlin - load file
         lda   MERLIN_FILETYPE ;merlin - file type
         cmp   #$f8
         beq   :L3F1D
         jsr   $e033
         asc   8d8d,"Not LNK type",8d00
         rts

:L3F1D   clc
         lda   MERLIN_AUXTYPE+1 ;aux type is offset to relocaton table
         tax
         adc   #$41
         sta   reloc+1
         lda   MERLIN_AUXTYPE ;merlin - aux type
         beq   :L3F2D
         inx              ;round up # of pages
:L3F2D   sta   reloc
         stx   pages
         lda   #$f0       ; filetype = $f0 = basic command file 
         sta   $be52      ;merlin stuff....
         lda   reloc
         sta   $42
         lda   reloc+1
         sta   $43
         ldy   #$00
:L3F44   lda   ($42),y    ;; check for invalid reloc opcodes
         beq   :L3FA6     ;eof
         cmp   #$c0       ;err \ or ds \
         bcs   :L3F5C
         and   #$10       ;external label
         bne   :L3F5C
         lda   $42
         iny
         iny
         iny
         iny
         bne   :L3F44
         inc   $43
         bne   :L3F44
:L3F5C   php
         jsr   $e033
         asc   8d8d,"LNK file has ",00
         plp
         bcc   :L3F81
         jsr   $e033
         asc   "\ codes",00
         jmp   :L3F8E

:L3F81   jsr   $e033
         asc   "externals",00
:L3F8E   jsr   $e033
         asc   ".  RELOC aborted.",8d8d00
         rts

:L3FA6   ldy   #$00
         sty   $3c
         sty   $42
         sty   $e2
         sty   $e6
         lda   #$40       ;starting address - $4000
         sta   $3d
         sta   $43
         sta   $e3
         sta   $e7
         lda   $be0a      ;merlin ptr?
         sta   $e4
         sta   $3e
         clc
         lda   $be0b      ;merlin ptr
         sta   $e5
         inc   $e5
         adc   #$41
         sta   $3f
         sec
         jsr   ROM_AUXMOVE
         ldy   #$00
         sty   $e8
         lda   #$ff
         sta   ($0e),y
         jmp   ($b22a)

         ds    \

         err   *-$4000
loader
         cld
         lda   reloc
         sta   $40
         lda   reloc+1
         sta   $41
         lda   MEMSIZ+1
         clc
         adc   #$05
         sbc   pages
         sta   $06
:L4015   ldy   #$00
         lda   ($40),y
         beq   end_reloc
         tax
         iny
         lda   ($40),y
         sta   $3a
         iny
         lda   ($40),y
         clc
         adc   #$41
         sta   $3b
         ldy   #$00
         clc
         lda   $40
         adc   #$04
         sta   $40
         bcc   :L4036
         inc   $41
:L4036   txa
* %1000_0000: 2-byte reloc
* %0100_0000: 1-byte reloc w/8-bit shift
         asl 
         bcc   :L4048     ;1 byte relocation?
         asl   
         bmi   :L403E
         iny
:L403E   lda   ($3a),y
         clc
         adc   $06
         eor   #$80
         sta   ($3a),y
         lsr   
:L4048   bpl   :L4015
         bmi   :L403E

fatal    lda   #$0c
         jsr   PRINTERR
         jsr   CLEARC
         jmp   WARMDOS

* relocation finished
end_reloc
         sta   $3e        ;a = 0
         lda   STREND+1
         cmp   #$40
         bcs   fatal
         lda   $41
         cmp   FRETOP+1
         bcs   fatal
         lda   MEMSIZ+1
         adc   #$04
:L4069   sta   $3f
         cmp   #$9a
         bcs   :L408B
         ldy   #<CMD_AMPEXIT
         lda   ($3e),y
         cmp   #$4c       ;JMP
         bne   :L408B
         ldy   #<CMD_ID
         lda   ($3e),y
         cmp   CMD_ID
         beq   :L40F9
         ldy   #<CMD_DOSEXIT+1
         lda   ($3e),y
         bne   :L408B
         iny
         lda   ($3e),y
         bne   :L4069
:L408B   lda   pages
         jsr   GETBUFR
         bcs   fatal
         sta   $3f
         tax
         eor   $06
         bne   fatal
         tay
         sty   $3e
         sty   $3c
         lda   #$41
         sta   $3d
         lda   AMP_VECTOR+1
         sta   CMD_AMPEXIT+1
         lda   AMP_VECTOR+2
         sta   CMD_AMPEXIT+2
         lda   #$09
         sta   AMP_VECTOR+1
         stx   AMP_VECTOR+2
         lda   EXTRNCMD+1
         sta   CMD_DOSEXIT+1
         lda   EXTRNCMD+2
         sta   CMD_DOSEXIT+2
         sty   EXTRNCMD+1
         stx   EXTRNCMD+2
:L40C9   lda   ($3c),y
         sta   ($3e),y
         iny
         bne   :L40C9
         inc   $3d
         inc   $3f
         dec   pages
         bne   :L40C9
         nop
         nop
:L40DB   txa
         pha
         lsr   
         lsr   
         lsr   
         tay
         txa
         and   #$07
         tax
         lda   #$00
         sec
:L40E8   ror   
         dex
         bpl   :L40E8
         ora   P8_MEMTABL,y
         sta   P8_MEMTABL,y
         pla
         tax
         inx
         cpx   $3f
         bcc   :L40DB
:L40F9   rts

pages    dfb   $00
reloc    dw    $0000
         asc   "GEB"

         err   *-$4100
