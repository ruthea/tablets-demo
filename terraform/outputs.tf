

# Output for ScyllaDB Nodes
output "scylla_nodes_public_ips" {
  description = "Public IPs of ScyllaDB nodes"
  value       = [for instance in aws_instance.scylladb_node : instance.public_ip]
}

output "scylla_nodes_private_ips" {
  description = "Private IPs of ScyllaDB nodes"
  value       = [for instance in aws_instance.scylladb_node : instance.private_ip]
}

output "scylla_nodes_public_dns" {
  description = "Public DNS names of ScyllaDB nodes"
  value       = [for instance in aws_instance.scylladb_node : instance.public_dns]
}

output "demo_portal" {
  value = format("http://%s:5000", aws_instance.loader_node[0].public_dns)
  description = "URL of the Demo Portal"
}
# Output for Loader Nodes
output "loader_nodes_public_ips" {
  description = "Public IPs of Loader nodes"
  value       = [for instance in aws_instance.loader_node : instance.public_ip]
}

output "loader_nodes_private_ips" {
  description = "Private IPs of Loader nodes"
  value       = [for instance in aws_instance.loader_node : instance.private_ip]
}

output "loader_nodes_public_dns" {
  description = "Public DNS names of Loader nodes"
  value       = [for instance in aws_instance.loader_node : instance.public_dns]
}

