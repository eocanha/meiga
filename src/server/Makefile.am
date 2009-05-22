NULL = 

AM_CPPFLAGS = \
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
	Meiga.vala \
	Rss.vala \
	Net.vala \
	$(NULL)

meigaserver_SOURCES = \
	$(meigaserver_VALASOURCES:.vala=.c) \
	$(meigaserver_VALASOURCES:.vala=.h) \
	$(NULL)

meiga.vala.stamp: $(meigaserver_VALASOURCES)
	$(VALAC) -C \
	--thread --pkg=libsoup-2.4 --pkg=gtk+-2.0 --pkg=dbus-glib-1 \
	--basedir $(top_srcdir)/src/server $^
	touch $@

meigaserver_LDADD = \
	$(gthread_LIBS) \
	$(glib_LIBS) \
	$(gobject_LIBS) \
	$(gtk_LIBS) \
	$(libsoup24_LIBS) \
	$(dbusglib_LIBS) \
	$(NULL)

EXTRA_DIST = \
	$(meiga_VALASOURCES) \
	meiga.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

