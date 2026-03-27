######################
# Neptune cluster
######################

resource "aws_neptune_cluster" "this" {
  count = var.create_neptune_cluster ? 1 : 0

  # Core configuration
  cluster_identifier          = var.cluster_identifier
  cluster_identifier_prefix   = var.cluster_identifier_prefix
  engine                      = "neptune"
  engine_version              = var.engine_version
  port                        = var.port
  storage_encrypted           = var.storage_encrypted
  storage_type                = var.storage_type
  deletion_protection         = var.deletion_protection
  apply_immediately           = var.apply_immediately
  allow_major_version_upgrade = var.allow_major_version_upgrade
  backup_retention_period     = var.backup_retention_period

  # Optional references
  neptune_cluster_parameter_group_name = try(aws_neptune_cluster_parameter_group.this[0].name, null)
  neptune_subnet_group_name            = coalesce(try(aws_neptune_subnet_group.this[0].name, null), var.neptune_subnet_group_name)
  kms_key_arn                          = var.kms_key_arn
  iam_database_authentication_enabled  = var.iam_database_authentication_enabled
  iam_roles                            = var.create_neptune_iam_role ? concat([aws_iam_role.this[0].arn], coalesce(var.iam_roles, [])) : var.iam_roles
  availability_zones                   = var.availability_zones
  copy_tags_to_snapshot                = var.copy_tags_to_snapshot
  final_snapshot_identifier            = var.final_snapshot_identifier
  global_cluster_identifier            = var.global_cluster_identifier
  replication_source_identifier        = var.replication_source_identifier
  snapshot_identifier                  = var.snapshot_identifier
  preferred_backup_window              = var.preferred_backup_window
  preferred_maintenance_window         = var.preferred_maintenance_window

  # CloudWatch logs
  enable_cloudwatch_logs_exports = var.enable_cloudwatch_logs_exports

  # Serverless configuration
  dynamic "serverless_v2_scaling_configuration" {
    for_each = var.enable_serverless ? [1] : []
    content {
      min_capacity = var.min_capacity
      max_capacity = var.max_capacity
    }
  }

  skip_final_snapshot    = var.skip_final_snapshot
  vpc_security_group_ids = var.create_neptune_security_group ? concat([aws_security_group.this[0].id], coalesce(var.vpc_security_group_ids, [])) : var.vpc_security_group_ids
  tags                   = var.tags

  lifecycle {
    precondition {
      condition     = var.create_neptune_subnet_group || var.neptune_subnet_group_name != null
      error_message = "When create_neptune_subnet_group = false, neptune_subnet_group_name must be provided."
    }
    precondition {
      condition     = !var.enable_serverless || var.instance_class == "db.serverless"
      error_message = "Serverless clusters must use instance_class = \"db.serverless\"."
    }
    precondition {
      condition     = var.skip_final_snapshot || var.final_snapshot_identifier != null
      error_message = "When skip_final_snapshot = false, you must provide final_snapshot_identifier."
    }
  }
}

######################
# Neptune Global Cluster
######################

resource "aws_neptune_global_cluster" "this" {
  count = var.create_neptune_global_cluster ? 1 : 0

  global_cluster_identifier    = var.global_cluster_identifier
  engine                       = var.global_cluster_engine
  engine_version               = var.global_cluster_engine_version
  deletion_protection          = var.global_cluster_deletion_protection
  source_db_cluster_identifier = var.global_cluster_source_db_cluster_identifier
  storage_encrypted            = var.global_cluster_storage_encrypted
}

######################
# Primary Cluster instance
######################

resource "aws_neptune_cluster_instance" "primary" {
  count = var.create_neptune_instance ? 1 : 0

  identifier                   = var.instance_identifier
  cluster_identifier           = aws_neptune_cluster.this[0].cluster_identifier
  instance_class               = var.instance_class
  neptune_parameter_group_name = try(aws_neptune_parameter_group.this[0].name, null)
  neptune_subnet_group_name    = coalesce(try(aws_neptune_subnet_group.this[0].name, null), var.neptune_subnet_group_name)
  publicly_accessible          = var.publicly_accessible

  apply_immediately            = var.instance_apply_immediately
  auto_minor_version_upgrade   = var.instance_auto_minor_version_upgrade
  availability_zone            = var.primary_instance_availability_zone
  promotion_tier               = var.primary_instance_promotion_tier
  preferred_maintenance_window = var.instance_preferred_maintenance_window

  tags = merge(var.tags, var.neptune_cluster_instance_tags)

  lifecycle {
    precondition {
      condition     = var.create_neptune_cluster
      error_message = "create_neptune_instance requires create_neptune_cluster = true."
    }
    precondition {
      condition     = var.publicly_accessible || var.create_neptune_subnet_group || var.neptune_subnet_group_name != null
      error_message = "neptune_subnet_group_name is required on cluster instances when publicly_accessible = false. Set create_neptune_subnet_group = true or provide neptune_subnet_group_name."
    }
  }
}

######################
# Read Replica Instances
######################

resource "aws_neptune_cluster_instance" "read_replicas" {
  count = var.create_neptune_instance ? var.read_replica_count : 0

  identifier                   = var.replica_identifier_prefix != null ? "${var.replica_identifier_prefix}-${count.index}" : null
  cluster_identifier           = aws_neptune_cluster.this[0].cluster_identifier
  instance_class               = var.instance_class
  neptune_parameter_group_name = try(aws_neptune_parameter_group.this[0].name, null)
  neptune_subnet_group_name    = coalesce(try(aws_neptune_subnet_group.this[0].name, null), var.neptune_subnet_group_name)
  publicly_accessible          = var.publicly_accessible

  apply_immediately = try(
    var.read_replica_configs[count.index].apply_immediately,
    var.instance_apply_immediately
  )
  auto_minor_version_upgrade = try(
    var.read_replica_configs[count.index].auto_minor_version_upgrade,
    var.instance_auto_minor_version_upgrade
  )
  availability_zone = try(
    var.read_replica_configs[count.index].availability_zone,
    null
  )
  promotion_tier = try(
    var.read_replica_configs[count.index].promotion_tier,
    1 + count.index
  )
  preferred_maintenance_window = try(
    var.read_replica_configs[count.index].preferred_maintenance_window,
    var.instance_preferred_maintenance_window
  )

  tags = merge(var.tags, var.neptune_cluster_instance_tags)

  lifecycle {
    precondition {
      condition     = var.create_neptune_cluster
      error_message = "create_neptune_instance requires create_neptune_cluster = true."
    }
    precondition {
      condition     = var.publicly_accessible || var.create_neptune_subnet_group || var.neptune_subnet_group_name != null
      error_message = "neptune_subnet_group_name is required on cluster instances when publicly_accessible = false. Set create_neptune_subnet_group = true or provide neptune_subnet_group_name."
    }
  }
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

  db_cluster_snapshot_identifier = var.create_neptune_cluster ? coalesce(var.db_cluster_snapshot_identifier, format("%s-%s", aws_neptune_cluster.this[0].id, random_id.snapshot_suffix[0].hex)) : var.db_cluster_snapshot_identifier

  lifecycle {
    precondition {
      condition     = var.create_neptune_cluster || var.db_cluster_snapshot_identifier != null
      error_message = "When create_neptune_cluster = false, db_cluster_snapshot_identifier must be provided."
    }
  }

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

  name        = "cluster-parameter-group-${local.name_prefix}"
  description = "Neptune Cluster Parameter Group"
  family      = var.neptune_family

  dynamic "parameter" {
    for_each = var.neptune_cluster_parameters
    content {
      name  = parameter.value.key
      value = parameter.value.value
    }
  }

  tags = merge(var.tags, var.neptune_cluster_parameter_group_tags)
}

resource "aws_neptune_parameter_group" "this" {
  count = var.create_neptune_parameter_group ? 1 : 0

  name        = "parameter-group-${local.name_prefix}"
  description = "Neptune DB Parameter Group"
  family      = var.neptune_family

  dynamic "parameter" {
    for_each = var.neptune_db_parameters
    content {
      name  = parameter.value.key
      value = parameter.value.value
    }
  }

  tags = merge(var.tags, var.neptune_parameter_group_tags)
}

######################
# Subnet groups
######################

locals {
  subnet_ids_resolved = coalesce(var.subnet_ids, [])
  networking = {
    final_ids = length(local.subnet_ids_resolved) > 0 ? (
      local.subnet_ids_resolved
      ) : (
      length(data.aws_subnets.filtered) > 0 ? data.aws_subnets.filtered[0].ids : []
    )
  }
  name_prefix   = coalesce(var.cluster_identifier, var.cluster_identifier_prefix, "neptune")
  ingress_cidrs = var.publicly_accessible ? concat(var.neptune_subnet_cidrs, var.public_cidr_blocks) : var.neptune_subnet_cidrs

  effective_ingress_rules = var.security_group_ingress_rules != null ? var.security_group_ingress_rules : [
    {
      description      = "Inbound Neptune Traffic"
      from_port        = var.port
      to_port          = var.port
      protocol         = "tcp"
      cidr_blocks      = length(local.ingress_cidrs) > 0 ? local.ingress_cidrs : null
      security_groups  = length(var.ingress_security_group_ids) > 0 ? var.ingress_security_group_ids : null
      prefix_list_ids  = null
      ipv6_cidr_blocks = null
    }
  ]
}

data "aws_subnets" "filtered" {
  count = length(local.subnet_ids_resolved) == 0 && length(var.subnet_name_filters) > 0 ? 1 : 0

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

  name        = "subnet-group-${local.name_prefix}"
  description = "Neptune Subnet Group"
  subnet_ids  = local.networking.final_ids

  tags = merge(var.tags, var.neptune_subnet_group_tags)

  lifecycle {
    precondition {
      condition     = length(local.subnet_ids_resolved) > 0 || length(var.subnet_name_filters) > 0
      error_message = "You must provide either subnet_ids or subnet_name_filters to create a subnet group."
    }
    precondition {
      condition     = !(length(local.subnet_ids_resolved) > 0 && length(var.subnet_name_filters) > 0)
      error_message = "You must set either subnet_ids or subnet_name_filters, not both."
    }
  }
}

######################
# Event subscriptions
######################

locals {
  event_subscription_source_ids = concat(
    var.create_neptune_instance ? [aws_neptune_cluster_instance.primary[0].id] : [],
    aws_neptune_cluster_instance.read_replicas[*].id
  )
}

resource "aws_neptune_event_subscription" "this" {
  for_each = var.event_subscriptions != null && length(local.event_subscription_source_ids) > 0 ? var.event_subscriptions : {}

  name          = each.key
  sns_topic_arn = each.value
  source_type   = "db-instance"
  source_ids    = local.event_subscription_source_ids

  tags = merge(var.tags, var.neptune_event_subscription_tags)
}

######################
# Endpoints
######################

resource "aws_neptune_cluster_endpoint" "this" {
  for_each = var.create_neptune_cluster_endpoint ? var.neptune_cluster_endpoints : {}

  cluster_identifier          = aws_neptune_cluster.this[0].cluster_identifier
  cluster_endpoint_identifier = each.key
  endpoint_type               = each.value.endpoint_type

  static_members   = each.value.static_members
  excluded_members = each.value.excluded_members
  tags             = each.value.tags

  lifecycle {
    precondition {
      condition     = var.create_neptune_cluster
      error_message = "create_neptune_cluster_endpoint requires create_neptune_cluster = true."
    }
  }
}

######################
# Security group
######################

resource "aws_security_group" "this" {
  count = var.create_neptune_security_group ? 1 : 0

  name        = "neptune-sg-${local.name_prefix}"
  description = "Neptune security group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.effective_ingress_rules
    content {
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      security_groups  = ingress.value.security_groups
      prefix_list_ids  = ingress.value.prefix_list_ids
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.security_group_egress_rules
    content {
      description      = egress.value.description
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = egress.value.cidr_blocks
      security_groups  = egress.value.security_groups
      prefix_list_ids  = egress.value.prefix_list_ids
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
    }
  }

  tags = merge(var.tags, var.neptune_security_group_tags)

  lifecycle {
    precondition {
      condition = (
        var.security_group_ingress_rules != null ||
        length(var.neptune_subnet_cidrs) > 0 ||
        length(var.ingress_security_group_ids) > 0
      )
      error_message = "You must provide at least one of security_group_ingress_rules, neptune_subnet_cidrs, or ingress_security_group_ids."
    }
  }
}

######################
# IAM role
######################

data "aws_iam_policy_document" "this" {
  count = var.create_neptune_iam_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

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

  tags = merge({ "Name" = var.neptune_role_name }, var.tags)
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.create_neptune_iam_role ? toset(var.iam_role_policies) : toset([])

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
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
