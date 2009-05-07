#!/bin/bash
#valac --vapidir=. --pkg=glib-2.0 --pkg=upnp Test.vala -X -I./ -X -L./ -X -lupnp

OPTIONS=""
for i in -I./ -L./ `pkg-config --cflags --libs gupnp-1.0 glib-2.0` upnp.o
do
    OPTIONS="$OPTIONS -X $i"
done

# Show equivalent gcc parameters
# valac --cc=echo --vapidir=. --pkg=glib-2.0 --pkg=upnp $OPTIONS Test.vala

# Compile to C code
# valac -C --vapidir=. --pkg=glib-2.0 --pkg=upnp $OPTIONS Test.vala

# Compile to executable
valac --vapidir=. --pkg=glib-2.0 --pkg=upnp --thread $OPTIONS Test.vala

