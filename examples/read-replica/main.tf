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
# Primary Neptune Cluster (us-east-1)
########################################

module "neptune_primary" {
  source  = "dstrates/neptune/aws"
  version = "0.1.2"

  providers = {
    aws = aws.primary
  }

  cluster_identifier                     = "primary-neptune-cluster"
  create_neptune_cluster                 = true
  create_neptune_subnet_group            = true
  create_neptune_cluster_parameter_group = true
  create_neptune_instance                = true
  engine_version                         = "1.2.0.1"
  apply_immediately                      = true
  backup_retention_period                = 5
  skip_final_snapshot                    = true
  iam_database_authentication_enabled    = true
  kms_key_arn                            = data.aws_kms_key.primary.arn
  enable_serverless                      = true
  min_capacity                           = 2.5
  max_capacity                           = 128
  subnet_ids                             = data.aws_subnets.primary_db.ids
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
    Name        = "primary-neptune"
    Environment = "prod"
  }
}

########################################
# Read-Replica Neptune Cluster (us-west-2)
########################################

module "neptune_replica" {
  source  = "dstrates/neptune/aws"
  version = "0.1.2"

  providers = {
    aws = aws.secondary
  }

  create_neptune_cluster                 = true
  create_neptune_subnet_group            = true
  create_neptune_instance                = true
  create_neptune_cluster_parameter_group = false
  create_neptune_parameter_group         = false

  replication_source_identifier       = module.neptune_primary.aws_neptune_cluster_arn
  cluster_identifier                  = "replica-neptune-cluster"
  engine_version                      = "1.2.0.1"
  apply_immediately                   = true
  skip_final_snapshot                 = true
  iam_database_authentication_enabled = true
  kms_key_arn                         = data.aws_kms_key.secondary.arn
  enable_serverless                   = true
  min_capacity                        = 2.5
  max_capacity                        = 128
  subnet_ids                          = data.aws_subnets.secondary_db.ids
  instance_class                      = "db.serverless"

  tags = {
    Name        = "replica-neptune"
    Environment = "prod"
  }
}

########################################
# Outputs
########################################

output "primary_neptune_cluster_endpoint" {
  value = module.neptune_primary.aws_neptune_cluster_endpoint
}

output "primary_neptune_cluster_id" {
  value = module.neptune_primary.aws_neptune_cluster_id
}

output "replica_neptune_cluster_endpoint" {
  value = module.neptune_replica.aws_neptune_cluster_endpoint
}

output "replica_neptune_cluster_id" {
  value = module.neptune_replica.aws_neptune_cluster_id
}
