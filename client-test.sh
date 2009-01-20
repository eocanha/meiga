#!/bin/sh
dbus-send --session --dest=org.gnome.FromGnomeToTheWorld \
--print-reply --type=method_call /org/gnome/FromGnomeToTheWorld \
org.gnome.FromGnomeToTheWorld.GetPathsAsString
