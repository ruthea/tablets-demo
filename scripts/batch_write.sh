Å#!/bin/bash

CONTACT_POINT=$1
# Set the Cassandra stress command
STRESS_CMD="nohup cassandra-stress write duration=2m cl=local_quorum -col names=val size='FIXED(20000)' -mode native cql3 user=wlp password=wlp -rate throttle=200000/s threads=128 -pop seq=10M..50M -node ec2-35-167-163-85.us-west-2.compute.amazonaws.com ##\${CONTACT_POINT} > /tmp/wlp.log 2>&1 </dev/null &"

# Infinite loop
while true; do
    echo "Starting Cassandra stress test for 2 minutes..."
    $STRESS_CMD

    # Wait for a random time between 1 and 4 minutes
    WAIT_TIME=$((60 + RANDOM % 180)) # Random time in seconds (60 to 240)
    echo "Waiting for $WAIT_TIME seconds..."
    sleep $WAIT_TIME
done
