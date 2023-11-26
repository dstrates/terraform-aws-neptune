output "neptune_cluster_id" {
  description = "ID of the Neptune cluster"
  value       = module.neptune.neptune_cluster_id
}

output "neptune_cluster_snapshot_arn" {
  description = "The Amazon Resource Name (ARN) for the DB Cluster Snapshot"
  value       = module.neptune.neptune_cluster_snapshot_arn
}

output "neptune_instance_id" {
  description = "ID of the Neptune cluster instance"
  value       = module.neptune.neptune_instance_id
}

output "neptune_parameter_group_id" {
  description = "ID of the Neptune cluster parameter group"
  value       = module.neptune.neptune_parameter_group_id
}

output "neptune_db_parameter_group_id" {
  description = "ID of the Neptune DB parameter group"
  value       = module.neptune.neptune_db_parameter_group_id
}

output "neptune_subnet_group_id" {
  description = "ID of the Neptune subnet group"
  value       = module.neptune.neptune_subnet_group_id
}

output "neptune_event_subscription_ids" {
  description = "IDs of the Neptune event subscriptions"
  value       = module.neptune.neptune_event_subscription_ids
}

output "neptune_cluster_endpoint_ids" {
  description = "IDs of the Neptune cluster endpoints"
  value       = module.neptune.neptune_cluster_endpoint_ids
}

output "neptune_security_group_id" {
  description = "ID of the Neptune security group"
  value       = module.neptune.neptune_security_group_id
}

output "neptune_iam_role_arn" {
  description = "ARN of the IAM role for Neptune"
  value       = module.neptune.neptune_iam_role_arn
}
