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

variable "availability_zones" {
  description = "(Optional) A list of EC2 Availability Zones that instances in the Neptune cluster can be created in."
  type        = list(string)
  default     = null
}

variable "backup_retention_period" {
  description = "The number of days to retain backups for"
  type        = number
  default     = 7
}

variable "cluster_identifier" {
  description = "The cluster identifier. Required if create_neptune_cluster is true."
  type        = string
  default     = null
}

variable "cluster_identifier_prefix" {
  description = "(Optional) Creates a unique cluster identifier beginning with the specified prefix. Conflicts with cluster_identifier."
  type        = string
  default     = null
}

variable "copy_tags_to_snapshot" {
  description = "(Optional) If set to true, tags are copied to any snapshot of the DB cluster that is created."
  type        = bool
  default     = null
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

variable "create_neptune_global_cluster" {
  description = "Whether or not to create a Neptune global cluster"
  type        = bool
  default     = false
}

variable "create_neptune_iam_role" {
  description = "Whether or not to create and attach a Neptune IAM role"
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
  default     = null
}

variable "db_cluster_snapshot_identifier" {
  description = "The Identifier for the snapshot"
  type        = string
  default     = null
}

variable "deletion_protection" {
  type        = bool
  description = "(Optional) A value that indicates whether the DB cluster has deletion protection enabled"
  default     = true
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

variable "engine_version" {
  description = "The database engine version. When enable_serverless = true, must be 1.2.0.1 or above."
  type        = string
  default     = "1.2.0.1"
}

variable "event_subscriptions" {
  description = <<-EOT
    Map of Neptune event subscriptions with names and SNS topic ARNs

    Example:
    {
      "subscription1" = "arn:aws:sns:us-east-1:123456789012:topic1",
      "subscription2" = "arn:aws:sns:us-east-1:123456789012:topic2"
    }
  EOT
  type        = map(string)
  default     = null
}

variable "final_snapshot_identifier" {
  description = "(Optional) The name of your final Neptune snapshot when this Neptune cluster is deleted. If omitted, no final snapshot will be made."
  type        = string
  default     = null
}

variable "global_cluster_engine" {
  description = "(Optional) Name of the database engine to be used for the global cluster. Valid values: neptune."
  type        = string
  default     = null
}

variable "global_cluster_engine_version" {
  description = "(Optional) Engine version of the global database. Must be compatible with Neptune global cluster versions."
  type        = string
  default     = null
}

variable "global_cluster_identifier" {
  description = "(Optional) The global cluster identifier specified on aws_neptune_global_cluster."
  type        = string
  default     = null
}

variable "global_cluster_source_db_cluster_identifier" {
  description = "(Optional) Amazon Resource Name (ARN) to use as the primary DB Cluster of the Global Cluster on creation. Terraform cannot perform drift detection of this value."
  type        = string
  default     = null
}

variable "global_cluster_deletion_protection" {
  description = "(Optional) Whether or not the global cluster should have deletion protection enabled. Default: false."
  type        = bool
  default     = false
}

variable "global_cluster_storage_encrypted" {
  description = "(Optional) Specifies whether the global cluster is encrypted. The default is false unless the source DB cluster is encrypted."
  type        = bool
  default     = null
}

variable "iam_database_authentication_enabled" {
  description = "Specifies whether IAM database authentication is enabled"
  type        = bool
  default     = true
}

variable "iam_role_policies" {
  description = "(Optional) List of IAM policy ARNs to attach to the Neptune IAM role. Example: [\"arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess\"] for bulk load."
  type        = list(string)
  default     = []
}

variable "iam_roles" {
  description = "(Optional) A List of ARNs for the IAM roles to associate to the Neptune Cluster"
  type        = list(string)
  default     = null
}

variable "instance_identifier" {
  description = "(Optional) The identifier for the primary Neptune cluster instance. If omitted, Terraform will assign a random, unique identifier."
  type        = string
  default     = null
}

variable "instance_class" {
  description = "The instance class to use for the Neptune instances (e.g., db.r5.large, db.serverless)."
  type        = string
  default     = "db.serverless"
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

variable "ingress_security_group_ids" {
  description = "(Optional) List of security group IDs allowed inbound access to Neptune. Used in addition to cidr_blocks on the managed security group."
  type        = list(string)
  default     = []
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

variable "security_group_egress_rules" {
  description = "List of egress rules for the Neptune security group. Defaults to allowing HTTPS (443) outbound to 0.0.0.0/0."
  type = list(object({
    description      = string
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = optional(list(string), null)
    security_groups  = optional(list(string), null)
    prefix_list_ids  = optional(list(string), null)
    ipv6_cidr_blocks = optional(list(string), null)
  }))
  default = [
    {
      description     = "HTTPS outbound for AWS service connectivity"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = null
    }
  ]
}

variable "neptune_security_group_tags" {
  description = "Tags for the Neptune security group"
  type        = map(string)
  default     = {}
}

variable "neptune_subnet_cidrs" {
  description = "CIDR blocks allowed to reach the Neptune port. Used for the ingress rule on the managed security group."
  type        = list(string)
  default     = []
}

variable "neptune_subnet_group_name" {
  description = "(Optional) Name of an existing Neptune subnet group to use when create_neptune_subnet_group = false."
  type        = string
  default     = null
}

variable "neptune_subnet_group_tags" {
  description = "Tags for the Neptune subnet group"
  type        = map(string)
  default     = {}
}

variable "port" {
  description = "(Optional) The port on which the Neptune accepts connections."
  type        = number
  default     = 8182
}

variable "preferred_backup_window" {
  description = "The daily time range during which automated backups are created"
  type        = string
  default     = "07:00-09:00"
}

variable "preferred_maintenance_window" {
  description = "(Optional) The weekly time range during which system maintenance can occur, in UTC, e.g., 'wed:04:00-wed:04:30'."
  type        = string
  default     = null
}

variable "read_replica_count" {
  description = "Number of read replicas to create."
  type        = number
  default     = 0
}

variable "replica_identifier_prefix" {
  description = "(Optional) A prefix for read replica identifiers. Replicas will be named '<prefix>-0', '<prefix>-1', etc. If omitted, Terraform will assign random, unique identifiers."
  type        = string
  default     = null
}

variable "replication_source_identifier" {
  description = "(Optional) ARN of a source Neptune cluster or Neptune instance if this Neptune cluster is to be created as a Read Replica."
  type        = string
  default     = null
}

variable "skip_final_snapshot" {
  description = "Determines whether a final Neptune snapshot is created before deletion"
  type        = bool
  default     = false
}

variable "snapshot_identifier" {
  description = "(Optional) Specifies whether or not to create this cluster from a snapshot."
  type        = string
  default     = null
}

variable "storage_encrypted" {
  description = "(Optional) Specifies whether the Neptune cluster is encrypted."
  type        = bool
  default     = true
}

variable "storage_type" {
  description = "(Optional) Storage type associated with the cluster (standard or iopt1). Default: standard"
  type        = string
  default     = "standard"
}

variable "subnet_ids" {
  description = "A list of subnet IDs to associate with the Neptune cluster"
  type        = list(string)
  default     = null
}

variable "subnet_name_filters" {
  description = "When subnet_ids = null, you can filter subnets by tags instead of supplying IDs."
  type        = map(list(string))
  default     = {}
}

variable "tags" {
  description = "A map of tags to assign to the Neptune cluster"
  type        = map(string)
  default     = {}
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

variable "publicly_accessible" {
  description = "(Optional) Bool to control if Neptune cluster instances are publicly accessible. Requires instances to be in a public subnet with an internet gateway."
  type        = bool
  default     = false
}

variable "public_cidr_blocks" {
  description = "(Optional) List of public CIDR blocks allowed inbound/outbound Neptune traffic when publicly_accessible = true. Only used when create_neptune_security_group = true."
  type        = list(string)
  default     = []
}
