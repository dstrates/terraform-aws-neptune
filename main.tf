data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

######################
# Neptune cluster
######################

resource "aws_neptune_cluster" "this" {
  count = var.create_neptune_cluster ? 1 : 0

  # Core configuration
  cluster_identifier          = try(var.cluster_identifier, null)
  cluster_identifier_prefix   = try(var.cluster_identifier_prefix, null)
  engine                      = "neptune"
  engine_version              = var.engine_version
  port                        = try(var.port, 8182)
  storage_encrypted           = try(var.storage_encrypted, null)
  storage_type                = try(var.storage_type, "standard")
  deletion_protection         = try(var.deletion_protection, null)
  apply_immediately           = try(var.apply_immediately, null)
  allow_major_version_upgrade = try(var.allow_major_version_upgrade, null)
  backup_retention_period     = try(var.backup_retention_period, null)

  # Optional references
  neptune_cluster_parameter_group_name = try(aws_neptune_cluster_parameter_group.this[0].name, null)
  neptune_subnet_group_name            = try(aws_neptune_subnet_group.this[0].name, null)
  kms_key_arn                          = try(var.kms_key_arn, null)
  iam_database_authentication_enabled  = try(var.iam_database_authentication_enabled, null)
  iam_roles                            = try([aws_iam_role.this[0].arn], var.iam_roles)
  availability_zones                   = try(var.availability_zones, null)
  copy_tags_to_snapshot                = try(var.copy_tags_to_snapshot, null)
  final_snapshot_identifier            = try(var.final_snapshot_identifier, null)
  global_cluster_identifier            = try(var.global_cluster_identifier, null)
  replication_source_identifier        = try(var.replication_source_identifier, null)
  snapshot_identifier                  = try(var.snapshot_identifier, null)
  preferred_backup_window              = try(var.preferred_backup_window, null)
  preferred_maintenance_window         = try(var.preferred_maintenance_window, null)

  # CloudWatch logs
  enable_cloudwatch_logs_exports = try(var.enable_cloudwatch_logs_exports, null)

  # Serverless configuration
  dynamic "serverless_v2_scaling_configuration" {
    for_each = var.enable_serverless ? [1] : []
    content {
      min_capacity = var.min_capacity
      max_capacity = var.max_capacity
    }
  }

  # Skipping final snapshot if needed
  skip_final_snapshot = try(var.skip_final_snapshot, null)

  # Security groups
  vpc_security_group_ids = try([aws_security_group.this[0].id], var.vpc_security_group_ids)

  tags = try(var.tags, null)
}

######################
# Neptune Global Cluster
######################

resource "aws_neptune_global_cluster" "this" {
  count = var.create_neptune_global_cluster ? 1 : 0

  global_cluster_identifier    = var.global_cluster_identifier
  engine                       = try(var.global_cluster_engine, null)
  engine_version               = try(var.global_cluster_engine_version, null)
  deletion_protection          = try(var.global_cluster_deletion_protection, null)
  source_db_cluster_identifier = try(var.global_cluster_source_db_cluster_identifier, null)
  storage_encrypted            = try(var.global_cluster_storage_encrypted, null)
}

######################
# Primary Cluster instance
######################

resource "aws_neptune_cluster_instance" "primary" {
  count = var.create_neptune_instance ? 1 : 0

  cluster_identifier           = aws_neptune_cluster.this[0].cluster_identifier
  instance_class               = var.instance_class
  neptune_parameter_group_name = try(aws_neptune_parameter_group.this[0].name, null)
  neptune_subnet_group_name    = try(aws_neptune_subnet_group.this[0].name, null)

  tags = merge(
    try(var.tags, {}),
    try(var.neptune_cluster_instance_tags, {})
  )
}

######################
# Read Replica Instances
######################

resource "aws_neptune_cluster_instance" "read_replicas" {
  count = var.read_replica_count

  cluster_identifier           = aws_neptune_cluster.this[0].cluster_identifier
  instance_class               = var.instance_class
  neptune_parameter_group_name = try(aws_neptune_parameter_group.this[0].name, null)
  neptune_subnet_group_name    = try(aws_neptune_subnet_group.this[0].name, null)

  tags = merge(
    try(var.tags, {}),
    try(var.neptune_cluster_instance_tags, {})
  )
}

######################
# Cluster snapshot
######################

resource "aws_neptune_cluster_snapshot" "this" {
  count = var.create_neptune_cluster_snapshot ? 1 : 0

  db_cluster_identifier = (var.create_neptune_cluster
    ? aws_neptune_cluster.this[0].id
    : var.db_cluster_identifier
  )

  db_cluster_snapshot_identifier = coalesce(
    var.db_cluster_snapshot_identifier,
    format("%s-%s",
      aws_neptune_cluster.this[0].id,
      random_id.snapshot_suffix[0].hex
    )
  )

  dynamic "timeouts" {
    for_each = var.db_cluster_identifier != null ? [1] : []
    content {
      create = var.create_timeout
    }
  }
}

######################
# Parameter groups
######################

resource "aws_neptune_cluster_parameter_group" "this" {
  count = var.create_neptune_cluster_parameter_group ? 1 : 0

  name        = "cluster-parameter-group-${var.cluster_identifier}"
  description = "Neptune Cluster Parameter Group"
  family      = var.neptune_family

  dynamic "parameter" {
    for_each = var.neptune_cluster_parameters
    content {
      name  = parameter.value.key
      value = parameter.value.value
    }
  }

  tags = merge(
    try(var.tags, {}),
    try(var.neptune_cluster_parameter_group_tags, {})
  )
}

resource "aws_neptune_parameter_group" "this" {
  count = var.create_neptune_parameter_group ? 1 : 0

  name        = "parameter-group-${var.cluster_identifier}"
  description = "Neptune DB Parameter Group"
  family      = var.neptune_family

  dynamic "parameter" {
    for_each = var.neptune_db_parameters
    content {
      name  = parameter.value.key
      value = parameter.value.value
    }
  }

  tags = merge(
    try(var.tags, {}),
    try(var.neptune_parameter_group_tags, {})
  )
}

######################
# Subnet groups
######################

locals {
  networking = {
    final_ids = length(var.subnet_ids) > 0 ? (
      var.subnet_ids
      ) : (
      data.aws_subnets.filtered[0].ids
    )
  }
}

data "aws_subnets" "filtered" {
  count = length(var.subnet_ids) == 0 ? 1 : 0

  dynamic "filter" {
    for_each = var.subnet_name_filters
    content {
      name   = filter.key
      values = filter.value
    }
  }
}

resource "aws_neptune_subnet_group" "this" {
  count = var.create_neptune_subnet_group ? 1 : 0

  name        = "subnet-group-${var.cluster_identifier}"
  description = "Neptune Subnet Group"
  subnet_ids  = local.networking.final_ids

  tags = merge(
    try(var.tags, {}),
    try(var.neptune_subnet_group_tags, {})
  )
}

######################
# Event subscriptions
######################

resource "aws_neptune_event_subscription" "this" {
  for_each = var.event_subscriptions != null ? var.event_subscriptions : {}

  name          = each.key
  sns_topic_arn = each.value
  source_type   = var.event_subscriptions != null ? "db-instance" : null
  source_ids    = var.create_neptune_instance ? [aws_neptune_cluster_instance.primary[0].id] : []

  tags = merge(
    try(var.tags, {}),
    try(var.neptune_event_subscription_tags, {})
  )
}

######################
# Endpoints
######################

resource "aws_neptune_cluster_endpoint" "this" {
  for_each = var.create_neptune_cluster_endpoint ? { for idx, endpoint in var.neptune_cluster_endpoints : idx => endpoint } : {}

  cluster_identifier          = aws_neptune_cluster.this[0].cluster_identifier
  cluster_endpoint_identifier = each.key
  endpoint_type               = each.value.endpoint_type

  static_members   = each.value.static_members
  excluded_members = each.value.excluded_members
  tags             = each.value.tags
}

######################
# Security group
######################

resource "aws_security_group" "this" {
  count = var.create_neptune_security_group ? 1 : 0

  name        = "neptune-sg-${var.cluster_identifier}"
  description = "Neptune security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Inbound Neptune Traffic"
    from_port   = var.neptune_port
    to_port     = var.neptune_port
    protocol    = "tcp"
    cidr_blocks = var.neptune_subnet_cidrs
  }

  egress {
    description = "Outbound Neptune Traffic"
    from_port   = var.neptune_port
    to_port     = var.neptune_port
    protocol    = "tcp"
    cidr_blocks = var.neptune_subnet_cidrs
  }

  tags = merge(
    try(var.tags, {}),
    try(var.neptune_security_group_tags, {})
  )
}

######################
# IAM role
######################

data "aws_iam_policy_document" "this" {
  count = var.create_neptune_iam_role ? 1 : 0

  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create_neptune_iam_role ? 1 : 0

  name                 = var.neptune_role_name
  assume_role_policy   = data.aws_iam_policy_document.this[0].json
  description          = var.neptune_role_description
  permissions_boundary = var.neptune_role_permissions_boundary

  tags = merge(
    {
      "Name" = format("%s", var.neptune_role_name)
    },
    try(var.tags, {}),
  )
}

resource "aws_iam_role_policy_attachment" "this" {
  count = var.create_neptune_iam_role ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/ROSAKMSProviderPolicy"
}


######################
# Random ID
######################

resource "random_id" "snapshot_suffix" {
  count = var.create_neptune_cluster_snapshot && var.create_neptune_cluster ? 1 : 0

  keepers = {
    cluster_identifier = aws_neptune_cluster.this[0].id
  }

  byte_length = 4
}
