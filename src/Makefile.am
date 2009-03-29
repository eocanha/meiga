NULL = 

AM_CPPFLAGS = \
	$(FGTW_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

BUILT_SOURCES = fgtw.vala.stamp

bin_PROGRAMS = fgtw

fgtw_VALASOURCES = \
	mainwindow.vala \
	$(NULL)

fgtw_SOURCES = \
	$(fgtw_VALASOURCES:.vala=.c) \
	$(fgtw_VALASOURCES:.vala=.h) \
	$(NULL)

fgtw.vala.stamp: $(fgtw_VALASOURCES)
	$(VALAC) -C --pkg gtk+-2.0 --basedir $(top_srcdir)/src $^
	touch $@

fgtw_LDADD = \
	$(FGTW_LIBS) \
	$(NULL)

EXTRA_DIST = \
	$(fgtw_VALASOURCES) \
	fgtw.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

