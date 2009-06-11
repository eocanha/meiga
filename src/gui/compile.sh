export datadir=.

valac -g --thread --pkg=gtk+-2.0 --pkg=gmodule-2.0 --pkg=dbus-glib-1 \
    --vapidir=. --pkg=config -X -DDATADIR=\"$datadir\" \
    Gui.vala -o meiga
