#!/bin/sh

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
  sleep 5;
fi

# If you're using a distribution for which an updated Vala package 
# exists and you want to check the dependency, remove the "-d" option

dpkg-buildpackage -d -rfakeroot -b -uc
