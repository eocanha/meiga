NULL = 

AM_CPPFLAGS = \
	$(gthread_CFLAGS) \
	$(glib_CFLAGS) \
	$(gobject_CFLAGS) \
	$(gupnp_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

bin_PROGRAMS = fwupnp
bin_SCRIPTS = fwlocalip fwssh fwssh-task meiga-askpass fwfon

fwupnp_SOURCES = \
	upnp.c \
	fwupnp.c \
	$(NULL)

fwupnp_LDADD = \
	$(gthread_LIBS) \
	$(glib_LIBS) \
	$(gobject_LIBS) \
	$(gupnp_LIBS) \
	$(NULL)

DISTCLEANFILES = \
	$(NULL)

