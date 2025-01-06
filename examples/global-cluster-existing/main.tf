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
}

########################################
# Data Sources
########################################

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = ["my-vpc"]
  }
}

data "aws_subnets" "db_subnets" {
  filter {
    name   = "tag:Tier"
    values = ["db"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
}

data "aws_kms_key" "default" {
  key_id = "alias/my-default-kms-key"
}

########################################
# Create a Global cluster from existing DB cluster
########################################

# Assuming you have an existing standard Neptune cluster
module "neptune_existing_cluster" {
  source  = "dstrates/neptune/aws"
  version = "0.1.2"

  create_neptune_cluster                 = true
  create_neptune_subnet_group            = true
  create_neptune_cluster_parameter_group = true
  create_neptune_instance                = true
  engine_version                         = "1.2.0.1"
  apply_immediately                      = true
  backup_retention_period                = 5
  skip_final_snapshot                    = true
  iam_database_authentication_enabled    = true
  kms_key_arn                            = data.aws_kms_key.default.arn
  enable_serverless                      = true
  min_capacity                           = 2.5
  max_capacity                           = 128
  subnet_ids                             = data.aws_subnets.db_subnets.ids
  cluster_identifier                     = "existing-neptune-cluster"
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
    Name        = "existing-neptune-cluster"
    Environment = "dev"
  }
}

# Create a global cluster referencing that cluster
module "neptune_global_cluster" {
  source  = "dstrates/neptune/aws"
  version = "0.1.2"

  create_neptune_global_cluster               = true
  global_cluster_engine                       = "neptune"
  global_cluster_engine_version               = "1.2.0.1"
  global_cluster_identifier                   = "my-global-neptune-cluster"
  global_cluster_source_db_cluster_identifier = module.neptune_existing_cluster.aws_neptune_cluster_arn
}

########################################
# Outputs
########################################

output "existing_cluster_id" {
  description = "ID of the existing Neptune cluster"
  value       = module.neptune_existing_cluster.aws_neptune_cluster_id
}

output "existing_cluster_endpoint" {
  description = "Endpoint of the existing Neptune cluster"
  value       = module.neptune_existing_cluster.aws_neptune_cluster_endpoint
}

output "global_cluster_id" {
  description = "ID of the newly created global Neptune cluster"
  value       = aws_neptune_global_cluster.this.id
}
