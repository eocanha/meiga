#!/bin/sh
echo "DBUS SERVICE!" > /tmp/dbus.txt
echo `date` >> /tmp/dbus.txt

exit 0

# This isn't executed:
/home/enrique/HACKFEST/GNOME/myserver/myserver 2>> /tmp/fromgnometotheworld.log
