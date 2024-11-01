#!/bin/bash

if [ -z "$1" ]; then
	echo "No loaders specified, nothing to do!"
	exit 1
fi

LOADER_LIST="$1"

for i in ${LOADER_LIST[@]}; do
   # First ensure no other process is running
   echo -ne "Stopping loader on $i ..."
   ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${i} 'killall java' 2>/dev/null
   echo "Done!"
done
