#!/bin/bash
gcc -g `pkg-config --libs --cflags gupnp-1.0 glib` upnp.c
