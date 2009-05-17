#!/bin/sh

# Gets IP addr of the interface having the default gateway

GWIFACE=`ip route | grep 'default via' | { read _ _ _ _ I _; echo $I; }`
IP=`ip addr show dev $GWIFACE | grep 'inet ' | { read _ J _; echo $J; } | sed 's/\/[0-9]*//'`
echo $IP
