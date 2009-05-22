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

BUILT_SOURCES = meiga.vala.stamp

bin_PROGRAMS = meiga

meiga_VALASOURCES = \
	Gui.vala \
	$(NULL)

meiga_SOURCES = \
	$(meiga_VALASOURCES:.vala=.c) \
	$(meiga_VALASOURCES:.vala=.h) \
	$(NULL)

meiga.vala.stamp: $(meiga_VALASOURCES)
	$(VALAC) -C \
	--thread --pkg=gtk+-2.0 --pkg=libglade-2.0 --pkg=gmodule-2.0 --pkg=dbus-glib-1 \
	--vapidir=. --pkg=config --basedir $(top_srcdir)/src/gui $^
	touch $@

meiga_LDADD = \
	$(gthread_LIBS) \
	$(glib_LIBS) \
	$(gobject_LIBS) \
	$(gtk_LIBS) \
	$(dbusglib_LIBS) \
	$(libglade_LIBS) \
	$(gmodule_LIBS) \
	$(NULL)

meigaextradir = ${datadir}/meiga/glade
meigaextra_DATA = \
        glade/gui.glade \
        $(NULL)

EXTRA_DIST = \
	$(meiga_VALASOURCES) \
	$(meigaextra_DATA) \
	meiga.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

