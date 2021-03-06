 


*			Labyrinthe en 3D avec des textures mapp�es
*			~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*				(c)1994 Sync/DreamDealers


* NOTE: 3x3
*



*********************************************************************************
*                         Les options de compilation                            *
*********************************************************************************
	OPT P=68020
	OPT O+,OW-,OW1+,OW6+
	OPT NODEBUG,NOLINE,NOHCLN
;;	OPT DEBUG,HCLN


*********************************************************************************
*                                Les includes                                   *
*********************************************************************************
	incdir "asm:sources/"
	incdir "Textures/"
	incdir "asm:songs/small"
	include "Registers.i"



LOAD_TEXTURE macro
	incbin "\1.PAL"
	incbin "\1.CHK"
	endm


*********************************************************************************
*                                   Les EQUs                                    *
*********************************************************************************
DATA_OFFSET=$7ffe

NB_COLONNES=96
NB_LIGNES=60
NB_ZOOM=NB_LIGNES+200
COP_SKIP=33*4
COP_SIZE_X=(NB_COLONNES+4+1+1)*4
COP_SIZE=COP_SKIP+COP_SIZE_X*NB_LIGNES+4

PIXEL_SIZE_X=3
PIXEL_SIZE_Y=3
SCREEN_X=256
SCREEN_Y=NB_LIGNES*PIXEL_SIZE_Y
SCREEN_DEPTH=7
SCREEN_WIDTH=(SCREEN_X+7)/8

TEXTURE_X=80
TEXTURE_Y=64
NB_TEXTURES=5

LABY_X=40
LABY_Y=39

WALL_SHIFT=5
WALL_SIZE=1<<WALL_SHIFT
BAK_SIZE=9
BEGIN_WALL=WALL_SIZE*(BAK_SIZE-1)/2+WALL_SIZE/2

SRC_REG=0
DEST_REG=1
TEMP_REG=0

SHIFT=7
ZOOM=24
MOVE_AREA=7
MAX_ANGLE=360
MAX_MOVE_SPEED=$7fff
MAX_ROTATE_SPEED=12

	rsreset
Rotate_struct	rs.b 0
CaseOffset	rs.w 1
Coord_X1	rs.w 1
Coord_Y1	rs.w 1
Coord_X2	rs.w 1
Coord_Y2	rs.w 1
Rotate_SIZEOF	rs.b 0






*********************************************************************************
*                          Point d'entr�e de la demo !                          *
*********************************************************************************
	section zoom,code

	lea _DataBase,a5			on precalcule tout �a !
	bsr Global_Init
	bsr Build_Screen
	bsr Build_Coplists
	bsr Build_Org_Coplist
	bsr Build_Textures
	bsr Build_Laby_Texture
	bsr Build_Zoom_Table
	bsr Build_Table_Screen_Offset
	bsr Build_Table_Rotate


	KILL_SYSTEM do_Zoom,0
	moveq #0,d0
	rts

do_Zoom
	jsr mt_init

	lea _DataBase,a5
	lea _CustomBase,a6

	movec cacr,d0
	move.l d0,Old_Cache(a5)
	move.l #$3111,d0			Write Allocate + Burst + Caches On
	movec d0,cacr

	move.l #Tmap_VBL,$6c.w

	move.w #$83c0,dmacon(a6)		set | pri | master | bpl | copper | blitter
	move.w #$c020,intena(a6)

Main_Loop
	bsr.s Flip_Coplists
	bsr.s Clear_log_coplist
	bsr Gestion_Joystick
	bsr Display_Walls

	btst #6,ciaapra
	bne.s Main_Loop

	jsr mt_end

	move.l Old_Cache(a5),d0
	movec d0,cacr
	RESTORE_SYSTEM





*********************************************************************************
*			Juste une petite VBL pour la muzik			*
*********************************************************************************
Tmap_VBL
	SAVE_REGS
	jsr mt_music
	move.w #$0020,_CustomBase+intreq
	clr.b _DataBase+Flip_Flag

	RESTORE_REGS
	rte




*********************************************************************************
*                           Permutation des coplists                            *
*   -->	a5=_DataBase                                                            *
*	a6=_Custom                                                              *
*********************************************************************************
Flip_Coplists
	st Flip_Flag(a5)

	movem.l Log_Coplist(a5),d0-d5
	exg d0,d1				�change des coplists
	exg d1,d2

	exg d3,d4
	exg d4,d5				�change des Table_Screen_Offset
	movem.l d0-d5,Log_Coplist(a5)

	move.l d2,cop1lc(a6)			init la nouvelle coplist

.wait	tst.b Flip_Flag(a5)			attend la syncho
	bne.s .wait
	clr.w copjmp1(a6)
	rts



*********************************************************************************
*                        Effacage de la coplist logique                         *
*   -->	a5=_DataBase                                                            *
*	a6=_Custom                                                              *
*********************************************************************************
Clear_log_coplist
	move.l Tmp_Coplist(a5),a0
	lea COP_SKIP+2(a0),a0

	WAIT_BLITTER
	move.l #org_coplist,bltapt(a6)
	move.l a0,bltdpt(a6)
	move.l #$09f00000,bltcon0(a6)
	move.l #$00000002,bltamod(a6)		bltamod=0 ; bltdmod=2
	moveq #-1,d0
	move.l d0,bltafwm(a6)
	move.l #((COP_SIZE_X/4)*NB_LIGNES<<16)|(1),bltsizV(a6)
	rts



*********************************************************************************
*				Gestion du joystick				*
*   -->	a5=_DataBase								*
*********************************************************************************
Gestion_Joystick
	bsr Check_JoyMove

	bsr check_angle

	move.w Angle(a5),d0			projette la vitesse sur les
	move.w Speed(a5),d1			axe
	move.w d1,d2
	lea Table_Sinus(pc),a0

	muls.w (a0,d0.w*2),d1			Sin(Angle)
	add.l d1,d1
	swap d1
	ext.l d1				vitesse sur les X
	add.l d1,d1
	add.l d1,d1
	add.l d1,d1

	muls.w (90*2,a0,d0.w*2),d2		Cos(Angle)
	add.l d2,d2
	swap d2
	ext.l d2				vitesse sur les Y
	add.l d2,d2
	add.l d2,d2
	add.l d2,d2

	add.l d1,PosX(a5)
	sub.l d2,PosY(a5)


	movem.l PosX-2(a5),d0/d1		on recherche o� on est dans le labyrinthe
	move.w d0,d2
	move.w d1,d3
	lsr.w #WALL_SHIFT,d2
	lsr.w #WALL_SHIFT,d3
	mulu.w #LABY_X,d3
	add.w d3,d2
	lea Packed_Laby(pc),a0
	lea (a0,d2.w*2),a0			on doit etre ici!

	and.w #WALL_SIZE-1,d0
	and.w #WALL_SIZE-1,d1
	moveq #0,d2				limite Nord
	moveq #WALL_SIZE-1,d3			limite Est
	moveq #WALL_SIZE-1,d4			limite Sud
	moveq #0,d5				limite Ouest

	tst.w -LABY_X*2(a0)
	beq.s .no_Nord
	moveq #(WALL_SIZE-MOVE_AREA)/2,d2
.no_Nord
	tst.w 2(a0)
	beq.s .no_Est
	moveq #(WALL_SIZE+MOVE_AREA)/2,d3
.no_Est
	tst.w LABY_X*2(a0)
	beq.s .no_Sud
	moveq #(WALL_SIZE+MOVE_AREA)/2,d4
.no_Sud
	tst.w -2(a0)
	beq.s .no_Ouest
	moveq #(WALL_SIZE-MOVE_AREA)/2,d5
.no_Ouest

	IFNE 0
.Check_Ouest
	cmp.w #(WALL_SIZE-MOVE_AREA)/2,d0
	bge.s .Check_Est

.Check_Nord_Ouest
	cmp.w #(WALL_SIZE-MOVE_AREA)/2,d1
	bge.s .Check_Sud_Ouest
	tst.w -LABY_X*2-2(a0)
	beq.s .Clip_Test
	moveq #(WALL_SIZE-MOVE_AREA)/2,d1
	moveq #(WALL_SIZE-MOVE_AREA)/2,d5
	bra.s .Clip_Test

.Check_Sud_Ouest
	cmp.w #(WALL_SIZE+MOVE_AREA)/2,d1
	ble.s .Clip_Test
	tst.w LABY_X*2-2(a0)
	beq.s .Clip_Test
	moveq #(WALL_SIZE+MOVE_AREA)/2,d4
	moveq #(WALL_SIZE-MOVE_AREA)/2,d5
	bra.s .Clip_Test

.Check_Est
	cmp.w #(WALL_SIZE+MOVE_AREA)/2,d0
	ble.s .Clip_Test

.Check_Nord_Est
	cmp.w #(WALL_SIZE-MOVE_AREA)/2,d1
	bge.s .Check_Sud_Est
	tst.w -LABY_X*2+2(a0)
	beq.s .Clip_Test
	moveq #(WALL_SIZE-MOVE_AREA)/2,d1
	moveq #(WALL_SIZE+MOVE_AREA)/2,d2
	bra.s .Clip_Test

.Check_Sud_Est
	cmp.w #(WALL_SIZE+MOVE_AREA)/2,d1
	ble.s .Clip_Test
	tst.w LABY_X*2+2(a0)
	beq.s .Clip_Test
	moveq #(WALL_SIZE+MOVE_AREA)/2,d4
	moveq #(WALL_SIZE+MOVE_AREA)/2,d2
	ENDC

.Clip_Test
	cmp.w d2,d1
	bge.s .ok_Nord
	move.w d2,d1
.ok_Nord
	cmp.w d3,d0
	ble.s .ok_Est
	move.w d3,d0
.ok_Est
	cmp.w d4,d1
	ble.s .ok_Sud
	move.w d4,d1
.ok_Sud
	cmp.w d5,d0
	bge.s .ok_Ouest
	move.w d5,d0
.ok_Ouest
	movem.l PosX-2(a5),d2/d3
	and.w #WALL_SIZE-1,d2
	and.w #WALL_SIZE-1,d3
	sub.w d0,d2
	sub.w d2,PosX(a5)
	sub.w d1,d3
	sub.w d3,PosY(a5)
	rts




Check_JoyMove
	move.w joy1dat(a6),d0
	ror.b #2,d0
	lsr.w #4,d0
	and.w #%111100,d0
	jmp JoyRout(pc,d0.w)
JoyRout
	bra.w move_none
	bra.w move_down
	bra.w move_down_left
	bra.w move_right
	bra.w move_up
	bra.w move_none
	bra.w move_none
	bra.w move_up_right
	bra.w move_up_left
	bra.w move_none
	bra.w move_none
	bra.w move_none
	bra.w move_left
	bra.w move_down_right
	bra.w move_none
	bra.w move_none

move_none
	bsr.s decrize_angle
	bra.s decrize_speed

decrize_angle
	moveq #1,d0
	tst.w Angle_Speed(a5)
	beq.s .no_decrize_angle
	bpl.s .do
	neg.w d0
.do
	sub.w d0,Angle_Speed(a5)
.no_decrize_angle
	move.w Angle_Speed(a5),d0
	asr.w #2,d0
	add.w d0,Angle(a5)
move_exit
	rts

decrize_speed
	move.w #1200,d0
	tst.w Speed(a5)
	beq.s .no_decrize_speed
	bpl.s .do_pl
.do_mi
	add.w #1200,Speed(a5)
	ble.s .no_decrize_speed
	clr.w Speed(a5)
	rts
.do_pl
	sub.w #1200,Speed(a5)
	bge.s .no_decrize_speed
	clr.w Speed(a5)
.no_decrize_speed
	rts

check_angle
	tst.w Angle(a5)				fait gaffe � l'angle de vision
	bge.s .ok1
	add.w #MAX_ANGLE,Angle(a5)
	bra.s .ok2
.ok1	cmp.w #MAX_ANGLE,Angle(a5)
	blt.s .ok2
	sub.w #MAX_ANGLE,Angle(a5)
.ok2
	rts

move_up
	bsr.s decrize_angle
move_up2
	add.w #8000,Speed(a5)
	cmp.w #MAX_MOVE_SPEED,Speed(a5)
	bls.s move_exit
	move.w #MAX_MOVE_SPEED,Speed(a5)
	rts

move_down
	bsr.s decrize_angle
move_down2
	sub.w #8000,Speed(a5)
	cmp.w #-MAX_MOVE_SPEED,Speed(a5)
	bhi.s move_exit
	move.w #-MAX_MOVE_SPEED,Speed(a5)
	rts

move_left
	bsr.s decrize_speed
move_left2
	subq.w #2,Angle_Speed(a5)
	cmp.w #-MAX_ROTATE_SPEED,Angle_Speed(a5)
	bge.s .set_angle
	move.w #-MAX_ROTATE_SPEED,Angle_Speed(a5)
.set_angle
	move.w Angle_Speed(a5),d0
	asr.w #2,d0
	add.w d0,Angle(a5)
	rts

move_right
	bsr decrize_speed
move_right2
	addq.w #2,Angle_Speed(a5)
	cmp.w #MAX_ROTATE_SPEED,Angle_Speed(a5)
	ble.s .set_angle
	move.w #MAX_ROTATE_SPEED,Angle_Speed(a5)
.set_angle
	move.w Angle_Speed(a5),d0
	asr.w #2,d0
	add.w d0,Angle(a5)
	rts

move_up_left
	bsr.s move_up2
	bra.s move_left2

move_up_right
	bsr.s move_up2
	bra.s move_right2

move_down_left
	bsr.s move_down2
	bra.s move_left2

move_down_right
	bsr.s move_down2
	bra.s move_right2



*********************************************************************************
*                              Affichage des murs                               *
*   -->	a5=_DataBase                                                            *
*	a6=_Custom                                                              *
*********************************************************************************
Display_Walls
	movem.l a5/a6,-(sp)

	movem.l PosX-2(a5),d2/d4		d�calage par rapport au milieu d'une dalle
	and.w #WALL_SIZE-1,d2			garde que les bits sur une dalle
	and.w #WALL_SIZE-1,d4
	sub.w #WALL_SIZE/2,d2			recentrage sur la dalle
	sub.w #WALL_SIZE/2,d4

	lea Table_Sinus(pc),a0
	move.w Angle(a5),d3
	move.w (90*2,a0,d3.w*2),d0		Cos(Angle)
	move.w (a0,d3.w*2),d1			Sin(Angle)

	neg.w d4
	move.w d2,d3				sauve X et Y...
	move.w d4,d5

	muls.w d0,d2				X*Cos(TETA)
	muls.w d1,d4				Y*Sin(TETA)
	sub.l d4,d2				NX=X*Cos(TETA)-Y*Sin(TETA)
	add.l d2,d2
	swap d2
	ext.l d2

	muls.w d1,d3				X*Sin(TETA)
	muls.w d0,d5				Y*Cos(TETA)
	add.l d5,d3				NY=X*Sin(TETA)+Y*Cos(TETA)
	add.l d3,d3
	swap d3
	IFNE ZOOM
	sub.w #ZOOM,d3
	ENDC

* d2=NX et d3=NY+ZOOM  :  offset � rajouter aux murs

	move.w Angle(a5),d0			recherche la table de rotation
	move.l (Table_Rotate_Offset.l,a5,d0.w*4),a2

	clr.l -(sp)
	move.w (a2)+,2(sp)			Nb de murs dans la table

	move.l Log_Table_Screen_Offset(a5),a3
	lea Table_Zoom_Offset(a5),a4

	movem.l PosX-2(a5),d4/d5		on recherche o� on est dans le labyrinthe
	lsr.w #WALL_SHIFT,d4
	lsr.w #WALL_SHIFT,d5
	subq.w #(BAK_SIZE-1)/2,d4
	subq.w #(BAK_SIZE-1)/2,d5
	mulu.w #LABY_X,d5
	add.w d5,d4
	lsl.w #4,d4				mulu.w #4*4,d4   4 murs par case / table de LONG
	move.l Laby_Texture(a5),a5
	lea (a5,d4.w),a5			on doit etre ici!

loop_display_walls
	move.w (a2)+,d4				lit l'offset de la case
	move.l (a5,d4.w),d4			euh.. ya un mur au fait ici ?
	beq no_wall
	move.l d4,a6				houba! c'est le pointeur sur la texture !

	movem.w (a2)+,d4/d6
	sub.l d2,d4
	asl.l #SHIFT,d4
	move.l #24<<SHIFT,d5
	sub.w d3,d6
	blt wall_not_visible_divs
	beq.s .no_divs1
	divs d6,d4				d4=X1
	divs d6,d5				d5=Y1
.no_divs1

	movem.w (a2)+,d6/d7
	sub.l d2,d6
	asl.l #SHIFT,d6
	move.l #24<<SHIFT,d0
	sub.w d3,d7
	blt wall_not_visible
	beq.s .no_divs2
	divs d7,d6				d6=X2
	divs d7,d0				d0=Y2
.no_divs2

	sub.w d4,d6				d6=DeltaX
	ble.s wall_not_visible
	sub.w d5,d0				d0=DeltaY

	add.w #1+NB_COLONNES/2,d4		recentrage sur l'�cran

	ext.l d6

	move.l #TEXTURE_X<<16,d7
	divu.l d6,d7				d7=IncX sur la texture

	swap d0
	clr.w d0
	divs.l d6,d0
	exg d0,d6				d6=IncY sur l'�cran   d0=DeltaX

	swap d5					c'est le Y de d�part
	clr.w d5

	moveq #0,d1				position X dans la texture

	tst.w d4				X1>=0 ?
	bge.s .test_X1_lt
	add.w d4,d0				X1+DeltaX>=0 ?
	ble.s wall_finish			si n�gatif on se casse !
	sub.w d4,d0
.loop_X1_ge
	add.l d6,d5				passe � un autre Y
	add.l d7,d1				colonne suivante dans la texture
	subq.w #1,d0
	addq.w #1,d4				colonne suivante sur l'�cran
	blt.s .loop_X1_ge
	bra.s .test_X1_lt
.loop_X1_lt
	swap d1
	lea (a6,d1.w*2),a0			c'est la colonne � zoomer de la texture
	swap d1
	move.l (a3,d4.w*4),a1			on �crit dans cette colonne de la coplist
	tst.w (a1)				d�ja remplie cette colonne ?
	bne.s .already_done

	swap d5
	cmp.w #NB_ZOOM,d5			ouia.. zoom limit� en hauteur ! FUCK PRECALC !!
	bge.s .no_zoom
	move.l d0,-(sp)
	jsr (a4,d5.w*8)				zoom moi ca gamin !
	move.l (sp)+,d0
.no_zoom
	swap d5
.already_done

	add.l d6,d5
	add.l d7,d1
	addq.w #1,d4
.test_X1_lt
	cmp.w #NB_COLONNES,d4
	dbge d0,.loop_X1_lt
	
wall_finish
	subq.l #1,(sp)
	bne loop_display_walls
	addq.l #4,sp				bouffe le compteur
	movem.l (sp)+,a5/a6
	rts

no_wall
	addq.l #Rotate_SIZEOF-Coord_X1,a2	ya po mur...
wall_not_visible
	subq.l #1,(sp)
	bne loop_display_walls
	addq.l #4,sp				bouffe le compteur
	movem.l (sp)+,a5/a6
	rts

wall_not_visible_divs
	addq.l #4,a2
	bra.s wall_not_visible












*********************************************************************************
*                       Initialisation globale des datas                        *
*   -->	a5=_DataBase                                                            *
*********************************************************************************
Global_Init
	move.w #WALL_SIZE*16+WALL_SIZE/2,PosX(a5)
	move.w #WALL_SIZE*15+WALL_SIZE/2,PosY(a5)
	clr.w Angle(a5)
	clr.w Angle_Speed(a5)
	clr.w Speed(a5)
	rts



*********************************************************************************
*                      Fabrication de l'�cran pour le zoom                      *
*   -->	a5=_DataBase                                                            *
*********************************************************************************
Build_Screen
	move.l #Screen_space,a0
	move.l a0,Screen(a5)

* efface d�ja le buffer
* ~~~~~~~~~~~~~~~~~~~~~
	move.l a0,a1
	moveq #(SCREEN_WIDTH/4)-1,d0
.clear
	clr.l (a1)+
	dbf d0,.clear

* construction de 2 lignes du motif
* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Build_Motif
	moveq #1,d0

* Fabrication d'une ligne du motif
* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*   -->	d0=Couleur de d�part
*	a0=Ecran
* <--	a0=Ecran
Build_Motif_Lines
	moveq #0,d1				PosX
Build_Motif_One_Line
	move.w d1,d2
	lsr.w #3,d2				pointe des octets
	move.w d1,d3
	not.w d3				# du bit � modifier

	moveq #SCREEN_DEPTH-1,d4		on se fait tous les bitplans
	move.w d0,d5
put_pixel
	lsr.w #1,d5				sort un bit de la couleur
	bcc.s .clear				c'est quoi ?
.set	bset d3,(a0,d2.w)			met le bit
.branch
	add.w #SCREEN_WIDTH,d2			ligne suivante
	dbf d4,put_pixel

	moveq #0,d2				incr�mente la position
	move.w d1,d2				du point
	addq.w #1,d1
	divu #PIXEL_SIZE_X,d2
	swap d2
	tst.w d2
	bne.s .skip

	addq.w #1,d0				couleur suivante

.skip	cmp.w #SCREEN_X,d1
	bne.s Build_Motif_One_Line
	rts
.clear	bclr d3,(a0,d2.w)			efface le bit
	bra.s .branch



*********************************************************************************
*                       Contruction des coplists de la demo                     *
*   -->	a5=_DataBase                                                            *
*********************************************************************************
Build_Coplists
	lea Coplist_space,a0
	move.l a0,Log_Coplist(a5)
	bsr.s Build_One_Coplist
	move.l a0,Tmp_Coplist(a5)
	bsr.s Build_One_Coplist
	move.l a0,Phy_Coplist(a5)
Build_One_Coplist
	move.l #(fmode<<16)|(%11),(a0)+
	move.l #(bplcon0<<16)|($7201),(a0)+	pas de ECSENA
	move.l #(bplcon1<<16),(a0)+
	move.l #(bplcon2<<16),(a0)+
	move.l #(bplcon4<<16),(a0)+
	move.l #(ddfstrt<<16)|($38),(a0)+
	move.l #(ddfstop<<16)|($80),(a0)+
	move.l #(diwstrt<<16)|($4f80),(a0)+
;; BUG !!! devrait etre $0340... une ligne qu'est pas trac�e !!!
	move.l #(diwstop<<16)|($0080),(a0)+
	move.l #(bpl1mod<<16)|((-SCREEN_WIDTH)&$ffff),(a0)+
	move.l #(bpl2mod<<16)|((-SCREEN_WIDTH)&$ffff),(a0)+
	move.l #(bplcon3<<16)|($0020),(a0)+
	move.l #(color00<<16)|$000,(a0)+
	move.l #(bplcon3<<16)|($8020),(a0)+
	move.l #(color00<<16)|$000,(a0)+
	move.l #(bplcon3<<16)|($0220),(a0)+
	move.l #(color00<<16)|$000,(a0)+
	move.l #(bplcon3<<16)|($8220),(a0)+
	move.l #(color00<<16)|$000,(a0)+

	moveq #SCREEN_DEPTH-1,d0		met en place les ptrs videos
	move.w #bpl1ptH,d1
	move.l Screen(a5),d2
Build_BplPtr
	move.w d1,(a0)+				bplxptH
	swap d2
	move.w d2,(a0)+
	addq.w #2,d1
	move.w d1,(a0)+				bplxptL
	swap d2
	move.w d2,(a0)+
	addq.w #2,d1
	add.l #SCREEN_WIDTH,d2
	dbf d0,Build_BplPtr

** on arrive � la partie suivante par un COP_SKIP sur un pointeur coplist
	moveq #NB_LIGNES/2-1,d6
	move.l #($4edffffe),d5
Build_All
	move.l #(bplcon3<<16)|($0020),d7	commence � la palette 0
	bsr.s Build_Line
	move.l d5,(a0)+				met le wait
	add.l #PIXEL_SIZE_Y<<24,d5
	move.l #(bplcon4<<16),(a0)+		utilise les palettes 0-3

	move.l #(bplcon3<<16)|($8020),d7	commence � la palette 8
	bsr.s Build_Line
	move.l d5,(a0)+				met le wait
	add.l #PIXEL_SIZE_Y<<24,d5
	move.l #(bplcon4<<16)|($8000),(a0)+	utilise les palettes 4-7
	dbf d6,Build_All

	move.l #$fffffffe,(a0)+
	rts

Build_Line
	move.l d7,(a0)+				construit la palette 0 / 4
	moveq #31-1,d0				couleurs de 1 � 31
	move.l #color01<<16,d1
Build_Colors0	
	move.l d1,(a0)+
	add.l #2<<16,d1
	dbf d0,Build_Colors0

	add.w #$2000,d7				construit la palette 1 / 5
	move.l d7,(a0)+				couleurs de 0 � 32
	moveq #32-1,d0
	move.l #color00<<16,d1
Build_Colors1
	move.l d1,(a0)+
	add.l #2<<16,d1
	dbf d0,Build_Colors1

	add.w #$2000,d7				construit la palette 2 / 6
	move.l d7,(a0)+				couleurs de 0 � 32
	moveq #32-1,d0
	move.l #color00<<16,d1
Build_Colors2
	move.l d1,(a0)+
	add.l #2<<16,d1
	dbf d0,Build_Colors2

	add.w #$2000,d7				construit la palette 3 / 7
	move.l d7,(a0)+				couleurs de 0 � 10
	moveq #1-1,d0
	move.l #color00<<16,d1
Build_Colors3
	move.l d1,(a0)+
	add.l #2<<16,d1
	dbf d0,Build_Colors3
	rts







*********************************************************************************
*                        Construction de la coplist vide                        *
*   -->	a5=_DataBase                                                            *
*********************************************************************************
Build_Org_Coplist
	move.l Log_Coplist(a5),a0
	lea COP_SKIP+2(a0),a0
	lea org_coplist,a1
	lea Back_Texture,a2
	lea 256*2(a2),a3
	move.w #NB_LIGNES-1,d0
	moveq #0,d2
Build_Org
	moveq #31-1,d1				sauve les couleurs
	bsr.s Transmute
	bsr.s Transmute
	bsr.s Transmute
	moveq #1-1,d1
	bsr.s Transmute

	move.w (a0),(a1)+			sauve le wait
	addq.l #4,a0
	move.w (a0),(a1)+			sauve le bplcon4
	addq.l #4,a0

	dbf d0,Build_Org
	rts

Transmute
	move.w (a0),(a1)+			sauve le move bplcon3
	addq.l #4,a0
.trans
	move.b (a3)+,d2
	move.w (a2,d2.w*2),(a1)+		sauve la couleur
	addq.l #4,a0
	dbf d1,.trans
	moveq #32-1,d1
	rts



*********************************************************************************
*	Construction des textures � partir des Chunky et des palettes		*
*   -->	a5=_DataBase								*
*********************************************************************************
Build_Textures
	lea Textures_space,a0
	move.l a0,Textures(a5)

	lea Chunky_Textures(pc),a1
	moveq #NB_TEXTURES-1,d0
	moveq #0,d1
.loop_all
	move.w #TEXTURE_X*TEXTURE_Y-1,d2
	lea 256*2(a1),a2
.loop_texture
	move.b (a2)+,d1				lit l'octet chunky
	move.w (a1,d1.w*2),(a0)+		convertit en couleur WORD  $xyz
	dbf d2,.loop_texture
	move.l a2,a1
	dbf d0,.loop_all
	rts
	


*********************************************************************************
*		Construction de la map du laby avec les textures		*
*   -->	a5=_DataBase								*
*********************************************************************************
Build_Laby_Texture
	lea Laby_Texture_space,a0
	move.l a0,Laby_Texture(a5)

	lea Packed_Laby(pc),a1
	move.l Textures(a5),a2

	moveq #LABY_Y-1,d0
.loop_Y
	moveq #LABY_X-1,d1
.loop_X
	moveq #4-1,d2
	move.w (a1)+,d3				lit le contenu d'une case
.loop_case
	move.w d3,d4				convertit le numero de la texture en un
	and.w #$f,d4				pointeur
	beq.s .no_texture
	subq.w #1,d4
	mulu.w #TEXTURE_X*TEXTURE_Y*2,d4
	lea (a2,d4.l),a3
	move.l a3,(a0)+
	lsr.w #4,d3
	dbf d2,.loop_case
	dbf d1,.loop_X
	dbf d0,.loop_Y
	rts
.no_texture
	clr.l (a0)+
	lsr.w #4,d3
	dbf d2,.loop_case
	dbf d1,.loop_X
	dbf d0,.loop_Y
	rts



*********************************************************************************
*                        Construction de la table de ZOOM                       *
*   -->	a5=_DataBase                                                            *
*********************************************************************************
Build_Zoom_Table
	lea Table_Zoom_Offset(a5),a0
	lea Table_Zoom(a5),a1

	moveq #1,d0
.For_H
	move.w #NB_LIGNES,d1
	sub.w d0,d1
	asr.w #1,d1

	moveq #0,d2
	tst.w d1
	bge.s .ok_abs
	move.w d1,d2
	neg.w d2
.ok_abs
	mulu.w #TEXTURE_Y,d2
	divu d0,d2

	moveq #0,d3

	move.l a1,d4
	sub.l a0,d4
	subq.l #2,d4
	move.w #$60ff,(a0)+			bra.l ???
	move.l d4,(a0)+				bra.l patator
	addq.l #2,a0				multiple de 8 !!!

	moveq #0,d4
.For_A
	tst.w d1
	blt.s .out_of_screen
	cmp.w #NB_LIGNES,d1
	bge.s .out_of_screen

	move.w d2,d5
	move.w #TEXTURE_Y,d2
	mulu.w d4,d2
	divu d0,d2

	cmp.w d2,d5
	bne.s .not_equal
.equal
	addq.w #1,d3
	bra.s .out_of_screen
.not_equal
	bsr.s Generate_Code
	moveq #1,d3
.out_of_screen
	addq.w #1,d1
	addq.w #1,d4
	cmp.w d0,d4
	ble.s .For_A

	cmp.w d2,d5
	bne.s .no_more_generate
	move.w #NB_LIGNES-1,d1
	bsr.s Generate_Code
.no_more_generate
	move.w #$4e75,(a1)+
	addq.w #1,d0
	cmp.w #NB_ZOOM,d0
	ble.s .For_H
	rts

Generate_Code
	cmp.w #1,d3
	bne.s generate_several
generate_single
	move.w #$3000|SRC_REG|(DEST_REG<<9)|$28|$140,d6
	tst.w d5
	bne.s .no_opt1
	and.w #~$28,d6
	or.w #$10,d6
.no_opt1
	cmp.w #1+(NB_LIGNES/2),d1
	bne.s .no_opt2
	and.w #~$140,d6
	or.w #$80,d6
.no_opt2
	move.w d6,(a1)+

	tst.w d5
	beq.s .opt1
	move.w d5,d6
	mulu.w #TEXTURE_X*2,d6
	move.w d6,(a1)+
.opt1
	cmp.w #1+(NB_LIGNES/2),d1
	beq.s .opt2
	move.w d1,d6
	sub.w #1+(NB_LIGNES/2),d6
	muls.w #COP_SIZE_X,d6
	move.w d6,(a1)+
.opt2
	rts

generate_several
	move.w #$3000|SRC_REG|(TEMP_REG<<9)|$28,d6
	tst.w d5
	bne.s .no_opt1
	and.w #~$28,d6
	or.w #$10,d6
.no_opt1
	move.w d6,(a1)+

	tst.w d5
	beq.s .opt1
	move.w d5,d6
	mulu.w #TEXTURE_X*2,d6
	move.w d6,(a1)+
.opt1
	addq.w #1,d1
	sub.w d3,d1

	moveq #1,d7
.For_T
	move.w #$3000|TEMP_REG|(DEST_REG<<9)|$140,d6
	cmp.w #1+NB_LIGNES/2,d1
	bne.s .no_opt2
	and.w #~$140,d6
	or.w #$80,d6
.no_opt2
	move.w d6,(a1)+

	cmp.w #1+(NB_LIGNES/2),d1
	beq.s .opt2
	move.w d1,d6
	sub.w #1+(NB_LIGNES/2),d6
	muls.w #COP_SIZE_X,d6
	move.w d6,(a1)+
.opt2
.Next_T
	addq.w #1,d1
	addq.w #1,d7
	cmp.w d3,d7
	ble.s .For_T
	subq.w #1,d1
	rts



*********************************************************************************
*                     Construction de la Table_Screen_Offset                    *
*   -->	a5=_DataBase                                                            *
*********************************************************************************
Build_Table_Screen_Offset
	lea Table_Screen_Offset_space,a0	pour la Log_Table_Screen_Offset
	lea NB_COLONNES*4(a0),a1		pour la Phy_Table_Screen_Offset
	lea NB_COLONNES*4(a1),a2
	move.l a0,Log_Table_Screen_Offset(a5)
	move.l a1,Tmp_Table_Screen_Offset(a5)
	move.l a2,Phy_Table_Screen_Offset(a5)

	move.l Log_Coplist(a5),a4
	lea COP_SKIP+COP_SIZE_X*(NB_LIGNES/2)(a4),a4

	moveq #4+2,d0				bplcon3/move
	moveq #31-1,d1
	bsr.s Loop_Create_Table_Offset
	bsr.s Loop_Create_Table_Offset
	bsr.s Loop_Create_Table_Offset
	moveq #1-1,d1
Loop_Create_Table_Offset
	moveq #0,d2
	move.w d0,d2
	add.l a4,d2
	move.l d2,(a0)+
	add.l #COP_SIZE,d2
	move.l d2,(a1)+
	add.l #COP_SIZE,d2
	move.l d2,(a2)+

	addq.w #4,d0
	dbf d1,Loop_Create_Table_Offset
	addq.w #4,d0
	moveq #32-1,d1
	rts



*********************************************************************************
*              Fabrication de la table de rotation de la grille                 *
*   -->	a5=_DataBase								*
*********************************************************************************
Build_Table_Rotate
	lea Table_Sinus(pc),a0
	lea (Table_Rotate.l,a5),a1
	move.l a1,a4				JUSTE POUR CONNAITRE LA TAILLE DE LA TABLE...
	lea (Table_Rotate_Offset.l,a5),a2

	move.w #360-1,d7			resolution de 1� sur 360�
For_TETA
	clr.w (a1)				c'est le nombre de points dans la table
	lea 2(a1),a3				c'est l� kon stocke

	move.l a1,(a2)+				sauve l'adresse de la table

	move.w 90*2(a0),d0			choppe le   cos(TETA)*$7fff
	move.w (a0)+,d1				et le       sin(TETA)*$7fff
	


* fait le carr� en haut � gauche
* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	move.w #BEGIN_WALL,d3			Y
	moveq #0,d5
For_J_1
	move.w #-BEGIN_WALL,d2			X
	moveq #0,d4
For_I_1
	move.w d5,d6				numero de la case � roter
	mulu.w #LABY_X,d6
	add.w d4,d6
	add.w d6,d6
	add.w d6,d6

	movem.w d2-d5/d7,-(sp)			calcule de X1,Y1 et X2,Y2
	movem.w d2/d3,-(sp)

	move.w d2,d4
	move.w d3,d5
;;;	move.w d2,d2				X1=X
	sub.w #WALL_SIZE,d3			Y1=Y-WALL_SIZE
	add.w #WALL_SIZE,d4			X2=X+WALL_SIZE
	sub.w #WALL_SIZE,d5			Y2=Y-WALL_SIZE
	addq.w #2,d6				NB=SUD
	bsr Make_Wall

	movem.w (sp),d2-d5
	add.w #WALL_SIZE,d2			X1=X+WALL_SIZE
	sub.w #WALL_SIZE,d3			Y1=Y-WALL_SIZE
	add.w #WALL_SIZE,d4			X2=X+WALL_SIZE
;;;	move.w d5,d5				Y2=Y
	subq.w #1,d6				NB=EST
	bsr Make_Wall

	addq.l #4,sp
	movem.w (sp)+,d2-d5/d7
Next_I_1
	add.w #WALL_SIZE,d2			X=X+WALL_SIZE
	addq.w #1,d4
	cmp.w #(BAK_SIZE-1)/2,d4
	ble.s For_I_1

* fabrication des murs NORD
	sub.w #WALL_SIZE,d2
	subq.w #1,d4

	move.w d5,d6				numero de la case � roter
	mulu.w #LABY_X,d6
	add.w d4,d6
	add.w d6,d6
	add.w d6,d6

	movem.w d2-d5/d7,-(sp)
	move.w d2,d4
	move.w d3,d5
	sub.w #WALL_SIZE,d5
	addq.w #3,d6				NB=OUEST
	bsr Make_Wall
	movem.w (sp)+,d2-d5/d7	
	
Next_J_1
	sub.w #WALL_SIZE,d3			Y=Y-WALL_SIZE
	addq.w #1,d5
	cmp.w #(BAK_SIZE-1)/2,d5
	blt For_J_1



* fait le carr� en haut � droite
* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	move.w #BEGIN_WALL,d2			X
	moveq #BAK_SIZE-1,d4
For_I_2
	move.w #BEGIN_WALL,d3			Y
	moveq #0,d5
For_J_2
	move.w d5,d6				numero de la case � roter
	mulu.w #LABY_X,d6
	add.w d4,d6
	add.w d6,d6
	add.w d6,d6

	movem.w d2-d5/d7,-(sp)			calcule de X1,Y1 et X2,Y2
	movem.w d2/d3,-(sp)

	move.w d2,d4
	move.w d3,d5
	sub.w #WALL_SIZE,d2			X1=X-WALL_SIZE
;;;	move.w d3,d3				Y1=Y
	sub.w #WALL_SIZE,d4			X2=X-WALL_SIZE
	sub.w #WALL_SIZE,d5			Y2=Y-WALL_SIZE
	addq.w #3,d6				NB=OUEST
	bsr Make_Wall

	movem.w (sp),d2-d5
	sub.w #WALL_SIZE,d2			X1=X-WALL_SIZE
	sub.w #WALL_SIZE,d3			Y1=Y-WALL_SIZE
;;;	move.w d4,d4				X2=X
	sub.w #WALL_SIZE,d5			Y2=Y-WALL_SIZE
	subq.w #1,d6				NB=SUD
	bsr Make_Wall

	addq.l #4,sp
	movem.w (sp)+,d2-d5/d7
Next_J_2
	sub.w #WALL_SIZE,d3			Y=Y-WALL_SIZE
	addq.w #1,d5
	cmp.w #(BAK_SIZE-1)/2,d5
	ble.s For_J_2

* fabrication des murs EST
	add.w #WALL_SIZE,d3
	subq.w #1,d5

	move.w d5,d6				numero de la case � roter
	mulu.w #LABY_X,d6
	add.w d4,d6
	add.w d6,d6
	add.w d6,d6

	movem.w d2-d5/d7,-(sp)
	move.w d2,d4
	sub.w #WALL_SIZE,d4
	move.w d3,d5
;;;	addq.w #0,d6				NB=NORD
	bsr Make_Wall
	movem.w (sp)+,d2-d5/d7

Next_I_2
	sub.w #WALL_SIZE,d2			X=X-WALL_SIZE
	subq.w #1,d4
	cmp.w #(BAK_SIZE-1)/2,d4
	bgt For_I_2



* fait le carr� en bas � droite
* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	move.w #-BEGIN_WALL,d3			Y
	moveq #BAK_SIZE-1,d5
For_J_3
	move.w #BEGIN_WALL,d2			X
	moveq #BAK_SIZE-1,d4
For_I_3
	move.w d5,d6				numero de la case � roter
	mulu.w #LABY_X,d6
	add.w d4,d6
	add.w d6,d6
	add.w d6,d6

	movem.w d2-d5/d7,-(sp)			calcule de X1,Y1 et X2,Y2
	movem.w d2/d3,-(sp)

	move.w d2,d4
	move.w d3,d5
;;;	move.w d2,d2				X1=X
	add.w #WALL_SIZE,d3			Y1=Y+WALL_SIZE
	sub.w #WALL_SIZE,d4			X2=X-WALL_SIZE
	add.w #WALL_SIZE,d5			Y2=Y+WALL_SIZE
;;;	addq.w #0,d6				NB=NORD
	bsr Make_Wall

	movem.w (sp),d2-d5
	sub.w #WALL_SIZE,d2			X1=X-WALL_SIZE
	add.w #WALL_SIZE,d3			Y1=Y+WALL_SIZE
	sub.w #WALL_SIZE,d4			X2=X-WALL_SIZE
;;;	move.w d5,d5				Y2=Y
	addq.w #3,d6				NB=OUEST
	bsr Make_Wall

	addq.l #4,sp
	movem.w (sp)+,d2-d5/d7
Next_I_3
	sub.w #WALL_SIZE,d2			X=X-WALL_SIZE
	subq.w #1,d4
	cmp.w #(BAK_SIZE-1)/2,d4
	bge.s For_I_3

* fabrique les murs SUD
	add.w #WALL_SIZE,d2
	addq.w #1,d4

	move.w d5,d6				numero de la case � roter
	mulu.w #LABY_X,d6
	add.w d4,d6
	add.w d6,d6
	add.w d6,d6

	movem.w d2-d5/d7,-(sp)
	move.w d2,d4
	move.w d3,d5
	add.w #WALL_SIZE,d5
	addq.w #1,d6				NB=EST
	bsr Make_Wall
	movem.w (sp)+,d2-d5/d7

Next_J_3
	add.w #WALL_SIZE,d3			Y=Y+WALL_SIZE
	subq.w #1,d5
	cmp.w #(BAK_SIZE-1)/2,d5
	bgt For_J_3



* fait le carr� en bas � gauche
* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	move.w #-BEGIN_WALL,d2			X
	moveq #0,d4
For_I_4
	move.w #-BEGIN_WALL,d3			Y
	moveq #BAK_SIZE-1,d5
For_J_4
	move.w d5,d6				numero de la case � roter
	mulu.w #LABY_X,d6
	add.w d4,d6
	add.w d6,d6
	add.w d6,d6

	movem.w d2-d5/d7,-(sp)			calcule de X1,Y1 et X2,Y2
	movem.w d2/d3,-(sp)

	move.w d2,d4
	move.w d3,d5
	add.w #WALL_SIZE,d2			X1=X+WALL_SIZE
;;;	move.w d3,d3				Y1=Y
	add.w #WALL_SIZE,d4			X2=X+WALL_SIZE
	add.w #WALL_SIZE,d5			Y2=Y+WALL_SIZE
	addq.w #1,d6				NB=EST
	bsr Make_Wall

	movem.w (sp),d2-d5
	add.w #WALL_SIZE,d2			X1=X+WALL_SIZE
	add.w #WALL_SIZE,d3			Y1=Y+WALL_SIZE
;;;	move.w d4,d4				X2=X
	add.w #WALL_SIZE,d5			Y2=Y+WALL_SIZE
	subq.w #1,d6				NB=NORD
	bsr Make_Wall

	addq.l #4,sp
	movem.w (sp)+,d2-d5/d7
Next_J_4
	add.w #WALL_SIZE,d3			Y=Y+WALL_SIZE
	subq.w #1,d5
	cmp.w #(BAK_SIZE-1)/2,d5
	bge.s For_J_4

* fabrique les murs OUEST
	sub.w #WALL_SIZE,d3
	addq.w #1,d5

	move.w d5,d6				numero de la case � roter
	mulu.w #LABY_X,d6
	add.w d4,d6
	add.w d6,d6
	add.w d6,d6

	movem.w d2-d5/d7,-(sp)			calcule de X1,Y1 et X2,Y2
	move.w d2,d4
	add.w #WALL_SIZE,d4
	move.w d3,d5
	addq.w #2,d6				NB=SUD
	bsr Make_Wall
	movem.w (sp)+,d2-d5/d7

Next_I_4
	add.w #WALL_SIZE,d2			X=X+WALL_SIZE
	addq.w #1,d4
	cmp.w #(BAK_SIZE-1)/2,d4
	blt For_I_4



* on trie maintenant les murs qui sont dans la table
* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	movem.l d0-d7/a0-a6,-(sp)
sort_element
	move.l a1,a0				ptr sur �l�ments
	move.w (a0)+,d0				nb d'�l�ments
	subq.w #1,d0				� cause du dbf

big_loop_sort_element
	subq.w #1,d0				on trie tjs sur N+1
	blt.s end_sort
	move.w d0,d1				nb d'�l�ment � trier
	move.l a0,a1				*element
	moveq #0,d2				la marque
loop_sort_element
	move.w Coord_X1(a1),d3			barycentreX*2 du mur 1
	add.w Coord_X2(a1),d3
	move.w Coord_Y1(a1),d4			barycentreY*2 du mur 1
	add.w Coord_Y2(a1),d4
	muls.w d3,d3				X^2
	muls.w d4,d4				Y^2
	add.l d4,d3				X^2+Y^2

	lea Rotate_SIZEOF(a1),a1
loop_sort_element_second
	move.w Coord_X1(a1),d5			barycentreX*2 du mur 2
	add.w Coord_X2(a1),d5
	move.w Coord_Y1(a1),d6			barycentreY*2 du mur 2
	add.w Coord_Y2(a1),d6
	muls.w d5,d5				X^2
	muls.w d6,d6				Y^2
	add.l d6,d5				X^2+Y^2

	cmp.l d3,d5
	bge.s element_ok
swap_element
	move.w -Rotate_SIZEOF+CaseOffset(a1),d5	echange les WallNumber
	move.w CaseOffset(a1),-Rotate_SIZEOF+CaseOffset(a1)
	move.w d5,CaseOffset(a1)

	move.l -Rotate_SIZEOF+Coord_X1(a1),d5		echange les X1 et Y1
	move.l Coord_X1(a1),-Rotate_SIZEOF+Coord_X1(a1)
	move.l d5,Coord_X1(a1)

	move.l -Rotate_SIZEOF+Coord_X2(a1),d5		echange les X2 et Y2
	move.l Coord_X2(a1),-Rotate_SIZEOF+Coord_X2(a1)
	move.l d5,Coord_X2(a1)

	lea Rotate_SIZEOF(a1),a1
	addq.w #1,d2				signale le changement
	dbf d1,loop_sort_element_second
	bra.s big_loop_sort_element
element_ok
	dbf d1,loop_sort_element
	tst.w d2
	bne.s big_loop_sort_element
end_sort
	movem.l (sp)+,d0-d7/a0-a6



Next_TETA
	move.l a3,a1				table suivante
	dbf d7,For_TETA
	rts


* calcule les murs
* ~~~~~~~~~~~~~~~~
*	d0=Cos(Teta)
*	d1=Sin(Teta)
*	d2=X1
*	d3=Y1
*	d4=X2
*	d5=Y2
*	d6=# de la case
Make_Wall
	movem.w d2-d7,-(sp)

	muls.w d0,d2				X1*Cos(TETA)
	muls.w d1,d3				Y1*Sin(TETA)
	sub.l d3,d2				NX1=X1*Cos(TETA)-Y1*Sin(TETA)
	add.l d2,d2
	swap d2

	movem.w (sp)+,d3/d4
	muls.w d1,d3				X1*Sin(TETA)
	muls.w d0,d4				Y1*Cos(TETA)
	add.l d4,d3				NY1=X1*Sin(TETA)+Y1*Cos(TETA)
	add.l d3,d3
	swap d3

	movem.w (sp),d4/d5
	muls.w d0,d4				X2*Cos(TETA)
	muls.w d1,d5				Y2*Sin(TETA)
	sub.l d5,d4				NX2=X2*Cos(TETA)-Y2*Sin(TETA)
	add.l d4,d4
	swap d4

	movem.w (sp)+,d5/d6
	muls.w d1,d5				Y2*Sin(TETA)
	muls.w d0,d6				X2*Cos(TETA)
	add.l d6,d5				NY2=X2*Sin(TETA)+Y2*Cos(TETA)
	add.l d5,d5
	swap d5

	move.w (sp)+,d6				r�cup�re le num�ro de la case

	tst.w d3				si ((NY1>0) or (NY2>0)) alors c'est visible
	bgt.s .wall_visible
	tst.w d5
	ble.s .wall_unvisible
.wall_visible

	cmp.w d3,d5				cone de visiblilit� de 90 �
	bgt.s .chk2

	tst.w d2
	blt.s .chk2

.chk1
	move.w d2,d7
	bgt.s .ok1
	neg.w d7
.ok1
	sub.w #WALL_SIZE,d7
	cmp.w d3,d7
	bgt.s .wall_unvisible
	bra.s .ok
.chk2
	move.w d4,d7
	bgt.s .ok2
	neg.w d7
.ok2
	sub.w #WALL_SIZE,d7
	cmp.w d5,d7
	bgt.s .wall_unvisible

.ok
	add.w d6,d6				table de LONG
	add.w d6,d6
	move.w d6,(a3)+				sauve le # de la case
	lsr.w #2,d6

	move.w d2,(a3)+				X1
	move.w d3,(a3)+				Y1
	move.w d4,(a3)+				X2
	move.w d5,(a3)+				Y2

	addq.w #1,(a1)				et un mur en plus
.wall_unvisible
	move.w (sp)+,d7
	rts




*********************************************************************************
*			Toutes les constantes de la demo			*
*********************************************************************************
Table_Sinus
	incbin "Table_Sinus.RAW"

Packed_Laby
	incbin "Laby2.RAW"

Chunky_Textures
	LOAD_TEXTURE WindowWall
	LOAD_TEXTURE VisageNana
	LOAD_TEXTURE Hippo
	LOAD_TEXTURE PlanetWall
	LOAD_TEXTURE PtitMalins

Back_Texture
	LOAD_TEXTURE Back



*********************************************************************************
*				La replay et sa zik				*
*********************************************************************************
	even
	include "TMC_Replay.s"
	include "song.s"


	section toz,data_c
	include "samples.s"



*********************************************************************************
*                         Toutes les datas du programme                         *
*********************************************************************************
	section mes_daaaatas,bss
	rsset -DATA_OFFSET
DataBase		rs.b 0
Old_Cache		rs.l 1
Log_Coplist		rs.l 1
Tmp_Coplist		rs.l 1
Phy_Coplist		rs.l 1
Log_Table_Screen_Offset	rs.l 1
Tmp_Table_Screen_Offset	rs.l 1
Phy_Table_Screen_Offset	rs.l 1
Screen			rs.l 1
PosX			rs.l 1
PosY			rs.l 1
Speed			rs.w 1
Angle			rs.w 1
Angle_Speed		rs.w 1
Flip_Flag		rs.b 1
Pad			rs.b 1
Laby_Texture		rs.l 1
Textures		rs.l 1
Laby_Around		rs.l BAK_SIZE*BAK_SIZE
Table_Zoom_Offset	rs.l NB_ZOOM*2
Table_Zoom		rs.b 77472			cf MONAM !
Table_Rotate_Offset	rs.l 360
Table_Rotate		rs.b 235200			cf MONAM !
DataBase_SIZEOF=__RS-DataBase

_DataBase=*+DATA_OFFSET
	ds.b DataBase_SIZEOF

Table_Screen_Offset_space
	ds.l NB_COLONNES*3

Laby_Texture_space
	ds.l LABY_X*LABY_Y*4

Textures_space
	ds.w TEXTURE_X*TEXTURE_Y*NB_TEXTURES



	section ponpon,bss_c

Screen_space
	ds.b SCREEN_WIDTH*SCREEN_DEPTH
Coplist_space
	ds.b COP_SIZE*3
org_coplist
	ds.w (COP_SIZE_X/4)*NB_LIGNES




***************
* end of file *
***************
