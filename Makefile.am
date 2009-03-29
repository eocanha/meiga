NULL = 

#Build in these directories:

SUBDIRS = \
	src/server \
	src/gui \
	po \
	$(NULL)

fgtwdocdir = ${prefix}/doc/fgtw
fgtwdoc_DATA = \
	ChangeLog \
	README \
	COPYING \
	AUTHORS \
	INSTALL \
	NEWS\
	$(NULL)

EXTRA_DIST = \
	$(fgtwdoc_DATA) \
	intltool-extract.in \
	intltool-merge.in \
	intltool-update.in\
	$(NULL)

DISTCLEANFILES = \
	intltool-extract \
	intltool-merge \
	intltool-update
	po/.intltool-merge-cache \
	$(NULL)

