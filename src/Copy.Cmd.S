******************************
*                            *
*       COPY BASIC CMD       *
*                            *
*  Glen E. Bredon   9/6/85   *
*     Original 12/16/84      *
******************************

         DATE

         REL                                      ;Generate a LNK file

SAVOBJ   KBD            "Save object (0=no, 1=yes)?"

         DO             SAVOBJ
         DSK            OBJECT/COPY.CMD
         FIN

         EXP            OFF
         TR

STREND   =              $6D                       ;Bottom of free space
FRETOP   =              $6F                       ;Top of free space
HIMEM    =              $73                       ;Bottom of system buffer
CHRGOT   =              $B7
PATHPNT1 =              $E0                       ;Source pathname ptr
PATHPNT2 =              $E2                       ;Dest " (for moving 2->1)
SRCREF   =              $E4                       ;Source ref #
DESTREF  =              $E5                       ;Dest ref #
COUNT    =              $E6                       ;# bytes in file
PAGES    =              $E9                       ;# pages done at a time
FLAG     =              PATHPNT1                  ;Final block of copy flag
IN       =              $200
COUT     =              $FDED

* ProDOS MLI call codes:

create   =              $C0
destroy  =              $C1
setinfo  =              $C3
getinfo  =              $C4
open     =              $C8
newline  =              $C9
read     =              $CA
write    =              $CB
close    =              $CC
geteof   =              $D1

* ProDOS BASIC interp locations:

XTRNADDR =              $BE50                     ;External command vector
XLEN     =              $BE52                     ;Length of cmd -1 put here
XCNUM    =              $BE53                     ;Put 0 here for ext cmd
PBITS    =              $BE54                     ;Parameters
FBITS    =              $BE56                     ;Parameter bits found
VPATH1   =              $BE6C                     ;Pointer to pathname 1
VPATH2   =              $BE6E                     ; " 2
GOSYSTEM =              $BE70                     ;Call MLI routine
XRETURN  =              $BE9E                     ;Has RTS (for dos cmd linking)
CRACESS  =              $BEA3                     ;Create access parm
CRFILID  =              $BEA4                     ;  " file type
INFPARMS =              $BEB4                     ;GETINFO parm list
FILETYPE =              $BEB8                     ;File type put here
FIFKIND  =              $BEBB                     ;Kind of file (tree/dir)
SREFNUM  =              $BEC7                     ;Ref # for geteof
SMARK    =              $BEC8                     ;File size (3 bytes)
NEWLREF  =              $BED2                     ;Newline ref #
NLINENBL =              $BED3                     ;Newline enable (0=disable)
OSYSBUF  =              $BECE                     ;Buffer ptr for OPEN
OREFNUM  =              $BED0                     ;File ref # for OPEN
RWREFNUM =              $BED6                     ;Ref # for read/write
RWDATA   =              $BED7                     ;Buffer ptr for read/write
RWCOUNT  =              $BED9                     ;# of bytes to read/write
CFREFNUM =              $BEDE                     ;Ref # for CLOSE
DATETIME =              $BF06                     ;Date jmp
SERR     =              $BF0F                     ;MLI error code
DATE     =              $BF90                     ;Date and time
MONRTS   =              $FFCB                     ;Has RTS (for & linking)

STADR    MAC
         LDA            #]1
         STA            ]2
         LDA            #>]1
         STA            ]2+1
         <<<

MOVD     MAC
         LDA            ]1
         STA            ]2
         LDA            ]1+1
         STA            ]2+1
         <<<

DOS      MAC
         LDA            #]1
         JSR            GOSYSTEM
         <<<

         DUMMY          $2E0
OURINF   DFB            10
         DA             0                         ;Pathname ptr
ACCESS   DFB            0                         ;Access
FILEID   DFB            0
         DA             0                         ;Aux type
         DFB            0                         ;Kind
         DA             0                         ;#Blocks
         DA             0                         ;Mod date
         DA             0                         ; & time
OURDATE  DA             0                         ;Create date
         DA             0                         ; & time
INFEND   DEND

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

         DFB            9                         ;Signature

PARSE    LDX            #CMDEND-CMDNAME
:ISIT    LDA            IN-1,X
         AND            #%11011111
         EOR            CMDNAME-1,X
         SEC                                      ;In case we exit here
         BNE            DOSEXIT                   ;Support daisy chain
         DEX
         BNE            :ISIT
         STX            XCNUM                     ;Signal external cmd
         STADR          DOCOPY;XTRNADDR
         LDA            #CMDEND-CMDNAME-1
         STA            XLEN                      ;Tell BASIC interp length of cmd
         LDA            #%11                      ;Two file names expected
         STA            PBITS
         STX            PBITS+1
         STX            DESTREF                   ;Flag for CLOSE
         CLC                                      ;Say we accept the cmd
         RTS

CMDNAME  ASC            "COPY"
CMDEND   ASC            " source pathname, dest pathname"8D
AMPEND

DOCOPY   LDA            FBITS
         LSR                                      ;Found file name?
         BCS            :FND                      ;Branch if so
:SYNERR  LDA            #11                       ;Syntax error
:ERROR   SEC
:MLIERR  RTS

:FND     LSR                                      ;Second name given?
         BCC            :SYNERR                   ;Error if not
         LDA            FRETOP+1
         SBC            STREND+1                  ;Get free space
         SBC            #5                        ;Subt part pg & 4 pgs for buffer
         BEQ            :TOOL                     ;Error if no pages left
         BCS            :MEMOK                    ; or if even less
:TOOL    LDA            #14                       ;Program too large
         BNE            :ERROR
:MEMOK   STA            PAGES                     ;# pages used as copy buffer
         LDA            #10                       ;# of parms for GETINFO
         STA            INFPARMS
         DOS            getinfo
         BCS            :MLIERR
         LDY            #INFEND-OURINF-1
:MP      LDA            INFPARMS,Y                ;Save info on orig file
         STA            OURINF,Y
         DEY
         BPL            :MP
         LDA            FIFKIND                   ;What kind of file?
         AND            #%11111100
         BNE            :BADTYPE                  ;Reject dir & nonstandard
         LDY            HIMEM+1                   ;Address high of system buffer
         STY            OSYSBUF+1                 ;Use system buffer for orig file
         DOS            open                      ;Open orig file
         BCS            :CLSERR                   ;Close if error
         LDA            OREFNUM
         STA            SRCREF                    ;Remember orig file's ref #
         STA            NEWLREF                   ;Set up for NEWLINE
         STA            SREFNUM                   ; and GETEOF
         DOS            geteof
         BCS            :CLSERR
         LDX            #3
]LUP     LDA            SMARK-1,X
         STA            COUNT-1,X
         DEX
         BNE            ]LUP
         STX            NLINENBL                  ;Set up to
         DOS            newline                   ; disable NEWLINE
         LDX            #2
]LUP     LDA            VPATH1-1,X
         STA            PATHPNT1-1,X
         LDA            VPATH2-1,X
         STA            PATHPNT2-1,X
         DEX
         BNE            ]LUP
         LDA            (PATHPNT2,X)
         TAY                                      ;Length of path 2
:MVN     LDA            (PATHPNT2),Y
         STA            (PATHPNT1),Y
         DEY                                      ;Now system points to pathname 2
         BPL            :MVN
         DOS            getinfo                   ;Does it exist?
         BCS            :CREATE                   ;Branch if not
         LDA            FILETYPE
         CMP            FILEID                    ;Correct type?
         BEQ            :FOK                      ;Branch if so
:BADTYPE LDA            #13                       ;Type mismatch error
:CLSERR  JSR            CLOSE                     ;Close both files
         SEC                                      ;Signal an error
         RTS
:FOK     DOS            destroy                   ;Erase file 2 that exists
         BCC            :OV
         BCS            :CLSERR
:CREATE  LDY            SERR
         CPY            #$46                      ;Path not found?
         BNE            :CLSERR                   ;Abort if not
:OV      LDX            #3
         SEI
         LDY            DATETIME                  ;Save the JMP or ?
:CRE     LDA            DATE,X                    ;Save real date
         STA            FLAG,X
         LDA            OURDATE,X                 ;Set up orig date
         STA            DATE,X                    ; for create
         LDA            FILEID,X                  ;Also filetype, aux type
         STA            CRFILID,X                 ; and storage type
         DEX
         BPL            :CRE
         LDA            #$60
         STA            DATETIME                  ;Disable date routine
         LDA            ACCESS                    ;Make sure we can do write
         ORA            #%10000011
         STA            CRACESS
         DOS            create                    ;Create file 2
         STY            DATETIME                  ;Fix date call
         PHA                                      ;Save error code
         LDX            #3                        ;(Must preserve carry)
:FD      LDA            FLAG,X                    ;Replace real date
         STA            DATE,X
         DEX
         BPL            :FD
         PLA                                      ;Error code back
         CLI
:BCLSERR BCS            :CLSERR
         LDY            STREND+1
         INY                                      ;Use 1st 4 free pages
         STY            OSYSBUF+1                 ; for file 2 buffer
         DOS            open                      ;Open file 2
         BCS            :CLSERR
         LDA            OREFNUM
         STA            DESTREF                   ;Remember ref for file 2
         LDA            #0
         STA            FLAG                      ;Flag not last block
         STA            RWCOUNT                   ;Use full pages
         STA            RWDATA                    ;Data buffer on pg bdry
         LDA            STREND+1
         ADC            #5                        ;(this one)
         STA            RWDATA+1
         LDA            PAGES                     ;# of data pages can use
         STA            RWCOUNT+1
         LDA            COUNT
         ORA            COUNT+1
         ORA            COUNT+2
         BEQ            :DONE
:NEXT    SEC
         LDA            COUNT+1
         SBC            PAGES
         TAX
         LDA            COUNT+2
         SBC            #0
         BLT            :LAST                     ;Branch if last block
         BNE            :NOTL                     ;  " if not
         CPX            #0
         BNE            :NOTL
         LDY            COUNT
         BNE            :NOTL
:LAST    MOVD           COUNT;RWCOUNT
         SEC
         ROR            FLAG                      ;Flag last block
:NOTL    STA            COUNT+2                   ;Decrease count by pages
         STX            COUNT+1
         LDA            SRCREF
         STA            RWREFNUM
         DOS            read                      ;Read from source
         BCS            :BCLSERR
         LDA            DESTREF
         STA            RWREFNUM
         DOS            write                     ;Write to dest
         BCS            :BCLSERR
         BIT            FLAG
         BPL            :NEXT                     ;Loop if not last block
:DONE    JSR            CLOSE                     ;Close up both files
         LDY            #INFEND-OURINF-5
:MVP     LDA            OURINF,Y                  ;Set up info from 1st file
         STA            INFPARMS,Y
         DEY
         BNE            :MVP
         LDA            #7
         STA            INFPARMS
         DOS            setinfo                   ;Write it to 2nd
         RTS                                      ;Back to user

CLOSE    PHA                                      ;Remember error code
         LDA            SRCREF
         STA            CFREFNUM
         DOS            close                     ;Close 1st file
         LDA            DESTREF
         BEQ            :PULL                     ;Branch if file 2 not open
         STA            CFREFNUM
         DOS            close                     ;Close file 2
:PULL    PLA                                      ;Retrieve error code
         RTS
