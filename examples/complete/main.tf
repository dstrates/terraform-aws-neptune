module "neptune" {
  source = "../../modules/terraform-aws-neptune"

  apply_immediately                      = true
  backup_retention_period                = 5
  cluster_identifier                     = "neptune-db-dev-use2"
  create_neptune_cluster                 = true
  create_neptune_cluster_parameter_group = true
  create_neptune_instance                = true
  create_neptune_subnet_group            = true
  enable_serverless                      = true
  engine_version                         = "1.2.0.1" # Neptune Serverless
  iam_database_authentication_enabled    = true
  kms_key_arn                            = data.aws_kms_key.default.arn
  max_capacity                           = 128
  min_capacity                           = 2.5
  preferred_backup_window                = "07:00-09:00"
  skip_final_snapshot                    = true
  subnet_ids                             = data.aws_subnets.db.ids

  neptune_cluster_parameters = {
    parameter1 = {
      key   = "neptune_enable_audit_log"
      value = "1"
    }
  }

  neptune_db_parameters = {
    parameter1 = {
      key   = "neptune_query_timeout"
      value = "25"
    }
  }

  event_subscriptions = {
    "subscription1" = "arn:aws:sns:us-east-1:123456789012:topic1"
    "subscription2" = "arn:aws:sns:us-east-1:123456789012:topic2"
  }

  tags = {
    Name        = "neptune-db-dev-use2"
    Environment = "dev"
  }
}
