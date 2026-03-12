locals {
  name = "neptune-test-${var.suffix}"
}

module "neptune" {
  source = "../../"

  cluster_identifier = local.name

  subnet_ids                    = var.subnet_ids
  vpc_id                        = var.vpc_id
  neptune_subnet_cidrs          = var.neptune_subnet_cidrs
  create_neptune_security_group = var.create_neptune_security_group
  vpc_security_group_ids        = var.vpc_security_group_ids

  engine_version          = var.engine_version
  enable_serverless       = var.enable_serverless
  instance_class          = var.instance_class
  min_capacity            = var.min_capacity
  max_capacity            = var.max_capacity
  create_neptune_instance = var.create_neptune_instance
  read_replica_count      = var.read_replica_count

  create_neptune_iam_role             = var.create_neptune_iam_role
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  create_neptune_cluster_parameter_group = var.create_neptune_cluster_parameter_group
  create_neptune_parameter_group         = var.create_neptune_parameter_group
  neptune_family                         = var.neptune_family
  neptune_cluster_parameters             = var.neptune_cluster_parameters
  neptune_db_parameters                  = var.neptune_db_parameters

  create_neptune_cluster_snapshot = var.create_neptune_cluster_snapshot
  skip_final_snapshot             = true

  publicly_accessible = var.publicly_accessible
  public_cidr_blocks  = var.public_cidr_blocks

  create_neptune_subnet_group = var.create_neptune_subnet_group

  storage_encrypted = var.storage_encrypted
  storage_type      = var.storage_type

  backup_retention_period = var.backup_retention_period
  deletion_protection     = false
  apply_immediately       = true

  tags = merge(
    {
      ManagedBy   = "terratest"
      ClusterName = local.name
    },
    var.tags
  )
}
