NULL = 

#Build in these directories:

SUBDIRS = \
	src/server \
	src/gui \
	src/net \
	po \
	$(NULL)

meigadocdir = ${prefix}/doc/meiga
meigadoc_DATA = \
	ChangeLog \
	README \
	COPYING \
	AUTHORS \
	INSTALL \
	NEWS\
	$(NULL)

EXTRA_DIST = \
	$(meigadoc_DATA) \
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

