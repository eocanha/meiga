#!/bin/sh
dbus-send --session --dest=com.igalia.Meiga \
    --print-reply --type=method_call /com/igalia/Meiga \
    com.igalia.Meiga.GetPathsAsString
