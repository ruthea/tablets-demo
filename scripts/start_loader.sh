#!/bin/bash

# Base ScyllaDB IPs - We do this to ensure each loader uses
# a different node as a control connection, to avoid overwhelming
# a single one as we start them all concurrently.
NODE_LIST=(172.31.13.19 172.31.3.146 172.31.3.82)
LOADER_LIST=(172.31.5.176 172.31.15.218 172.31.1.117)

if [ -z "$1" ]; then
   echo "Must specify throttle: [0-9]+"
   exit 1
fi

if [ -z "$2" ]; then
   echo "No loaders specified. Nothing to do!"
   exit 1
fi

if [ -z "$3" ]; then
   echo "You must specify node contact points"
   exit 1
fi


THROTTLE="$1"
LOADER_LIST=$2
NODE_LIST=$3

# This is quite an awkward check, but I am lazy to fix lol
if [ "${#LOADER_LIST[@]}" -lt "${#NODE_LIST[@]}" ]; then
   echo "You specified more loaders than nodes."
   echo "Because we try to use a different contact point per loader, this is unsupported."
   echo "But can easily be worked around ;-)"
   exit 1
fi

count=1
for i in ${LOADER_LIST}; do
   NODE=$(echo ${NODE_LIST} | cut -d ' ' -f${count})
   # First ensure no other process is running
   echo "Ensuring loader stopped on $i"
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${i} 'killall java' 2>/dev/null
   echo "Stopped!"
   sleep 3

   # Start it 
   echo "Starting loader on $i, contact point ${NODE}"
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${i} "nohup cassandra-stress mixed duration=24h cl=local_quorum 'ratio(read=8,write=2)' -col names=val size='FIXED(3900)' -mode native cql3 user=cassandra password=cassandra -rate throttle=${THROTTLE}/s threads=512 -pop seq=1..10M -node ${NODE} > /tmp/loader.log 2>&1 </dev/null &"

   count=$(expr $count + 1)
done
