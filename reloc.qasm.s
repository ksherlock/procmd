*
* IIgs procmd utility (qasm version)
*
*

	rel
	lst off
	cas in
	tbx on

*	use e16.memory
	use reloc.qasm.mac
	use qatools.macs

readEnable equ $0001
writeEnable equ $0002

attrLocked equ $8000
attrNoSpec equ $0008






* direct page
	dum 0
user_id	ds 2
handle	ds 4
ptr	ds 4
len	ds 2
q	ds 2

	dend

* 1. parse the command line for input/output files
* 2. load the input file, verify file type, reloc records
* 3. update the header pages/reloc offset
* 4 save to disk


	phk
	plb
	sta user_id

	jsr cmdline
	bcs :exit

	jsr loadfile
	bcs :exit

	jsr check_reloc
	bcs :exith

	jsr savefile
	bcs :exith

	~DisposeHandle handle
	lda #0
	clc
	rtl	


:exith
	~DisposeHandle handle
:exit	lda #1
	sec
	rtl


cmdline
	ph4 #:buffer
	ph2 #256
	_QAGetCmdLine

	lda #0 ; clear high bits
	tay
	shortmx

* _QAGetCmdLine is terminated w/ a CR (included in length).
* replace w/ 0 (to simplify end check) and strip trailing ws

	ldx :buffer
	beq :help
]loop	lda :buffer,x
	cmp #' '+1
	bcs :zt
	dex
	beq :help
	bra ]loop
:zt	stz :buffer+1,x

	longx

	ldx #0
* skip over the utility name....

	ldy #input+2
	sty ptr
	ldy #^input
	sty ptr+2

	jsr :parse1
	bcs :help

	jsr :skipws
	bcs :help

	jsr :parse1
	sty input
	bcs :help

	jsr :skipws
	bcs :help

	ldy #output+2
	sty ptr
	ldy #^output
	sty ptr+2

	jsr :parse1
	sty output
	bcc :help

	rep $30
	clc
	rts
:help
	rep $30
	ldx #0
	brl perr

:buffer	ds 256+2

	mx %10
* output - y = length of <ptr
:parse1

	ldy #0
	sec
	ror q ; bit 7 = no quote char.
]loop
	lda :buffer+1,x
	beq :eof
	inx
	bit q
	bmi :noq
*	in quote...
	cmp q
	beq :eoq
	sta [ptr],y
	iny
	bra ]loop
:eoq	sec
	ror q
	bra ]loop

:noq	cmp #' '+1
	bcc :eop
	cmp #$27
	beq :setq
	cmp #$22
	beq :setq
	sta [ptr],y
	iny
	bra ]loop

:setq	sta q
	bra ]loop



:eof
	sty len
	sec
	rts

:eop
	sty len
	clc
	rts

:skipws
	lda :buffer+1,x
	beq :eofws
	cmp #' '+1
	bcs :nows
	inx
	bra :skipws
:nows	clc
	rts
:eofws	sec
	rts

	mx %00
loadfile

	_GSOS:GetFileInfo info
	bcs :err_toolbox
	lda info_fileType
	cmp #$f8 ; rel
	bne :err_file_type
	lda info_eof+2
	bne :err_too_big


*	ph4 #input
*	ph2 #256
*	tll $0fff


* _QALoadFile expects a p-string
	lda input
	xba
	sta input

	pha ; space
	pha 
	ph4 #input+1
	ph4 #0 ; pos
	ph4 info_eof
	ph4 #0 ; type list
	ph2 user_id
	ph4 #0 ; address
	ph2 #attrLocked.attrNoSpec
	_QALoadFile
	plx
	stx handle
	plx
	stx handle+2
	bcs :err_toolbox

	lda [handle]
	sta ptr
	ldy #2
	lda [handle],y
	sta ptr+2

	lda info_eof
	clc
	adc #$00ff
	xba
*	short m
	sta pages
*	long m
	lda info_auxType
	sta reloc

	clc
	rts

:err_file_type
	ldx #2
	bra perr

:err_too_big
	ldx #4
	bra perr

:err_toolbox
	bra toolerr

toolerr
	pha
	ph4 #:str+14
	ph2 #4
	_Int2Hex
	ph4 #:str
	_QADrawErrString
	sec
	rts

:str	str 'Tool error: $xxxx',0d

perr
	pea ^:0
	lda :etable,x
	pha
	_QADrawErrString
	sec
	rts
:etable
	dw :0,:2,:4
:0	str 'Usage: procmd infile outfile',0d
:2	str 'Not a rel file.',0d
:4	str 'File too large.',0d

check_reloc
	ldy info_auxType ; offset to reloc dict

]loop
	lda [ptr],y
	and #$00ff
	beq :end
	iny
	iny
	iny
	iny

	lsr
	lsr
	lsr
	and #$00fe
	tax
	lda :table,x
	beq ]loop

	pha ; save
	ph4 #:str
	_QADrawErrString

	pla ; restore
	pea #^:0
	pha
	_QADrawErrString
	pea #$0d
	_QADrawErrChar
	sec
	rts

:end
	clc
	rts

:table
	dw 0	; $00 - 1-byte shift ?
	dw :1	; $10 - extern label
	dw :2	; $20 - 3 byte reloc
	dw :0	; $30
	dw 0	; $40 - 1-byte w/ 8-bit shift
	dw :0	; $50
	dw :0	; $60
	dw :0	; $70
	dw 0	; $80 - 2-byte reloc
	dw :0	; $90
	dw :a	; $a0 - 2-byte, byte swapped
	dw :0	; $b0
	dw :c	; $c0 - ds \
	dw :0	; $d0
	dw :e	; $e0 - err
	dw :f	; $f0 - extended shift 	

:str	str 'Relocation error: '

:0	str 'unknown reloc'
:1	str 'extern reloc'
:2	str '3-byte reloc'
:a	str 'ddb reloc'
:c	str 'ds \'
:e	str 'err \'
:f	str 'extended shift reloc'




savefile
	_GSOS:Destroy destroy
	_GSOS:Create create
	bcs :err

	_GSOS:Open open
	bcs :err

	lda open_refNum
	sta io_refNum
	sta close_refNum

	lda #loader
	sta io_buffer
	lda #^loader
	sta io_buffer+2
	lda #$0100
	sta io_reqCount
	stz io_reqCount+2
	_GSOS:Write io

	lda ptr
	sta io_buffer
	lda ptr+2
	sta io_buffer+2
	lda info_eof
	sta io_reqCount
* info_eof+2 must be 0....
	_GSOS:Write io
	_GSOS:Close close
	clc
	rts

:err
	brl toolerr

info
info_pCount	dw 9
info_pathname	adrl input
info_access	ds 2
info_fileType	ds 2
info_auxType	ds 4
info_storageType ds 2
info_create	ds 8
info_mod	ds 8
info_option	adrl 0
info_eof	dl 0


io
io_pCount	dw 4
io_refNum	ds 2
io_buffer	ds 4
io_reqCount	ds 4
io_transCount	ds 4

close
close_pCount	dw 1
close_refNum	ds 2

open
open_pCount	dw 4
open_refNum	ds 2
open_pathname	adrl output
open_reqAccess	dw writeEnable
open_resNum	dw 0


create
create_pCount	dw 4
create_pathname	adrl output
create_access	dw $c3
create_fileType	dw $f0 ; basic cmd
create_auxType	dl $4000 ; load address


destroy
destroy_pCount	dw 1
destroy_pathname adrl output


input	ds 256+2
output	ds 256+2


*
* *** bootloader code ***
*
*

	mx %11
	xc off

STREND   equ   $6d
FRETOP   equ   $6f
MEMSIZ   equ   $73
AMP_VECTOR equ $03f5
CMD_DOSEXIT equ $4103
CMD_AMPEXIT equ $4106
CMD_ID   equ   $411d
WARMDOS  equ   $be00
EXTRNCMD equ   $be06
CLEARC   equ   $d66c
PRINTERR equ   $be0c
GETBUFR  equ   $bef5
P8_MEMTABL equ $bf58      ;memory map of lower 48K
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
         beq   :end_reloc
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

:fatal    lda   #$0c
         jsr   PRINTERR
         jsr   CLEARC
         jmp   WARMDOS

* relocation finished
:end_reloc
         sta   $3e        ;a = 0
         lda   STREND+1
         cmp   #$40
         bcs   :fatal
         lda   $41
         cmp   FRETOP+1
         bcs   :fatal
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
         bcs   :fatal
         sta   $3f
         tax
         eor   $06
         bne   :fatal
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

         err *-loader-$0100

	sav reloc.qasm.L
