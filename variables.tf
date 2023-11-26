variable "allow_major_version_upgrade" {
  description = "(Optional) Specifies whether upgrades between different major versions are allowed. You must set it to true when providing an engine_version parameter that uses a different major version than the DB cluster's current version."
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Specifies whether cluster modifications are applied immediately"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "The number of days to retain backups for"
  type        = number
  default     = 7
}

variable "cluster_identifier" {
  description = "The cluster identifier"
  type        = string
}

variable "create_neptune_cluster" {
  description = "Whether or not to create a Neptune cluster"
  type        = bool
  default     = true
}

variable "create_neptune_cluster_endpoint" {
  description = "Whether or not to create Neptune cluster endpoints."
  type        = bool
  default     = false
}

variable "create_neptune_parameter_group" {
  description = "Whether or not to create a Neptune DB parameter group"
  type        = bool
  default     = true
}

variable "create_neptune_cluster_parameter_group" {
  description = "Whether or not to create a Neptune cluster parameter group"
  type        = bool
  default     = true
}

variable "create_neptune_cluster_snapshot" {
  description = "Whether or not to create a Neptune cluster snapshot"
  type        = bool
  default     = true
}

variable "create_neptune_iam_role" {
  description = "Whether or not to create and attach Neptune IAM role"
  type        = bool
  default     = true
}

variable "create_neptune_instance" {
  description = "Whether or not to create Neptune instances"
  type        = bool
  default     = true
}

variable "create_neptune_security_group" {
  description = "Whether or not to create a Neptune security group"
  type        = bool
  default     = true
}

variable "create_neptune_subnet_group" {
  description = "Whether or not to create a Neptune subnet group"
  type        = bool
  default     = true
}

variable "create_timeout" {
  description = "Timeout for creating the Neptune cluster snapshot"
  type        = string
  default     = "20m"
}

variable "db_cluster_identifier" {
  description = "The DB Cluster Identifier from which to take the snapshot"
  type        = string
}

variable "db_cluster_snapshot_identifier" {
  description = "The Identifier for the snapshot"
  type        = string
}

variable "deletion_protection" {
  type        = bool
  description = "(Optional) A value that indicates whether the DB cluster has deletion protection enabled"
  default     = false
}

variable "enable_cloudwatch_logs_exports" {
  type        = list(string)
  description = "(Optional) A list of the log types this DB cluster is configured to export to Cloudwatch Logs. Currently only supports `audit` and `slowquery`."
  default     = null
}

variable "enable_serverless" {
  description = "Whether or not to create a Serverless Neptune cluster"
  type        = bool
  default     = true
}

variable "event_subscriptions" {
  description = <<-EOT
    Map of Neptune event subscriptions with names and SNS topic ARNs

    Example:
    {
      "subscription1" = "arn:aws:sns:us-east-1:123456789012:topic1",
      "subscription2" = "arn:aws:sns:us-east-1:123456789012:topic2"
      # Add more subscriptions as needed
    }
  EOT
  type        = map(string)
  default     = null
}

variable "iam_database_authentication_enabled" {
  description = "Specifies whether IAM database authentication is enabled"
  type        = bool
  default     = true
}

variable "iam_roles" {
  description = "(Optional) A List of ARNs for the IAM roles to associate to the Neptune Cluster"
  type        = list(string)
  default     = null
}

variable "engine_version" {
  description = "The database engine version"
  type        = string
  default     = "1.2.0.1"
}

variable "kms_key_arn" {
  description = "(Optional) The ARN for the KMS encryption key. When specifying kms_key_arn, storage_encrypted needs to be set to true."
  type        = string
  default     = null
}

variable "max_capacity" {
  description = "The maximum Neptune Capacity Units (NCUs) for the cluster"
  type        = number
  default     = 128
}

variable "min_capacity" {
  description = "The minimum Neptune Capacity Units (NCUs) for the cluster"
  type        = number
  default     = 2.5
}

variable "neptune_cluster_endpoints" {
  description = "A map of Neptune cluster endpoints to create."
  type = map(object({
    endpoint_type    = string
    static_members   = list(string)
    excluded_members = list(string)
    tags             = map(string)
  }))
  default = {}
}

variable "neptune_cluster_instance_tags" {
  description = "Tags for the Neptune cluster instances"
  type        = map(string)
  default     = {}
}

variable "neptune_cluster_parameters" {
  description = "A map of Neptune cluster parameter settings"
  type = map(object({
    key   = string
    value = string
  }))
  default = {
    parameter1 = {
      key   = "neptune_enable_audit_log"
      value = "1"
    }
    # Add more parameters as needed
  }
}

variable "neptune_cluster_parameter_group_tags" {
  description = "Tags for the Neptune cluster parameter group"
  type        = map(string)
  default     = {}
}

variable "neptune_db_parameters" {
  description = "A map of Neptune DB parameter settings"
  type = map(object({
    key   = string
    value = string
  }))
  default = {
    parameter1 = {
      key   = "neptune_query_timeout"
      value = "25"
    }
  }
}

variable "neptune_event_subscription_tags" {
  description = "Tags for the Neptune event subscription"
  type        = map(string)
  default     = {}
}

variable "neptune_family" {
  description = "The family of the neptune cluster and parameter group."
  type        = string
  default     = "neptune1.2"
}

variable "neptune_parameter_group_tags" {
  description = "Tags for the Neptune parameter group"
  type        = map(string)
  default     = {}
}

variable "neptune_port" {
  description = "Network port for the Neptune DB Cluster"
  type        = number
  default     = 8182
}

variable "neptune_role_name" {
  description = "Name for the Neptune IAM role"
  type        = string
  default     = "iam-role-neptune"
}

variable "neptune_role_description" {
  description = "Description for the Neptune IAM role"
  type        = string
  default     = null
}

variable "neptune_role_permissions_boundary" {
  description = "ARN of the policy that is used to set the permissions boundary for the Neptune IAM role"
  type        = string
  default     = null
}

variable "neptune_security_group_tags" {
  description = "Tags for the Neptune security group"
  type        = map(string)
  default     = {}
}

variable "neptune_subnet_cidrs" {
  description = "A list of subnet CIDRs where the Neptune cluster is situated"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "neptune_subnet_group_tags" {
  description = "Tags for the Neptune subnet group"
  type        = map(string)
  default     = {}
}

variable "preferred_backup_window" {
  description = "The daily time range during which automated backups are created"
  type        = string
  default     = "07:00-09:00"
}

variable "skip_final_snapshot" {
  description = "Determines whether a final Neptune snapshot is created before deletion"
  type        = bool
  default     = true
}

variable "storage_encrypted" {
  description = "(Optional) Specifies whether the Neptune cluster is encrypted. The default is false if not specified."
  type        = bool
  default     = true
}

variable "subnet_ids" {
  description = "A list of subnet IDs to associate with the Neptune cluster"
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to the Neptune cluster"
  type        = map(string)
  default     = null
}

variable "vpc_id" {
  description = "The VPC ID for the Neptune cluster and security group"
  type        = string
  default     = null
}

variable "vpc_security_group_ids" {
  description = "(Optional) List of VPC security groups to associate with the Cluster"
  type        = list(string)
  default     = null
}
