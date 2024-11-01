#!/bin/bash

if [ -z "$1" ]; then
  echo "No contact point provided."
  exit 1
fi

NODE="$1"

nohup cassandra-stress write n=100M cl=local_quorum -col names=val size='FIXED(3900)' -mode native cql3 user=cassandra password=cassandra -rate throttle=500000/s threads=512 -pop seq=1..100M -node ${NODE} > /tmp/ingest.log 2>&1 </dev/null &
