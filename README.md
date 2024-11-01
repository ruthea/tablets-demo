# tablets-demo
This repo contains a simple Web UI with ScyllaDB and Monitoring.

## Before you start
The following assumptions are made as part of this demo:

- The Monitoring runs on the same VM as the Web App (there is basically no reason not to)
- All ScyllaDB VMs are provisioned and configured, using the default `/var/lib/scylla` mount
- Loaders already have `cassandra-stress` installed
- There is SSH connectivity from the Monitoring/Web VM (private key under the user running the frontend) to all loaders & ScyllaDB nodes
- Ubuntu is used, and the user to SSH from/to is named `ubuntu`
- All ScyllaDB nodes point to the same node as seed node
- You **never** (!!!) decommission the seed node

The code here makes no attempt to figure out these for you. In addition, because Ansible is used to instrument scaling tasks, and test connectivity (see the `ping` playbook), you are required to tune Ansible's `inventory.ini` before you get started.

Although not mandatory, if you'd like to use WLP - you must enable ScyllaDB `Authentication`. We rely on the default `cassandra/cassandra` combo as there's very little reason not to.

We also assume `tablets` are enabled. The full `scylla.yaml` code from a random node goes like this:

```yaml
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
          - seeds: "172.31.13.19"
listen_address: 172.31.13.19
native_transport_port: 9042
native_shard_aware_transport_port: 19042
read_request_timeout_in_ms: 5000
write_request_timeout_in_ms: 2000
cas_contention_timeout_in_ms: 1000
endpoint_snitch: GossipingPropertyFileSnitch
rpc_address: 0.0.0.0
broadcast_rpc_address: 172.31.13.19
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
```

Where:

- `compaction_enforce_min_threshold` is important so we can ingest data faster
- `enable_tablets` ensures tablets is the default default
- `endpoint_snitch: GossipingPropertyFileSnitch` is nice for simulating an artifical multi-AZ setup, when in reality we save on costs by running everything under a single AZ only :-)

## Getting Started

Unless I missed anything, ensure you have `python3`, `python3-pip` and simply install the required packages:

```shell
apt update && apt-get install -y python3 python3-pip
pip3 install -r requirements.txt
```

## Environment

There is no mandatory infrastructure to run this. Technically speaking, you could use docker, or whatever better suits you.
The currently packaged code ingests and reaches 1M ops/second for a payload of 4KB. It originally relied on the following infrastructure:

- ScyllaDB Nodes: 6x i4i.8xlarge, where:
  - 3 nodes are always up & running
  - 3 nodes are "dormant" waiting to be scaled out
- Loaders: 3x c7.12xlarge, where:
  - 2 VMs are "just loaders"
  - 1 VM is a loder+monitor+web app

Feel free to adjust these as you see fit, and play with the scripts under the `scripts` folder to scale accordingly.

## Running the app

```shell
$ python3 app.py -h
usage: app.py [-h] --seed-node SEED_NODE --monitoring-ip MONITORING_IP [--init]

WebApp Settings

options:
  -h, --help            show this help message and exit
  --seed-node SEED_NODE, -s SEED_NODE
                        IP address of the seed node.
  --monitoring-ip MONITORING_IP, -m MONITORING_IP
                        IP address for monitoring.
  --init, -i            Optional flag to initialize (default: False).
```

You must specify the **private IP** of your seed-node, this will be used on scripts requiring providing a contact point, among other things.
You must also specify the **public IP** of your Monitoring instance, this will be used to update the IP address on the HTML page iframes.

The `--init` parameter is optional. When you specify it, it will execute the schema creation steps, add roles and define service levels. In addition, it will also kickstart the initial data ingestion. See the Python app code to see how it works and adjust as needed, it should be relatively straightforward.

If this is your first time ingesting data, then be minded that starting the initial 500K/s data load may take a while (for your cache to warm up) before you observe the actual throughput.

Once you are happy with the results, proceed with next steps (scaling out, then scaling traffic, playing with batches, nodetool/cqlsh tabs, and then scaling-in). 

If you set-up things correctly, then you should be able to scale-out and scale-in without any intervention.

## Known issues

- The scaling playbooks contain a task to update monitoring and add/remove the affected nodes from each. This is optional, and I decided not to automate it. If you don't care either, simply leave your monitoring already configured with all nodes you need and off you go. (Though, for a better UX - remember to update the playbooks)
- The code is NOT fool-proof. Don't try stupid things like downscaling while you are scaling-out. This will break things. (Probably, I didn't test it)
- Most playbooks/commands block. I know it. Feel free to rewrite the code using asyncio and off you go.
- Probably more, open an issue if you need help. Expect delayed responses.

## Out of Scope

- This work doesn't aim to auto-provision VMs. Just terraform it, don't try to reinvent the wheel.
- Yes, all ScyllaDB nodes must be up and running. If this bothers you, fix it. Or even better: Switch to K8s Operator.
- The code makes no attempt to troubleshoot things for you. Get familiar with it, and adapt as you need.
