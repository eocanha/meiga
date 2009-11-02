#!/bin/sh

# Parameters:
# -d	Installs all the needed compilation dependencies

# -------------------------------------------------

VALA_URL='http://download.gnome.org/sources/vala/0.7/vala-0.7.2.tar.bz2'

# -------------------------------------------------

VALA_INSTALLED=0
WKDIR=`pwd`
if [ "$#" -ge 1 ]
then if [ "$1" = "-d" ]
  then
    if [ -f /usr/bin/lsb_release ]
    then
      UBUNTU_RELEASE=`lsb_release -r | { read _ X; echo $X; }`
      export PATH=/usr/local/bin:$PATH
      apt-get -y --force-yes \
        install wget flex bison debhelper fakeroot \
        gnome-common pkg-config \
        libgtk2.0-dev libglade2-dev libsoup2.2-dev libsoup2.4-dev \
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

# If you're using a distribution for which an updated Vala package 
# exists and you want to check the dependency, remove the "-d" option

dpkg-buildpackage -d -rfakeroot -b -uc

if [ "$VALA_INSTALLED" = "1" ]
then
  cd /tmp
  cd vala*
  make uninstall
  cd "$WKDIR"
  ldconfig
fi
