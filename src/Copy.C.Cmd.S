******************************
*                            *
*       COPY BASIC CMD       *
*                            *
*  Glen E. Bredon  8/26/89   *
*     Original 12/16/84      *
******************************

         DATE

         REL              ;Generate a LNK file

SAVOBJ   KBD   "Save object (0=no, 1=yes)?"

         DO    SAVOBJ
         DSK   OBJECT/COPY.C.CMD
         FIN

         EXP   OFF
         TR
         TR    ADR
         XC
         XC

STREND   =     $6D        ;Bottom of free space
FRETOP   =     $6F        ;Top of free space
HIMEM    =     $73        ;Bottom of system buffer
CHRGOT   =     $B7
PATHPNT1 =     $E0        ;Source pathname ptr
PATHPNT2 =     $E2        ;Dest " (for moving 2->1)
SRCREF   =     $E4        ;Source ref #
DESTREF  =     $E5        ;Dest ref #
COUNT    =     $E6        ;# bytes in file
PAGES    =     $E9        ;# pages done at a time
PNT1     =     $EA
PNT2     =     $EC
TEMP     =     $EE
FLAG     =     PATHPNT1   ;Final block of copy flag
IN       =     $200
COUT     =     $FDED

* ProDOS MLI call codes:

create   =     $C0
destroy  =     $C1
setinfo  =     $C3
getinfo  =     $C4
open     =     $C8
read     =     $CA
write    =     $CB
close    =     $CC
setmark  =     $CE
getmark  =     $CF
seteof   =     $D0
geteof   =     $D1

* ProDOS BASIC interp locations:

XTRNADDR =     $BE50      ;External command vector
XLEN     =     $BE52      ;Length of cmd -1 put here
XCNUM    =     $BE53      ;Put 0 here for ext cmd
PBITS    =     $BE54      ;Parameters
FBITS    =     $BE56      ;Parameter bits found
VPATH1   =     $BE6C      ;Pointer to pathname 1
VPATH2   =     $BE6E      ; " 2
GOSYSTEM =     $BE70      ;Call MLI routine
XRETURN  =     $BE9E      ;RTS (for dos cmd linking)
CRACESS  =     $BEA3      ;Create access parm
CRFILID  =     $BEA4      ;  " file type
INFPARMS =     $BEB4      ;GETINFO parm list
FIACCESS =     $BEB7      ;Access parm
FILETYPE =     $BEB8      ;File type put here
FIFKIND  =     $BEBB      ;Kind of file (tree/dir)
SREFNUM  =     $BEC7      ;Ref # for geteof
SMARK    =     $BEC8      ;File size (3 bytes)
OSYSBUF  =     $BECE      ;Buffer ptr for OPEN
OREFNUM  =     $BED0      ;File ref # for OPEN
RWREFNUM =     $BED6      ;Ref # for read/write
RWDATA   =     $BED7      ;Buffer ptr for read/write
RWCOUNT  =     $BED9      ;# of bytes to read/write
CFREFNUM =     $BEDE      ;Ref # for CLOSE
DATETIME =     $BF06      ;Date jmp
SERR     =     $BF0F      ;MLI error code
DATE     =     $BF90      ;Date and time
MONRTS   =     $FFCB      ;Has RTS (for & linking)

STADR    MAC
         LDA   #]1
         STA   ]2
         LDA   #>]1
         STA   ]2+1
         <<<

MOVD     MAC
         LDA   ]1
         STA   ]2
         LDA   ]1+1
         STA   ]2+1
         <<<

DOS      MAC
         LDA   #]1
         JSR   GOSYSTEM
         <<<

         DUMMY $2E0
OURINF   DFB   10
         DA    0          ;Pathname ptr
ACCESS   DFB   0          ;Access
FILEID   DFB   0
         DA    0          ;Aux type
         DFB   0          ;Kind
         DA    0          ;#Blocks
         DA    0          ;Mod date
         DA    0          ; & time
OURDATE  DA    0          ;Create date
         DA    0          ; & time
INFEND   DEND

         AST   50
*
* NOTE: The JMPs at DOSEXIT and AMPEXIT are modified
* by the relocation header for daisy chaining.

DOSENTRY JMP   PARSE
DOSEXIT  JMP   XRETURN
AMPEXIT  JMP   MONRTS
AMPENTRY BNE   AMPEXIT
         LDY   #0
:SN      LDA   CMDNAME,Y
         JSR   COUT
         INY
         CPY   #AMPEND-CMDNAME
         BLT   :SN
         JSR   CHRGOT
         BEQ   AMPEXIT

         DFB   9          ;Signature

PARSE    LDX   #CMDEND-CMDNAME
:ISIT    LDA   IN-1,X
         AND   #%11011111
         EOR   CMDNAME-1,X
         SEC              ;In case we exit here
         BNE   DOSEXIT    ;Support daisy chain
         DEX
         BNE   :ISIT
         STX   XCNUM      ;Signal external cmd
         STADR DOCOPY;XTRNADDR
         LDA   #CMDEND-CMDNAME-1
         STA   XLEN       ;Length of cmd
         LDA   #%11       ;Two file names expected
         STA   PBITS
         STX   PBITS+1
         STX   DESTREF    ;Flag for CLOSE
         CLC              ;Say we accept the cmd
         RTS

CMDNAME  ASC   "COPY"
CMDEND   ASC   " source pathname, dest pathname"8D
AMPEND

DOCOPY   LDA   FBITS
         LSR              ;Found file name?
         BCS   :FND       ;Branch if so
:SYNERR  LDA   #11        ;Syntax error
:ERROR   SEC
:MLIERR  RTS

:FND     LSR              ;Second name given?
         BCC   :SYNERR    ;Error if not
         LDA   FRETOP+1
         SBC   STREND+1   ;Get free space
         SBC   #6         ;Part pg & 4 pgs for buffer
         BEQ   :TOOL      ;Error if no pages left
         BCS   :MEMOK     ; or if even less
:TOOL    LDA   #14        ;Program too large
         BNE   :ERROR
:MEMOK   INC
         AND   #%11111110 ;Mask to blocks
         STA   PAGES      ;# pages for copy buffer
         LDA   #10        ;# of parms for GETINFO
         STA   INFPARMS
         DOS   getinfo
         BCS   :MLIERR
         LDY   #INFEND-OURINF-1
:MP      LDA   INFPARMS,Y ;Save info on orig file
         STA   OURINF,Y
         DEY
         BPL   :MP
         LDA   FIFKIND    ;What kind of file?
         AND   #%11111100
         BNE   :BADTYPE   ;Reject dir & nonstandard
         LDY   HIMEM+1    ;Adrs high of system buffer
         STY   OSYSBUF+1
         DOS   open       ;Open orig file
         BCS   :CLSERR    ;Close if error
         LDA   OREFNUM
         STA   SRCREF
         STA   SREFNUM
         DOS   geteof
         BCS   :CLSERR
         LDX   #3
]LUP     LDA   SMARK-1,X
         STA   COUNT-1,X
         DEX
         BNE   ]LUP
         LDX   #2
]LUP     LDA   VPATH1-1,X
         STA   PATHPNT1-1,X
         LDA   VPATH2-1,X
         STA   PATHPNT2-1,X
         DEX
         BNE   ]LUP
         LDA   (PATHPNT2,X)
         TAY              ;Length of path 2
:MVN     LDA   (PATHPNT2),Y
         STA   (PATHPNT1),Y
         DEY              ;Now points to pathname 2
         BPL   :MVN
         DOS   getinfo    ;Does it exist?
         BCS   :CREATE    ;Branch if not
         LDA   FILETYPE
         CMP   FILEID     ;Correct type?
         BEQ   :FOK       ;Branch if so
:BADTYPE LDA   #13        ;Type mismatch error
:CLSERR  JSR   CLOSE      ;Close both files
         SEC              ;Signal an error
         RTS

:FOK     LDA   #$C3
         STA   FIACCESS
         JSR   SETINFO
         BCS   :CLSERR
         DOS   destroy    ;Erase file 2 that exists
         BCC   :OV
         BCS   :CLSERR
:CREATE  LDY   SERR
         CPY   #$46       ;Path not found?
         BNE   :CLSERR    ;Abort if not
:OV      LDX   #3
         SEI
         LDY   DATETIME   ;Save the JMP or ?
:CRE     LDA   DATE,X     ;Save real date
         STA   FLAG,X
         LDA   OURDATE,X  ;Set up orig date
         STA   DATE,X     ; for create
         LDA   FILEID,X   ;Also filetype, aux type
         STA   CRFILID,X  ; and storage type
         DEX
         BPL   :CRE
         LDA   #$60
         STA   DATETIME   ;Disable date routine
         LDA   ACCESS     ;Make sure we can do write
         ORA   #%10000011
         STA   CRACESS
         DOS   create     ;Create file 2
         STY   DATETIME   ;Fix date call
         PHA              ;Save error code
         LDX   #3         ;(Must preserve carry)
:FD      LDA   FLAG,X     ;Replace real date
         STA   DATE,X
         DEX
         BPL   :FD
         PLA              ;Error code back
         CLI
:BCLSERR BCS   :CLSERR
         LDY   STREND+1
         INY              ;Use 1st 4 free pages
         STY   OSYSBUF+1  ; for file 2 buffer
         DOS   open       ;Open file 2
         BCS   :CLSERR
         LDA   OREFNUM
         STA   DESTREF    ;Remember ref for file 2
         STZ   FLAG       ;Flag not last block
         STZ   RWDATA     ;Data buffer on pg bdry
         LDA   COUNT
         ORA   COUNT+1
         ORA   COUNT+2
         BNE   :NEXT
         BRL   :DONE

:NEXT    STZ   RWCOUNT
         LDA   PAGES      ;# of data pages can use
         STA   RWCOUNT+1
         SEC
         LDA   COUNT+1
         SBC   PAGES
         TAX
         LDA   COUNT+2
         SBC   #0
         BLT   :LAST      ;Branch if last block
         BNE   :NOTL      ;  " if not
         TXY
         BNE   :NOTL
         LDY   COUNT
         BNE   :NOTL
:LAST    MOVD  COUNT;RWCOUNT
         SEC
         ROR   FLAG       ;Flag last block
:NOTL    STA   COUNT+2    ;Decrease count by pages
         STX   COUNT+1
         LDA   SRCREF
         STA   RWREFNUM
         LDA   STREND+1
         CLC
         ADC   #5         ;(this one)
         STA   RWDATA+1
         DOS   read       ;Read from source
:BERR    BCS   :BCLSERR
         LDA   DESTREF
         STA   RWREFNUM
         STA   SREFNUM
         MOVD  RWCOUNT;TEMP
         STZ   PNT1
         STZ   PNT2
         LDA   RWDATA+1
]LOOP    STA   PNT1+1
         INC
         STA   PNT2+1
         LDA   TEMP+1
         SEC
         SBC   #2
         BCC   :WRT
         STA   TEMP+1
         LDA   #2
         STA   RWCOUNT+1
         STZ   RWCOUNT
         LDY   #0
]LUP     LDA   (PNT1),Y
         ORA   (PNT2),Y
         BNE   :DOW
         INY
         BNE   ]LUP
         DOS   getmark
         BCS   :BERR
         LDA   SMARK+1
         ADC   #2
         STA   SMARK+1
         BCC   :SEOF
         INC   SMARK+2
:SEOF    DOS   seteof
         BCS   :BERR
         DOS   setmark
         BCS   :BERR
         BRA   :OVER

:DOW     DOS   write
:BBERR   BCS   :BERR
:OVER    INC   RWDATA+1
         INC   RWDATA+1
         LDA   PNT1+1
         INC
         INC
         BRA   ]LOOP

:WRT     MOVD  TEMP;RWCOUNT
         DOS   write      ;Write to dest
         BCS   :BBERR
         BIT   FLAG
         BMI   :DONE
         BRL   :NEXT      ;Loop if not last block

:DONE    DOS   getmark
         DOS   seteof
         JSR   CLOSE      ;Close up both files
         LDY   #INFEND-OURINF-5
:MVP     LDA   OURINF,Y   ;Set up info from 1st file
         STA   INFPARMS,Y
         DEY
         BNE   :MVP
SETINFO  LDA   #7
         STA   INFPARMS
         DOS   setinfo    ;Write it to 2nd
         RTS              ;Back to user

CLOSE    PHA              ;Remember error code
         LDA   SRCREF
         STA   CFREFNUM
         DOS   close      ;Close 1st file
         LDA   DESTREF
         BEQ   :PULL      ;Branch if file 2 not open
         STA   CFREFNUM
         DOS   close      ;Close file 2
:PULL    PLA              ;Retrieve error code
         RTS
