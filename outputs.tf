output "neptune_cluster_id" {
  description = "ID of the Neptune cluster"
  value       = try(aws_neptune_cluster.this[0].id, null)
}

output "neptune_cluster_arn" {
  description = "ARN of the Neptune cluster"
  value       = try(aws_neptune_cluster.this[0].arn, null)
}

output "neptune_cluster_endpoint" {
  description = "The endpoint of the Neptune cluster"
  value       = try(aws_neptune_cluster.this[0].endpoint, null)
}

output "neptune_cluster_reader_endpoint" {
  description = "The reader endpoint of the Neptune cluster"
  value       = try(aws_neptune_cluster.this[0].reader_endpoint, null)
}

output "neptune_cluster_resource_id" {
  description = "The resource ID of the Neptune cluster"
  value       = try(aws_neptune_cluster.this[0].cluster_resource_id, null)
}

output "neptune_cluster_snapshot_arn" {
  description = "The Amazon Resource Name (ARN) for the DB Cluster Snapshot"
  value       = try(aws_neptune_cluster_snapshot.this[0].arn, null)
}

output "neptune_iam_role_arn" {
  description = "ARN of the IAM role for Neptune"
  value       = try(aws_iam_role.this[0].arn, null)
}

output "neptune_instance_id" {
  description = "ID of the Neptune cluster instance"
  value       = try(aws_neptune_cluster_instance.this[0].id, null)
}

output "neptune_parameter_group_id" {
  description = "ID of the Neptune cluster parameter group"
  value       = try(aws_neptune_cluster_parameter_group.this[0].id, null)
}

output "neptune_db_parameter_group_id" {
  description = "ID of the Neptune DB parameter group"
  value       = try(aws_neptune_parameter_group.this[0].id, null)
}

output "neptune_subnet_group_id" {
  description = "ID of the Neptune subnet group"
  value       = try(aws_neptune_subnet_group.this[0].id, null)
}

output "neptune_event_subscription_ids" {
  description = "IDs of the Neptune event subscriptions"
  value       = try(values(aws_neptune_event_subscription.this)[*].id, [])
}

output "neptune_cluster_endpoint_ids" {
  description = "IDs of the Neptune cluster endpoints"
  value       = try(values(aws_neptune_cluster_endpoint.this)[*].id, [])
}

output "neptune_security_group_id" {
  description = "ID of the Neptune security group"
  value       = try(aws_security_group.this[0].id, null)
}

output "neptune_global_cluster_id" {
  description = "ID of the Neptune global cluster"
  value       = try(aws_neptune_global_cluster.this[0].id, null)
}

output "neptune_global_cluster_arn" {
  description = "ARN of the Neptune global cluster"
  value       = try(aws_neptune_global_cluster.this[0].arn, null)
}

output "neptune_global_cluster_resource_id" {
  description = "AWS Region-unique, immutable identifier for the global database cluster"
  value       = try(aws_neptune_global_cluster.this[0].global_cluster_resource_id, null)
}

output "neptune_global_cluster_members" {
  description = "A set of objects containing global cluster members"
  value       = try(aws_neptune_global_cluster.this[0].global_cluster_members, [])
}
