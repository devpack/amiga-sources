
*			Trace de droite en Chunky 256 ecran de 320*240
*			~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



SCREEN_X=320
SCREEN_Y=240



	lea Buffer,a0
	moveq #0,d0
	moveq #0,d1
	move.w #SCREEN_X-1,d2
	move.w #SCREEN_Y-1,d3
	moveq #1,d4
	bsr DrawLine
	rts


* Routine de trace de droite en Chunky 256
* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*  -->	A0=Ecran Chunky
*	D0=X1
*	D1=Y1
*	D2=X2
*	D3=Y3
*	d4.b=Color

X1 equr d0
Y1 equr d1
X2 equr d2
Y2 equr d3
DX equr d2
DY equr d3
COLOR equr d4
INCY equr d5
C equr d6
COUNT equr d7

DrawLine
	sub.w X1,X2				calcul de DX=X2-X1
	bge.s .okx
	exg X1,X2				on va toujours de gauche � droite
	exg Y1,Y2
	neg.w DX
.okx
	move.w #SCREEN_X,INCY
	sub.w Y1,Y2				calcul de DY=Y2-Y1
	bge.s .oky
	neg.w DY
	neg.w INCY
.oky
	move.w Y1,C				recherche le premier point de la droite
	mulu.w #SCREEN_X,C
	ext.l X1
	add.l X1,C
	lea (a0,C.l),a0

	cmp.w DX,DY				DX>DY ?
	bgt.s DX_lt_DY
DX_ge_DY
	add.w DY,DY				2*DY
	move.w DY,C				C=2*DY
	sub.w DX,C				C=2*DY-DX

	add.w DX,DX				2*DX

	move.w DX,COUNT
	subq.w #1,COUNT				for COUNT=1 to DX
.for_COUNT
	move.b COLOR,(a0)+
	tst.w C
	bmi.s .C_mi
.C_pl
	lea (a0,INCY.w),a0
	add.w DY,C
	sub.w DX,C
	dbf COUNT,.for_COUNT
	rts
.C_mi
	add.w DY,C
	dbf COUNT,.for_COUNT
	rts

DX_lt_DY
	add.w DX,DX				2*DX
	move.w DX,C				C=2*DX
	sub.w DY,C				C=2*DX-DY

	add.w DY,DY

	move.w DY,COUNT
	subq.w #1,COUNT				for COUNT=1 to DY
.for_COUNT
	move.b COLOR,(a0)
	lea (a0,INCY.w),a0

	tst.w C
	bmi.s .C_mi
.C_pl
	addq.l #1,a0
	add.w DX,C
	sub.w DY,C
	dbf d7,.for_COUNT
	rts
.C_mi
	add.w DX,C
	dbf d7,.for_COUNT
	rts



Buffer