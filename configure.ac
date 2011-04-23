AC_PREREQ(2.62)
AC_INIT([meiga],[0.4.1],[info@igalia.com],[meiga])

AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([dist-bzip2])
AM_MAINTAINER_MODE
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

# Checks for programs.
AC_PROG_CC
AM_PROG_CC_C_O

# Initialize libtool
LT_PREREQ([2.2.6])
LT_INIT([disable-static])

AC_PATH_PROG(VALAC, valac, valac)
AC_SUBST(VALAC)

# Checks for header files.
AC_CHECK_HEADERS([stdlib.h])

# i18n stuff
if test "x$localedir" == x
then
    localedir='${datadir}/locale'
    AC_SUBST(localedir)
    AM_GLIB_DEFINE_LOCALEDIR([localedir])
fi

# Gettext
IT_PROG_INTLTOOL([0.40.0])
AC_SUBST([GETTEXT_PACKAGE], [meiga])
AM_GNU_GETTEXT_VERSION([0.17])
AM_GLIB_GNU_GETTEXT
AC_DEFINE([GETTEXT_PACKAGE], [PACKAGE_TARNAME], [The prefix for our gettext translation domains.])

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

VALA_REQUIRED=0.8.0
GTHREAD_REQUIRED=2.16.3
GLIB_REQUIRED=2.12.0
GTK_REQUIRED=2.10.0
SOUP24_REQUIRED=2.4.0
DBUSGLIB_REQUIRED=0.74
GMODULE_REQUIRED=0.22
GUPNP_REQUIRED=0.6

# No need to ask for the Vala compiler if the sources are
# already compiled to C
if test ! -f src/server/MeigaServer.c
then

    # Compare major, minor and revision version values one by one
    # because lexicographic order isn't enough

    VALA_REQUIRED="0.11.2"
    VALAC_VERSION="Vala 0.11.3"
    IFS_BAK="$IFS"
    IFS=". "
    VALAC_MAJ=`echo "$VALAC_VERSION" | { read _ A _ _; echo $A; }`
    VALAC_MIN=`echo "$VALAC_VERSION" | { read _ _ A _; echo $A; }`
    VALAC_REV=`echo "$VALAC_VERSION" | { read _ _ _ A; echo $A; }`
    VALAC_REQ_MAJ=`echo "$VALA_REQUIRED" | { read A _ _; echo $A; }`
    VALAC_REQ_MIN=`echo "$VALA_REQUIRED" | { read _ A _; echo $A; }`
    VALAC_REQ_REV=`echo "$VALA_REQUIRED" | { read _ _ A; echo $A; }`
    IFS="$IFS_BAK"

    VALAC_REQ_FAIL=0
    if test "$VALAC_MAJ" \< "$VALAC_REQ_MAJ"
    then
     VALAC_REQ_FAIL=1
    elif test "$VALAC_MAJ" = "$VALAC_REQ_MAJ"
    then
      echo "Equal majors"
      if test "$VALAC_MIN" \< "$VALAC_REQ_MIN"
      then
       VALAC_REQ_FAIL=1
      elif test "$VALAC_MIN" = "$VALAC_REQ_MIN"
      then
      echo "Equal minors"
       if test "$VALAC_REV" \< "$VALAC_REQ_REV"
       then
         VALAC_REQ_FAIL=1
       fi
      fi
    fi
     
    if test "$VALAC_REQ_FAIL" = "1"
    then
      AC_MSG_ERROR([Vala >= $VALA_REQUIRED is required.])
    fi  
fi

PKG_CHECK_MODULES(gthread, gthread-2.0 >= $GTHREAD_REQUIRED)
PKG_CHECK_MODULES(glib, glib-2.0 >= $GLIB_REQUIRED)
PKG_CHECK_MODULES(gobject, gobject-2.0 >= $GLIB_REQUIRED)
PKG_CHECK_MODULES(gtk, gtk+-2.0 >= $GTK_REQUIRED)
PKG_CHECK_MODULES(libsoup24, libsoup-2.4 >= $SOUP24_REQUIRED)
PKG_CHECK_MODULES(dbusglib, dbus-glib-1 >= $DBUSGLIB_REQUIRED)
PKG_CHECK_MODULES(gmodule, gmodule-2.0 >= $GMODULE_REQUIRED)
PKG_CHECK_MODULES(gupnp, gupnp-1.0 >= $GUPNP_REQUIRED)

# Syntax changes in gupnp 0.12 and above
echo -n "checking for gupnp >= 0.12... "
if $PKG_CONFIG --atleast-version=0.12 gupnp-1.0
then
    AC_DEFINE([HAVE_GUPNP_0_12],[1],[Defined if libgupnp >= 0.12])
    echo "yes"
else
    echo "no"
fi

serviceentrydir=`$PKG_CONFIG dbus-1 --variable=session_bus_services_dir`
launcherdir="\${datadir}/applications"

AC_SUBST(gthread_CFLAGS)
AC_SUBST(gthread_LIBS)
AC_SUBST(glib_CFLAGS)
AC_SUBST(glib_LIBS)
AC_SUBST(gobject_CFLAGS)
AC_SUBST(gobject_LIBS)
AC_SUBST(gtk_CFLAGS)
AC_SUBST(gtk_LIBS)
AC_SUBST(libsoup24_CFLAGS)
AC_SUBST(libsoup24_LIBS)
AC_SUBST(dbusglib_CFLAGS)
AC_SUBST(dbusglib_LIBS)
AC_SUBST(gmodule_CFLAGS)
AC_SUBST(gmodule_LIBS)
AC_SUBST(gupnp_CFLAGS)
AC_SUBST(gupnp_LIBS)

AC_SUBST(serviceentrydir)

AC_CONFIG_FILES([Makefile
	src/server/Makefile
	src/gui/Makefile
	src/net/Makefile
	scripts/Makefile
	po/Makefile.in])

AC_OUTPUT
