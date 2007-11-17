SUBDIRS = attributes ddx-config models

xpcdir = @xpconfigdir@/C/print


Xprinters.ghostscript: $(srcdir)/Xprinters
	sed < $(srcdir)/Xprinters "s/#Printer xp_pdf_spooldir_HOME_Xprintjobs/Printer xp_pdf_spooldir_HOME_Xprintjobs/" > Xprinters.ghostscript



dist_xpc_DATA = Xprinters
xpc_DATA = Xprinters.ghostscript

CLEANFILES = Xprinters.ghostscript
