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

BUILT_SOURCES = fgtw.vala.stamp

bin_PROGRAMS = fgtwserver

fgtwserver_VALASOURCES = \
	MyServer.vala \
	FromGnomeToTheWorld.vala \
	Rss.vala \
	$(NULL)

fgtwserver_SOURCES = \
	$(fgtwserver_VALASOURCES:.vala=.c) \
	$(fgtwserver_VALASOURCES:.vala=.h) \
	$(NULL)

fgtw.vala.stamp: $(fgtwserver_VALASOURCES)
	$(VALAC) -C \
	--thread --pkg=libsoup-2.4 --pkg=gtk+-2.0 --pkg=dbus-glib-1 \
	--basedir $(top_srcdir)/src/server $^
	touch $@

fgtwserver_LDADD = \
	$(gthread_LIBS) \
	$(glib_LIBS) \
	$(gobject_LIBS) \
	$(gtk_LIBS) \
	$(libsoup24_LIBS) \
	$(dbusglib_LIBS) \
	$(NULL)

EXTRA_DIST = \
	$(fgtw_VALASOURCES) \
	fgtw.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

