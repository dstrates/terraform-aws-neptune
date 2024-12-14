data "aws_region" "current" {}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_kms_key" "default" {
  key_id = "alias/my-key"
}

data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = ["my-vpc"]
  }
}

data "aws_subnets" "db" {
  filter {
    name   = "tag:Tier"
    values = ["db"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
}
