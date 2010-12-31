NULL = 

AM_CPPFLAGS = \
	-DDATADIR=\""$(datadir)"\" \
	-DBINDIR=\""$(bindir)"\" \
	-DGETTEXT_PACKAGE=\""$(GETTEXT_PACKAGE)"\" \
	-DLOCALEDIR=\""$(localedir)"\" \
	$(gthread_CFLAGS) \
	$(glib_CFLAGS) \
	$(gobject_CFLAGS) \
	$(gtk_CFLAGS) \
	$(libsoup24_CFLAGS) \
	$(dbusglib_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

BUILT_SOURCES = meiga.vala.stamp

bin_PROGRAMS = meigaserver

meigaserver_VALASOURCES = \
	MeigaServer.vala \
	ServerContext.vala \
	Meiga.vala \
	Rss.vala \
	Net.vala \
	Log.vala \
	$(NULL)

meigaserver_SOURCES = \
	$(meigaserver_VALASOURCES:.vala=.c) \
	$(meigaserver_VALASOURCES:.vala=.h) \
	$(NULL)

meiga.vala.stamp: $(meigaserver_VALASOURCES)
	$(VALAC) -C \
	--thread --pkg=libsoup-2.4 --pkg=gtk+-2.0 --pkg=dbus-glib-1 \
	--vapidir=. --vapidir=.. --pkg=config --basedir $(top_srcdir)/src/server $^
	touch $@

meigaserver_LDADD = \
	$(gthread_LIBS) \
	$(glib_LIBS) \
	$(gobject_LIBS) \
	$(gtk_LIBS) \
	$(libsoup24_LIBS) \
	$(dbusglib_LIBS) \
	$(NULL)

serviceentry_DATA = com.igalia.Meiga.service

edit = sed -e 's,@BINDIR\@,$(bindir),g' -e 's,@PIXMAPDIR\@,$(pixmapdir),g'

com.igalia.Meiga.service: Makefile com.igalia.Meiga.service.in
	rm -f com.igalia.Meiga.service com.igalia.Meiga.service.tmp
	$(edit) com.igalia.Meiga.service.in > com.igalia.Meiga.service.tmp
	mv com.igalia.Meiga.service.tmp com.igalia.Meiga.service

EXTRA_DIST = \
	$(meiga_VALASOURCES) \
	meiga.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

