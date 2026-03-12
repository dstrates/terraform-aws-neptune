variable "suffix" {
  description = "Unique suffix appended to all resource names to avoid collisions between test runs."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "aws_skip_credentials_validation" {
  description = "When true, skips AWS credential validation and metadata API checks. Set to true for plan-only validation tests that run without real credentials."
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "Subnet IDs for the Neptune subnet group."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for the Neptune security group."
  type        = string
  default     = null
}

variable "neptune_subnet_cidrs" {
  description = "CIDR blocks allowed to reach the Neptune port."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "create_neptune_security_group" {
  type    = bool
  default = true
}

variable "vpc_security_group_ids" {
  type    = list(string)
  default = null
}

variable "engine_version" {
  type    = string
  default = "1.3.0.0"
}

variable "enable_serverless" {
  type    = bool
  default = true
}

variable "instance_class" {
  type    = string
  default = "db.serverless"
}

variable "min_capacity" {
  type    = number
  default = 2.5
}

variable "max_capacity" {
  type    = number
  default = 8
}

variable "create_neptune_instance" {
  type    = bool
  default = true
}

variable "read_replica_count" {
  type    = number
  default = 0
}

variable "create_neptune_iam_role" {
  type    = bool
  default = true
}

variable "iam_database_authentication_enabled" {
  type    = bool
  default = true
}

variable "create_neptune_cluster_parameter_group" {
  type    = bool
  default = true
}

variable "create_neptune_parameter_group" {
  type    = bool
  default = true
}

variable "neptune_family" {
  type    = string
  default = "neptune1.3"
}

variable "neptune_cluster_parameters" {
  type = map(object({
    key   = string
    value = string
  }))
  default = {}
}

variable "neptune_db_parameters" {
  type = map(object({
    key   = string
    value = string
  }))
  default = {}
}

variable "create_neptune_cluster_snapshot" {
  type    = bool
  default = false
}

variable "storage_encrypted" {
  type    = bool
  default = true
}

variable "storage_type" {
  type    = string
  default = "standard"
}

variable "backup_retention_period" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
