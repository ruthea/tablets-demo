#!/bin/bash

if [ -z "$1" ]; then
   echo "You must specify a contact point"
   exit 1
fi

CONTACT_POINT=$1

# Non-blocking
echo "Start C-s reader"
nohup cassandra-stress read duration=24h cl=local_quorum -col names=val size='FIXED(3900)' -mode native cql3 user=wlp password=wlp -rate throttle=100000/s threads=128 -pop seq=10M..50M -node ${CONTACT_POINT} > /tmp/wlp.log 2>&1 </dev/null &
