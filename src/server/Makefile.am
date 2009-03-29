NULL = 

AM_CPPFLAGS = \
	$(FGTW_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

BUILT_SOURCES = fgtw.vala.stamp

bin_PROGRAMS = fgtwserver

fgtw_VALASOURCES = \
	MyServer.vala \
	FromGnomeToTheWorld.vala \
	Rss.vala \
	$(NULL)

fgtwserver_SOURCES = \
	$(fgtw_VALASOURCES:.vala=.c) \
	$(fgtw_VALASOURCES:.vala=.h) \
	$(NULL)

fgtw.vala.stamp: $(fgtw_VALASOURCES)
	$(VALAC) -C \
	--thread --pkg=libsoup-2.4 --pkg=gtk+-2.0 --pkg=dbus-glib-1 \
	--basedir $(top_srcdir)/src/server $^
	touch $@

fgtwserver_LDADD = \
	$(FGTW_LIBS) \
	$(NULL)

EXTRA_DIST = \
	$(fgtw_VALASOURCES) \
	fgtw.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

