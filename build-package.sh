#!/bin/sh

# Parameters:
# -d	      Installs all the needed compilation dependencies
# -r distro   Prepares a release for a given distro (jaunty, karmic, lucid...) in /tmp
#             After that, ***cd /tmp*** and upload with: dput -f meiga meiga*.changes
# -rn distro  The same than -r, but precompiling C sources to avoid dependancy on
#             Vala package in the target distro
# -s          Prepares a source release
# -sn         The same than -s, but precompiling C sources to avoid dependancy on
#             Vala package

# -------------------------------------------------

VALA_URL='http://download.gnome.org/sources/vala/0.8/vala-0.8.1.tar.bz2'

# -------------------------------------------------

LSB_VENDOR=`lsb_release -i | cut -f2`
case $LSB_VENDOR in
  Ubuntu|Debian)
    VALA_INSTALLED=0
    WKDIR=`pwd`
    MEIGA_VERSION=`grep AC_INIT "$WKDIR/configure.ac" | sed -e 's/[^,]*,\[\([^]]*\).*/\1/'`

    if [ "$#" -ge 1 ]
    then
      if [ "$1" = "-d" ]
      then
        shift
        if [ -f /usr/bin/lsb_release ]
        then
          UBUNTU_RELEASE=`lsb_release -r | { read _ X; echo $X; }`
          export PATH=/usr/local/bin:$PATH
          apt-get -y --force-yes \
            install wget flex bison debhelper fakeroot \
            gnome-common pkg-config \
            libgtk2.0-dev libglade2-dev libsoup2.4-dev \
            libdbus-1-dev libdbus-glib-1-dev libgupnp-1.0-dev
          ldconfig
          VALAC_PATH=`which valac`
          if [ ! -f "$VALAC_PATH" ]
          then
            cd /tmp
            wget "$VALA_URL"
            tar jxvf vala*.tar.bz2
            cd vala*
            ./configure
            make
            make install && VALA_INSTALLED=1
            cd "$WKDIR"
            ldconfig
          fi
        else
          echo "Your distribution is not supported for dependency autoinstall"
        fi
      fi

      if [ "$1" = "-r" -o "$1" = "-rn" -o "$1" = "-s" -o "$1" = "-sn" ]
      then
        RELEASETYPE="$1"
        DISTRO="$2"
        PACKAGE="meiga-$MEIGA_VERSION"
        BUILDPATH="/tmp/$PACKAGE"

        shift
        if [ "$RELEASETYPE" = "-r" -o "$RELEASETYPE" = "-rn" ]
        then
          shift
        fi

        if [ ! -d .git ]
        then
          echo "This kind of release can only be done from a git clone, not from downloaded sources"
          exit
        fi

        rm -rf "$BUILDPATH" "$BUILDPATH"_*
        mkdir "$BUILDPATH" \
        && cp -a .git "$BUILDPATH" \
        && cd "$BUILDPATH" \
        && git reset --hard HEAD \
        && rm -rf .git \
        && {
          if [ "$RELEASETYPE" = "-r" -o "$RELEASETYPE" = "-rn" ]
          then
	    sed -e "s/) unstable/$DISTRO) $DISTRO/" < "$WKDIR/debian/changelog" > "$BUILDPATH/debian/changelog"
          fi
        }

        BINARYONLY="-S"
        SIGNCHANGES=""

        if [ "$RELEASETYPE" = "-rn" -o "$RELEASETYPE" = "-sn" ]
        then
          # Remove valac dependency from debian/control in /tmp/meiga
          sed -e 's/, valac (.*)//' < "$WKDIR/debian/control" > "$BUILDPATH/debian/control" \
          && cd "$BUILDPATH" && ./autogen.sh \
          && cd "$BUILDPATH/src/gui" && make meiga.vala.stamp && cd "$BUILDPATH" \
          && cd "$BUILDPATH/src/server" && make meiga.vala.stamp && cd "$BUILDPATH"
        fi
      else
        BINARYONLY="-b"
        SIGNCHANGES="-uc"
      fi
    fi

    CHECKDEPS=`dpkg-checkbuilddeps 2>&1`

    echo "--------------------------------------------------"
    echo "$CHECKDEPS"
    echo "--------------------------------------------------"
    echo
    echo

    if test -n "$CHECKDEPS"
    then
      echo "Some build dependencies unmet, but building anyway..."
      echo "Do you have an older distribution without Vala package?"
      echo
      echo
    fi

    if [ "$RELEASETYPE" = "-s" -o "$RELEASETYPE" = "-sn" ]
    then
      cd "$BUILDPATH" \
      && cd .. \
      && tar zcvf "$PACKAGE.tar.gz" "$PACKAGE"
    else
      # If you're using a distribution for which an updated Vala package 
      # exists and you want to check the dependency, remove the "-d" option

      dpkg-buildpackage -d -rfakeroot $BINARYONLY $SIGNCHANGES
    fi

    if [ "$VALA_INSTALLED" = "1" ]
    then
      cd /tmp
      cd vala*
      make uninstall
      cd "$WKDIR"
      ldconfig
    fi

    if [ -n "$DISTRO" ]
    then
      echo "---------------------------------------------------------------"
      echo "Source release prepared."
      echo "Run the following commands to upload the release to Ubuntu PPA:"
      echo "  cd /tmp"
      echo "  dput -f meiga meiga*.changes"
      echo "---------------------------------------------------------------"
    fi

    ;;

  Fedora|Redhat|CentOS)
    RPMBUILD=`which rpmbuild`
    if [ -z $RPMBUILD ]
    then
      echo "Please install rpmbuild and setup RPM build environment"
      exit
    fi
    
    $RPMBUILD -bb fedora/meiga.spec
    ;;

esac;
