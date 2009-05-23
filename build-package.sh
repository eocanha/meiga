#!/bin/sh
set -x
dpkg-buildpackage -rfakeroot -b -uc

