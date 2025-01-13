#!/bin/bash

gpg --homedir /tmp --no-default-keyring --keyring /etc/apt/keyrings/scylladb.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys A43E06657BAC99E3
wget -O /etc/apt/sources.list.d/scylla.list https://s3.amazonaws.com/downloads.scylladb.com/deb/ubuntu/scylla-2024.2.list

apt-get update
apt-get -y install scylla-enterprise

SEED_IP="172.31.0.101"
INSTANCE_IP="$(hostname -I)"

# Determine rack placement. Pretty hardcoded, lol. Use modulo instead?
IP_BLOCK=$(echo ${INSTANCE_IP} | awk -F'.' '{ print $NF }')

case ${IP_BLOCK} in
   "101"|"104"|"107")
     rack="rack1"
     ;;
   "102"|"105"|"108")
     rack="rack2"
     ;;
   "103"|"106"|"109")
     rack="rack3"
     ;;
   *) ;;
esac

cat > /etc/scylla/cassandra-rackdc.properties << EOF
dc=datacenter1
rack=$rack

EOF

cat > /etc/scylla/scylla.yaml << EOF

num_tokens: 256
commitlog_sync: periodic
commitlog_sync_period_in_ms: 10000
commitlog_segment_size_in_mb: 32
schema_commitlog_segment_size_in_mb: 128
seed_provider:
    # The addresses of hosts that will serve as contact points for the joining node.
    # It allows the node to discover the cluster ring topology on startup (when
    # joining the cluster).
    # Once the node has joined the cluster, the seed list has no function.
    - class_name: org.apache.cassandra.locator.SimpleSeedProvider
      parameters:
          # In a new cluster, provide the address of the first node.
          # In an existing cluster, specify the address of at least one existing node.
          # If you specify addresses of more than one node, use a comma to separate them.
          # For example: "<IP1>,<IP2>,<IP3>"
          - seeds: "$SEED_IP"
listen_address: $INSTANCE_IP
native_transport_port: 9042
native_shard_aware_transport_port: 19042
read_request_timeout_in_ms: 5000
write_request_timeout_in_ms: 2000
cas_contention_timeout_in_ms: 1000
endpoint_snitch: GossipingPropertyFileSnitch
rpc_address: 0.0.0.0
broadcast_rpc_address: $INSTANCE_IP
rpc_port: 9160
api_port: 10000
api_address: 127.0.0.1
batch_size_warn_threshold_in_kb: 128
batch_size_fail_threshold_in_kb: 1024
authenticator: PasswordAuthenticator
authorizer: CassandraAuthorizer

partitioner: org.apache.cassandra.dht.Murmur3Partitioner
commitlog_total_space_in_mb: -1
internode_compression: all
murmur3_partitioner_ignore_msb_bits: 12
strict_is_not_null_in_views: true
maintenance_socket: ignore
enable_tablets: true
api_ui_dir: /opt/scylladb/swagger-ui/dist/
api_doc_dir: /opt/scylladb/api/api-doc/
compaction_enforce_min_threshold: true

EOF

# Workaround a bug in Ec2 when disks are provisioned in the wrong order lol

DISKS=$(lsblk | grep -E '3\.4T|2\.3T|6.8T' | awk '{ print "/dev/" $1 }' | paste -sd, -)


# Extract the primary NIC name from `ip addr`
primary_nic=$(ip addr | awk '/state UP/{print $2}' | sed 's/://')


scylla_setup --disks ${DISKS} --online-discard 1 \
   --nic ${primary_nic} --io-setup 1 --no-version-check \
   --no-fstrim-setup --no-rsyslog-setup

# Better be safe, than sorry later.

sed -i 's/^SET_NIC_AND_DISKS.*$/SET_NIC_AND_DISKS=yes/g' /etc/default/scylla-server
scylla_sysconfig_setup --nic ${primary_nic} --setup-nic-and-disks

# Wait for seed node availability (unless we are the seed), and start ScyllaDB
# if (and only if) we are either the 2nd or 3rd node.

case ${IP_BLOCK} in
     "101")
       echo "Starting ScyllaDB"
       systemctl start scylla-server
       ;;
     "102"|"103")
	  echo "Starting ScyllaDB"
	  while ! nc -z ${SEED_IP} 9042; do
	    echo "Seed node is not ready. Retrying in 10 seconds..."
	    sleep 10
	  done
	  systemctl start scylla-server
	  ;;
     *)
       ;;
esac

echo "ScyllaDB Started"
