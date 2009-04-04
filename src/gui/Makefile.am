NULL = 

AM_CPPFLAGS = \
	-DDATADIR=\""$(datadir)"\" \
	$(gthread_CFLAGS) \
	$(glib_CFLAGS) \
	$(gobject_CFLAGS) \
	$(gtk_CFLAGS) \
	$(dbusglib_CFLAGS) \
	$(libglade_CFLAGS) \
	$(gmodule_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

BUILT_SOURCES = fgtw.vala.stamp

bin_PROGRAMS = fgtw

fgtw_VALASOURCES = \
	Gui.vala \
	$(NULL)

fgtw_SOURCES = \
	$(fgtw_VALASOURCES:.vala=.c) \
	$(fgtw_VALASOURCES:.vala=.h) \
	$(NULL)

fgtw.vala.stamp: $(fgtw_VALASOURCES)
	$(VALAC) -C \
	--thread --pkg=gtk+-2.0 --pkg=libglade-2.0 --pkg=gmodule-2.0 --pkg=dbus-glib-1 \
	--vapidir=. --pkg=config --basedir $(top_srcdir)/src/gui $^
	touch $@

fgtw_LDADD = \
	$(gthread_LIBS) \
	$(glib_LIBS) \
	$(gobject_LIBS) \
	$(gtk_LIBS) \
	$(dbusglib_LIBS) \
	$(libglade_LIBS) \
	$(gmodule_LIBS) \
	$(NULL)

fgtwextradir = ${datadir}/fgtw/glade
fgtwextra_DATA = \
        glade/gui.glade \
        $(NULL)

EXTRA_DIST = \
	$(fgtw_VALASOURCES) \
	$(fgtwextra_DATA) \
	fgtw.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)
