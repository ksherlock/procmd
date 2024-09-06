


ldax	mac
	lda ]1
	if #=]1
	ldx ^]1
	else
	ldx ]1+2
	fin
	<<<
stax	mac
	sta ]1
	stx ]1+2
	<<<

plax	mac
	pla
	plx
	<<<

phxa	mac
	phx
	pha
	<<<

ph4	mac
	if #=]1
	pea ^]1
	pea ]1
	else
	lda ]1+2
	pha
	lda ]1
	pha
	fin
	<<<

ph2	mac
	if #=]1
	pea ]1
	else
	lda ]1
	pha
	fin
	<<<

phl	mac
	ph4 ]1
	<<<

Tool	mac
	tll ]1
	<<<

~DisposeHandle MAC
 PHL ]1
_DisposeHandle MAC
 Tool $1002
 <<<



LONGM	MAC
LONGACC	MAC	;Assumes native mode
	IF	MX&2	;If A is now short
	REP	%00100000
	FIN
	<<<

LONGX	MAC
LONGXY	MAC	;Assumes native mode
	IF	MX&1	;If X is now short
	REP	%00010000
	FIN
	<<<

LONG	MAC
LONGAX	MAC	;Assumes native mode
LONGMX	MAC	;Assumes native mode
	IF	MX	;If not now in full 16
	REP	%00110000
	FIN
	<<<

SHORTM	MAC
SHORTACC	MAC	;Assumes native mode
	IF	MX&2	;If A is now short,
	ELSE	; ignore
	SEP	%00100000
	FIN
	<<<

SHORTX	MAC
SHORTXY	MAC	;Assumes native mode
	IF	MX&1	;If X is now short,
	ELSE		; ignore
	SEP	%00010000
	FIN
	<<<

SHORT	MAC
SHORTAX	MAC	;Assumes native mode
SHORTMX	MAC	;Assumes native mode
	IF	MX!%11	;If not now in full 8
	SEP	%00110000
	FIN
	<<<