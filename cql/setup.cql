/*
CREATE KEYSPACE IF NOT EXISTS keyspace1 WITH replication = {'class': 'org.apache.cassandra.locator.NetworkTopologyStrategy', 'datacenter1': '3'} AND durable_writes = true AND tablets = {'initial': 6000};
*/
CREATE KEYSPACE IF NOT EXISTS keyspace1 WITH replication = {'class': 'org.apache.cassandra.locator.NetworkTopologyStrategy', 'datacenter1': '3'} AND durable_writes = true;

CREATE TABLE IF NOT EXISTS keyspace1.standard1 (
    key blob,
    val blob,
    PRIMARY KEY (key)
) WITH bloom_filter_fp_chance = 0.01
    AND caching = {'keys': 'ALL', 'rows_per_partition': 'ALL'}
    AND comment = ''
    AND compaction = {'class': 'IncrementalCompactionStrategy', 'min_threshold': '4'}
    AND compression = {}
    AND crc_check_chance = 1
    AND default_time_to_live = 0
    AND gc_grace_seconds = 864000
    AND max_index_interval = 2048
    AND memtable_flush_period_in_ms = 0
    AND min_index_interval = 128
    AND speculative_retry = '200.00ms'
    AND tombstone_gc = {'mode': 'repair', 'propagation_delay_in_seconds': '3600'};

CREATE ROLE IF NOT EXISTS wlp WITH PASSWORD = 'wlp' AND LOGIN = true AND SUPERUSER = true;

CREATE SERVICE_LEVEL IF NOT EXISTS realtime WITH SHARES = 1000;
CREATE SERVICE_LEVEL IF NOT EXISTS wlp WITH SHARES = 100;

ATTACH SERVICE_LEVEL realtime TO cassandra;
ATTACH SERVICE_LEVEL wlp TO wlp;
