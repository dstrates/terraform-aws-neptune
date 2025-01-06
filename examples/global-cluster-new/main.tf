########################################
# Providers
########################################

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}


provider "aws" {
  region = "us-east-1"
  alias  = "primary"
}

provider "aws" {
  region = "us-west-2"
  alias  = "secondary"
}

########################################
# Data Sources
########################################

# Primary region data
data "aws_region" "primary" {
  provider = aws.primary
}

data "aws_vpc" "primary" {
  provider = aws.primary
  filter {
    name   = "tag:Name"
    values = ["my-primary-vpc"]
  }
}

data "aws_subnets" "primary_db" {
  provider = aws.primary
  filter {
    name   = "tag:Tier"
    values = ["db"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.primary.id]
  }
}

data "aws_kms_key" "primary" {
  provider = aws.primary
  key_id   = "alias/my-primary-kms-key"
}

# Secondary region data
data "aws_region" "secondary" {
  provider = aws.secondary
}

data "aws_vpc" "secondary" {
  provider = aws.secondary
  filter {
    name   = "tag:Name"
    values = ["my-secondary-vpc"]
  }
}

data "aws_subnets" "secondary_db" {
  provider = aws.secondary
  filter {
    name   = "tag:Tier"
    values = ["db"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.secondary.id]
  }
}

data "aws_kms_key" "secondary" {
  provider = aws.secondary
  key_id   = "alias/my-secondary-kms-key"
}

########################################
# Primary Neptune Global Cluster + Cluster (us-east-1)
########################################

module "neptune_global_primary" {
  source  = "dstrates/neptune/aws"
  version = "0.1.2"

  providers = {
    aws = aws.primary
  }

  # Global Cluster Configuration
  create_neptune_global_cluster = true
  global_cluster_identifier     = "global-neptune-db"
  global_cluster_engine         = "neptune"
  global_cluster_engine_version = "1.2.0.1"

  # Primary Cluster Configuration
  create_neptune_cluster                 = true
  create_neptune_subnet_group            = true
  create_neptune_cluster_parameter_group = true
  create_neptune_instance                = true
  enable_serverless                      = true
  engine_version                         = "1.2.0.1"
  iam_database_authentication_enabled    = true
  apply_immediately                      = true
  backup_retention_period                = 5
  preferred_backup_window                = "07:00-09:00"
  preferred_maintenance_window           = "sun:06:00-sun:10:00"
  skip_final_snapshot                    = true
  copy_tags_to_snapshot                  = true
  kms_key_arn                            = data.aws_kms_key.primary.arn
  min_capacity                           = 2.5
  max_capacity                           = 128
  subnet_ids                             = data.aws_subnets.primary_db.ids
  cluster_identifier                     = "neptune-db-primary-use1"
  instance_class                         = "db.serverless"

  neptune_cluster_parameters = {
    audit = {
      key   = "neptune_enable_audit_log"
      value = "1"
    }
  }

  neptune_db_parameters = {
    timeout = {
      key   = "neptune_query_timeout"
      value = "25"
    }
  }

  tags = {
    Name        = "global-primary-neptune"
    Environment = "dev"
  }
}

########################################
# Secondary Neptune Global Cluster Member (us-west-2)
########################################

module "neptune_global_secondary" {
  source  = "dstrates/neptune/aws"
  version = "0.1.2"

  providers = {
    aws = aws.secondary
  }

  # Since this cluster will join the global cluster, we do not recreate it here
  # We just create a cluster that references the global cluster identifier
  create_neptune_global_cluster = false
  global_cluster_identifier     = "global-neptune-db"

  # Create secondary cluster as a member of the global cluster
  create_neptune_cluster                 = true
  create_neptune_subnet_group            = true
  create_neptune_instance                = true
  create_neptune_cluster_parameter_group = false
  create_neptune_parameter_group         = false

  # The replication_source_identifier is not needed for global clusters.
  # Instead, we rely on the global cluster identifier to attach this cluster.
  # Just ensure the global_cluster_identifier above matches the primary's global cluster.

  # For a global cluster secondary, engine version and other settings must match primary
  engine_version                      = "1.2.0.1"
  enable_serverless                   = true
  iam_database_authentication_enabled = true
  apply_immediately                   = true
  skip_final_snapshot                 = true
  kms_key_arn                         = data.aws_kms_key.secondary.arn
  min_capacity                        = 2.5
  max_capacity                        = 128
  subnet_ids                          = data.aws_subnets.secondary_db.ids
  cluster_identifier                  = "neptune-db-secondary-usw2"
  instance_class                      = "db.serverless"

  tags = {
    Name        = "global-secondary-neptune"
    Environment = "dev"
  }
}

########################################
# Outputs
########################################

output "primary_neptune_cluster_endpoint" {
  description = "Endpoint of the primary Neptune cluster"
  value       = module.neptune_global_primary.aws_neptune_cluster_endpoint
}

output "primary_neptune_cluster_id" {
  description = "ID of the primary Neptune cluster"
  value       = module.neptune_global_primary.aws_neptune_cluster_id
}

output "global_cluster_id" {
  description = "ID of the global Neptune cluster"
  value       = module.neptune_global_primary.neptune_global_cluster_id
}

output "secondary_neptune_cluster_endpoint" {
  description = "Endpoint of the secondary Neptune cluster"
  value       = module.neptune_global_secondary.aws_neptune_cluster_endpoint
}

output "secondary_neptune_cluster_id" {
  description = "ID of the secondary Neptune cluster"
  value       = module.neptune_global_secondary.aws_neptune_cluster_id
}
