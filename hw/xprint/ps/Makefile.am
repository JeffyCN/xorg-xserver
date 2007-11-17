noinst_LTLIBRARIES = libps.la

INCLUDES = -I$(top_srcdir)/hw/xprint

AM_CFLAGS = @DIX_CFLAGS@ @XPRINT_CFLAGS@ @FREETYPE_CFLAGS@ \
	    -D_XP_PRINT_SERVER_ -DXP_PSTEXT

libps_la_SOURCES =		\
	PsArc.c			\
	PsArea.c		\
	PsAttr.c		\
	PsAttVal.c		\
	PsCache.c		\
	PsColor.c		\
	PsDef.h			\
	PsFonts.c		\
	PsGC.c			\
	Ps.h			\
	PsImageUtil.c		\
	PsInit.c		\
	PsLine.c		\
	PsMisc.c		\
	psout.c			\
	psout.h			\
	PsPixel.c		\
	PsPixmap.c		\
	PsPolygon.c		\
	PsPrint.c		\
	PsSpans.c		\
	PsText.c		\
	PsWindow.c

FREETYPE_SRCS = PsFTFonts.c	\
	psout_ft.c		\
	psout_ftpstype1.c	\
	psout_ftpstype3.c	

EXTRA_DIST = ttf2pt1wrap.c

if XP_USE_FREETYPE
    TTF2PT1OURCEDIR = $(top_srcdir)/hw/xprint/extras/ttf2pt1
    TTF2PT1SRCFILE = ttf2pt1.c
    TTF2PT1OBJFILE = ttf2pt1.o
    TTF2PT1SRCS_EXTRA = pt1.h t1asm.c ttf.h global.h version.h
    TTF2PT1SRCS = ft.c pt1.c runt1asm.c $(TTF2PT1SRCFILE)
    TTF2PT1OBJS = ft.o pt1.o runt1asm.o $(TTF2PT1OBJFILE)
    
    AM_CFLAGS += -DXP_USE_FREETYPE -DUSE_FREETYPE -DXP_ONLY_BLOCKS

$(TTF2PT1SRCS_EXTRA):
	-rm -f $@
	$(LN_S) $(TTF2PT1OURCEDIR)/$@

$(TTF2PT1SRCS):  $(TTF2PT1SRCS_EXTRA)
	-rm -f $@
	$(LN_S) $(TTF2PT1OURCEDIR)/$@

    libps_la_SOURCES += $(FREETYPE_SRCS) $(TTF2PT1SRCS)
endif
