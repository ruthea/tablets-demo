#!/bin/bash

# Cleanup commands for ScyllaDB data directories
sudo rm -rf /var/lib/scylla/data
sudo find /var/lib/scylla/commitlog -type f -delete
sudo find /var/lib/scylla/hints -type f -delete
sudo find /var/lib/scylla/view_hints -type f -delete

# Credentials for ScyllaDB
SCYLLA_USER="cassandra"
SCYLLA_PASSWORD="cassandra"

# The command to be executed
QUERY="SELECT host_id FROM system.local;"

# Run the query using cqlsh and capture the result
RESULT=$(echo "$QUERY" | cqlsh -u "$SCYLLA_USER" -p "$SCYLLA_PASSWORD" --no-color | grep -oP '(?<=\| )[0-9a-fA-F-]+(?= \|)')

# Check if RESULT is not empty
if [[ -z "$RESULT" ]]; then
  echo "Failed to fetch host_id or no result returned."
  exit 1
fi

# Use the RESULT variable in the next step
echo "The host_id is: $RESULT"

# Append the parameter to the ScyllaDB YAML configuration file
SCYLLA_YAML="/etc/scylla/scylla.yaml"

# Backup the original configuration file
if [[ ! -f "${SCYLLA_YAML}.bak" ]]; then
  cp "$SCYLLA_YAML" "${SCYLLA_YAML}.bak"
  echo "Backup of scylla.yaml created at ${SCYLLA_YAML}.bak"
fi

# Add the parameter to the end of the configuration file
echo "replace_node_first_boot: $RESULT" >> "$SCYLLA_YAML"

# Confirm the addition
if grep -q "replace_node_first_boot: $RESULT" "$SCYLLA_YAML"; then
  echo "Parameter successfully added to $SCYLLA_YAML"
else
  echo "Failed to add the parameter to $SCYLLA_YAML"
  exit 1
fi