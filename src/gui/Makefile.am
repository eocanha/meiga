NULL = 

AM_CPPFLAGS = \
	-DDATADIR=\""$(datadir)"\" \
	$(gthread_CFLAGS) \
	$(glib_CFLAGS) \
	$(gobject_CFLAGS) \
	$(gtk_CFLAGS) \
	$(dbusglib_CFLAGS) \
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
	--thread --pkg=gtk+-2.0 --pkg=gmodule-2.0 --pkg=dbus-glib-1 \
	--vapidir=. --pkg=config --basedir $(top_srcdir)/src/gui $^
	touch $@

meiga_LDADD = \
	$(gthread_LIBS) \
	$(glib_LIBS) \
	$(gobject_LIBS) \
	$(gtk_LIBS) \
	$(dbusglib_LIBS) \
	$(gmodule_LIBS) \
	$(NULL)

launcherdir = ${datadir}/applications
launcher_DATA = meiga.desktop

edit = sed -e 's,@BINDIR\@,$(bindir),g' -e 's,@PIXMAPDIR\@,$(pixmapdir),g'

meiga.desktop: Makefile meiga.desktop.in
	rm -f meiga.desktop meiga.desktop.tmp
	$(edit) meiga.desktop.in > meiga.desktop.tmp
	mv meiga.desktop.tmp meiga.desktop

meigaextradir = ${datadir}/meiga/ui
meigaextra_DATA = \
        ui/gui.ui \
	pixmaps/meiga-16x16.png \
        $(NULL)

meigapixmapsdir = ${datadir}/pixmaps
meigapixmaps_DATA = \
	pixmaps/meiga.png \
	$(NULL)

meigaicon48dir = ${datadir}/icons/hicolor/48x48/apps
meigaicon48_DATA = \
	pixmaps/meiga.png \
	$(NULL)

EXTRA_DIST = \
	$(meiga_VALASOURCES) \
	$(meigaextra_DATA) \
	$(meigapixmaps_DATA) \
	$(meigaicon48_DATA) \
	meiga.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

