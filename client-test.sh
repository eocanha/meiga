#!/bin/sh
dbus-send --session --dest=org.gnome.FromGnomeToTheWorld \
--print-reply --type=signal /org/gnome/FromGnomeToTheWorld \ 
org.gnome.FromGnomeToTheWorld.Test
