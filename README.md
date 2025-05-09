# Terraform AWS Neptune Module

Terraform module that creates AWS Neptune resources.

## Features

- Create and manage AWS Neptune clusters, instances & snapshots.
- Create and manage Neptune cluster parameter groups.
- Define Neptune subnet groups for cluster deployment.
- Set up Neptune event subscriptions for monitoring.
- Create custom cluster endpoints with various configurations.
- Create Global clusters and read-only replicas in secondary regions.

## Usage

Neptune serverless has some limitations. Please see the [limitations](https://docs.aws.amazon.com/neptune/latest/userguide/neptune-serverless.html#neptune-serverless-limitations) before jumping into Neptune Serverless.

Neptune serverless requires that the `engine_version` attribute must be `1.2.0.1` or above. Also, you need to provide a cluster parameter group compatible with the family `neptune1.2`. In the examples below, the default cluster parameter group is used.

### Standard configuration

```hcl
# main.tf

module "neptune" {
  source  = "dstrates/neptune/aws"
  version = "0.2.0"

  apply_immediately                      = true
  backup_retention_period                = 5
  cluster_identifier                     = "neptune-db-dev-use2"
  copy_tags_to_snapshot                  = true
  create_neptune_cluster                 = true
  create_neptune_cluster_parameter_group = true
  create_neptune_instance                = true
  create_neptune_subnet_group            = true
  enable_serverless                      = false
  engine_version                         = "1.2.0.0"
  iam_database_authentication_enabled    = true
  kms_key_arn                            = data.aws_kms_key.default.arn
  max_capacity                           = 128
  min_capacity                           = 2.5
  preferred_backup_window                = "07:00-09:00"
  preferred_maintenance_window           = "sun:06:00-sun:10:00"
  skip_final_snapshot                    = true
  subnet_ids                             = data.aws_subnets.db.ids
  instance_class                         = "db.r5.large"

  # lookup subnets by tag; alternative to passing in explicit `subnet_ids`
  subnet_name_filters = {
    "tag:Environment" = ["uat", "prod"]
    "tag:Name"        = ["db-subnet-*"]
  }

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
```

### Advanced endpoint configuration

```hcl
module "neptune" {
  source  = "dstrates/neptune/aws"
  version = "0.2.0"

  # Standard configuration
  # ...
  # ...

  create_neptune_cluster_endpoint     = true

  neptune_cluster_endpoints           = {
    "endpoint1" = {
      endpoint_type    = "READER"
      static_members   = ["instance-1", "instance-2"]
      excluded_members = []
      tags             = {
        Name = "Endpoint 1"
      }
    },
    "endpoint2" = {
      endpoint_type    = "WRITER"
      static_members   = []
      excluded_members = ["instance-3"]
      tags             = {
        Name = "Endpoint 2"
      }
    }
  }

  # ... (other variables as needed)
}
```

## Examples

- [Neptune Cluster Complete](https://github.com/dstrates/terraform-aws-neptune/blob/main/examples/complete/main.tf)
- [Neptune Global Cluster (New)](https://github.com/dstrates/terraform-aws-neptune/blob/main/examples/global-cluster-new/main.tf)
- [Neptune Global Cluster (Existing DB cluster)](https://github.com/dstrates/terraform-aws-neptune/blob/main/examples/global-cluster-existing/main.tf)
- [Neptune Cluster Read-Replicas](https://github.com/dstrates/terraform-aws-neptune/blob/main/examples/read-replica/main.tf)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.25 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.81.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.6.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_neptune_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_cluster) | resource |
| [aws_neptune_cluster_endpoint.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_cluster_endpoint) | resource |
| [aws_neptune_cluster_instance.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_cluster_instance) | resource |
| [aws_neptune_cluster_instance.read_replicas](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_cluster_instance) | resource |
| [aws_neptune_cluster_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_cluster_parameter_group) | resource |
| [aws_neptune_cluster_snapshot.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_cluster_snapshot) | resource |
| [aws_neptune_event_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_event_subscription) | resource |
| [aws_neptune_global_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_global_cluster) | resource |
| [aws_neptune_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_parameter_group) | resource |
| [aws_neptune_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/neptune_subnet_group) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [random_id.snapshot_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnets.filtered](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_major_version_upgrade"></a> [allow\_major\_version\_upgrade](#input\_allow\_major\_version\_upgrade) | (Optional) Specifies whether upgrades between different major versions are allowed. You must set it to true when providing an engine\_version parameter that uses a different major version than the DB cluster's current version. | `bool` | `false` | no |
| <a name="input_apply_immediately"></a> [apply\_immediately](#input\_apply\_immediately) | Specifies whether cluster modifications are applied immediately | `bool` | `true` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | (Optional) A list of EC2 Availability Zones that instances in the Neptune cluster can be created in. | `list(string)` | `null` | no |
| <a name="input_backup_retention_period"></a> [backup\_retention\_period](#input\_backup\_retention\_period) | The number of days to retain backups for | `number` | `7` | no |
| <a name="input_cluster_identifier"></a> [cluster\_identifier](#input\_cluster\_identifier) | The cluster identifier. Required if create\_neptune\_cluster is true. | `string` | `null` | no |
| <a name="input_cluster_identifier_prefix"></a> [cluster\_identifier\_prefix](#input\_cluster\_identifier\_prefix) | (Optional) Creates a unique cluster identifier beginning with the specified prefix. Conflicts with cluster\_identifier. | `string` | `null` | no |
| <a name="input_copy_tags_to_snapshot"></a> [copy\_tags\_to\_snapshot](#input\_copy\_tags\_to\_snapshot) | (Optional) If set to true, tags are copied to any snapshot of the DB cluster that is created. | `bool` | `null` | no |
| <a name="input_create_neptune_cluster"></a> [create\_neptune\_cluster](#input\_create\_neptune\_cluster) | Whether or not to create a Neptune cluster | `bool` | `true` | no |
| <a name="input_create_neptune_cluster_endpoint"></a> [create\_neptune\_cluster\_endpoint](#input\_create\_neptune\_cluster\_endpoint) | Whether or not to create Neptune cluster endpoints. | `bool` | `false` | no |
| <a name="input_create_neptune_cluster_parameter_group"></a> [create\_neptune\_cluster\_parameter\_group](#input\_create\_neptune\_cluster\_parameter\_group) | Whether or not to create a Neptune cluster parameter group | `bool` | `true` | no |
| <a name="input_create_neptune_cluster_snapshot"></a> [create\_neptune\_cluster\_snapshot](#input\_create\_neptune\_cluster\_snapshot) | Whether or not to create a Neptune cluster snapshot | `bool` | `true` | no |
| <a name="input_create_neptune_global_cluster"></a> [create\_neptune\_global\_cluster](#input\_create\_neptune\_global\_cluster) | Whether or not to create a Neptune global cluster | `bool` | `false` | no |
| <a name="input_create_neptune_iam_role"></a> [create\_neptune\_iam\_role](#input\_create\_neptune\_iam\_role) | Whether or not to create and attach a Neptune IAM role | `bool` | `true` | no |
| <a name="input_create_neptune_instance"></a> [create\_neptune\_instance](#input\_create\_neptune\_instance) | Whether or not to create Neptune instances | `bool` | `true` | no |
| <a name="input_create_neptune_parameter_group"></a> [create\_neptune\_parameter\_group](#input\_create\_neptune\_parameter\_group) | Whether or not to create a Neptune DB parameter group | `bool` | `true` | no |
| <a name="input_create_neptune_security_group"></a> [create\_neptune\_security\_group](#input\_create\_neptune\_security\_group) | Whether or not to create a Neptune security group | `bool` | `true` | no |
| <a name="input_create_neptune_subnet_group"></a> [create\_neptune\_subnet\_group](#input\_create\_neptune\_subnet\_group) | Whether or not to create a Neptune subnet group | `bool` | `true` | no |
| <a name="input_create_timeout"></a> [create\_timeout](#input\_create\_timeout) | Timeout for creating the Neptune cluster snapshot | `string` | `"20m"` | no |
| <a name="input_db_cluster_identifier"></a> [db\_cluster\_identifier](#input\_db\_cluster\_identifier) | The DB Cluster Identifier from which to take the snapshot | `string` | `null` | no |
| <a name="input_db_cluster_snapshot_identifier"></a> [db\_cluster\_snapshot\_identifier](#input\_db\_cluster\_snapshot\_identifier) | The Identifier for the snapshot | `string` | `null` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | (Optional) A value that indicates whether the DB cluster has deletion protection enabled | `bool` | `false` | no |
| <a name="input_enable_cloudwatch_logs_exports"></a> [enable\_cloudwatch\_logs\_exports](#input\_enable\_cloudwatch\_logs\_exports) | (Optional) A list of the log types this DB cluster is configured to export to Cloudwatch Logs. Currently only supports `audit` and `slowquery`. | `list(string)` | `null` | no |
| <a name="input_enable_serverless"></a> [enable\_serverless](#input\_enable\_serverless) | Whether or not to create a Serverless Neptune cluster | `bool` | `true` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | The database engine version | `string` | `"1.2.0.1"` | no |
| <a name="input_event_subscriptions"></a> [event\_subscriptions](#input\_event\_subscriptions) | Map of Neptune event subscriptions with names and SNS topic ARNs<br/><br/>Example:<br/>{<br/>  "subscription1" = "arn:aws:sns:us-east-1:123456789012:topic1",<br/>  "subscription2" = "arn:aws:sns:us-east-1:123456789012:topic2"<br/>} | `map(string)` | `null` | no |
| <a name="input_final_snapshot_identifier"></a> [final\_snapshot\_identifier](#input\_final\_snapshot\_identifier) | (Optional) The name of your final Neptune snapshot when this Neptune cluster is deleted. If omitted, no final snapshot will be made. | `string` | `null` | no |
| <a name="input_global_cluster_deletion_protection"></a> [global\_cluster\_deletion\_protection](#input\_global\_cluster\_deletion\_protection) | (Optional) Whether or not the global cluster should have deletion protection enabled. Default: false. | `bool` | `false` | no |
| <a name="input_global_cluster_engine"></a> [global\_cluster\_engine](#input\_global\_cluster\_engine) | (Optional) Name of the database engine to be used for the global cluster. Valid values: neptune. | `string` | `null` | no |
| <a name="input_global_cluster_engine_version"></a> [global\_cluster\_engine\_version](#input\_global\_cluster\_engine\_version) | (Optional) Engine version of the global database. Must be compatible with Neptune global cluster versions. | `string` | `null` | no |
| <a name="input_global_cluster_identifier"></a> [global\_cluster\_identifier](#input\_global\_cluster\_identifier) | (Optional) The global cluster identifier specified on aws\_neptune\_global\_cluster. | `string` | `null` | no |
| <a name="input_global_cluster_source_db_cluster_identifier"></a> [global\_cluster\_source\_db\_cluster\_identifier](#input\_global\_cluster\_source\_db\_cluster\_identifier) | (Optional) Amazon Resource Name (ARN) to use as the primary DB Cluster of the Global Cluster on creation. Terraform cannot perform drift detection of this value. | `string` | `null` | no |
| <a name="input_global_cluster_storage_encrypted"></a> [global\_cluster\_storage\_encrypted](#input\_global\_cluster\_storage\_encrypted) | (Optional) Specifies whether the global cluster is encrypted. The default is false unless the source DB cluster is encrypted. | `bool` | `null` | no |
| <a name="input_iam_database_authentication_enabled"></a> [iam\_database\_authentication\_enabled](#input\_iam\_database\_authentication\_enabled) | Specifies whether IAM database authentication is enabled | `bool` | `true` | no |
| <a name="input_iam_roles"></a> [iam\_roles](#input\_iam\_roles) | (Optional) A List of ARNs for the IAM roles to associate to the Neptune Cluster | `list(string)` | `null` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | The instance class to use for the Neptune instances (e.g., db.r5.large, db.serverless). | `string` | `"db.serverless"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | (Optional) The ARN for the KMS encryption key. When specifying kms\_key\_arn, storage\_encrypted needs to be set to true. | `string` | `null` | no |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | The maximum Neptune Capacity Units (NCUs) for the cluster | `number` | `128` | no |
| <a name="input_min_capacity"></a> [min\_capacity](#input\_min\_capacity) | The minimum Neptune Capacity Units (NCUs) for the cluster | `number` | `2.5` | no |
| <a name="input_neptune_cluster_endpoints"></a> [neptune\_cluster\_endpoints](#input\_neptune\_cluster\_endpoints) | A map of Neptune cluster endpoints to create. | <pre>map(object({<br/>    endpoint_type    = string<br/>    static_members   = list(string)<br/>    excluded_members = list(string)<br/>    tags             = map(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_neptune_cluster_instance_tags"></a> [neptune\_cluster\_instance\_tags](#input\_neptune\_cluster\_instance\_tags) | Tags for the Neptune cluster instances | `map(string)` | `{}` | no |
| <a name="input_neptune_cluster_parameter_group_tags"></a> [neptune\_cluster\_parameter\_group\_tags](#input\_neptune\_cluster\_parameter\_group\_tags) | Tags for the Neptune cluster parameter group | `map(string)` | `{}` | no |
| <a name="input_neptune_cluster_parameters"></a> [neptune\_cluster\_parameters](#input\_neptune\_cluster\_parameters) | A map of Neptune cluster parameter settings | <pre>map(object({<br/>    key   = string<br/>    value = string<br/>  }))</pre> | <pre>{<br/>  "parameter1": {<br/>    "key": "neptune_enable_audit_log",<br/>    "value": "1"<br/>  }<br/>}</pre> | no |
| <a name="input_neptune_db_parameters"></a> [neptune\_db\_parameters](#input\_neptune\_db\_parameters) | A map of Neptune DB parameter settings | <pre>map(object({<br/>    key   = string<br/>    value = string<br/>  }))</pre> | <pre>{<br/>  "parameter1": {<br/>    "key": "neptune_query_timeout",<br/>    "value": "25"<br/>  }<br/>}</pre> | no |
| <a name="input_neptune_event_subscription_tags"></a> [neptune\_event\_subscription\_tags](#input\_neptune\_event\_subscription\_tags) | Tags for the Neptune event subscription | `map(string)` | `{}` | no |
| <a name="input_neptune_family"></a> [neptune\_family](#input\_neptune\_family) | The family of the neptune cluster and parameter group. | `string` | `"neptune1.2"` | no |
| <a name="input_neptune_parameter_group_tags"></a> [neptune\_parameter\_group\_tags](#input\_neptune\_parameter\_group\_tags) | Tags for the Neptune parameter group | `map(string)` | `{}` | no |
| <a name="input_neptune_port"></a> [neptune\_port](#input\_neptune\_port) | Network port for the Neptune DB Cluster | `number` | `8182` | no |
| <a name="input_neptune_role_description"></a> [neptune\_role\_description](#input\_neptune\_role\_description) | Description for the Neptune IAM role | `string` | `null` | no |
| <a name="input_neptune_role_name"></a> [neptune\_role\_name](#input\_neptune\_role\_name) | Name for the Neptune IAM role | `string` | `"iam-role-neptune"` | no |
| <a name="input_neptune_role_permissions_boundary"></a> [neptune\_role\_permissions\_boundary](#input\_neptune\_role\_permissions\_boundary) | ARN of the policy that is used to set the permissions boundary for the Neptune IAM role | `string` | `null` | no |
| <a name="input_neptune_security_group_tags"></a> [neptune\_security\_group\_tags](#input\_neptune\_security\_group\_tags) | Tags for the Neptune security group | `map(string)` | `{}` | no |
| <a name="input_neptune_subnet_cidrs"></a> [neptune\_subnet\_cidrs](#input\_neptune\_subnet\_cidrs) | A list of subnet CIDRs where the Neptune cluster is situated | `list(string)` | <pre>[<br/>  "10.0.0.0/8"<br/>]</pre> | no |
| <a name="input_neptune_subnet_group_tags"></a> [neptune\_subnet\_group\_tags](#input\_neptune\_subnet\_group\_tags) | Tags for the Neptune subnet group | `map(string)` | `{}` | no |
| <a name="input_port"></a> [port](#input\_port) | (Optional) The port on which the Neptune accepts connections. | `number` | `8182` | no |
| <a name="input_preferred_backup_window"></a> [preferred\_backup\_window](#input\_preferred\_backup\_window) | The daily time range during which automated backups are created | `string` | `"07:00-09:00"` | no |
| <a name="input_preferred_maintenance_window"></a> [preferred\_maintenance\_window](#input\_preferred\_maintenance\_window) | (Optional) The weekly time range during which system maintenance can occur, in UTC, e.g., 'wed:04:00-wed:04:30'. | `string` | `null` | no |
| <a name="input_read_replica_count"></a> [read\_replica\_count](#input\_read\_replica\_count) | Number of read replicas to create. | `number` | `0` | no |
| <a name="input_replication_source_identifier"></a> [replication\_source\_identifier](#input\_replication\_source\_identifier) | (Optional) ARN of a source Neptune cluster or Neptune instance if this Neptune cluster is to be created as a Read Replica. | `string` | `null` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Determines whether a final Neptune snapshot is created before deletion | `bool` | `true` | no |
| <a name="input_snapshot_identifier"></a> [snapshot\_identifier](#input\_snapshot\_identifier) | (Optional) Specifies whether or not to create this cluster from a snapshot. | `string` | `null` | no |
| <a name="input_storage_encrypted"></a> [storage\_encrypted](#input\_storage\_encrypted) | (Optional) Specifies whether the Neptune cluster is encrypted. | `bool` | `true` | no |
| <a name="input_storage_type"></a> [storage\_type](#input\_storage\_type) | (Optional) Storage type associated with the cluster (standard or iopt1). Default: standard | `string` | `"standard"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | A list of subnet IDs to associate with the Neptune cluster | `list(string)` | `null` | no |
| <a name="input_subnet_name_filters"></a> [subnet\_name\_filters](#input\_subnet\_name\_filters) | When subnet\_ids = null, you can filter subnets by tags instead of supplying IDs. | `map(list(string))` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the Neptune cluster | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC ID for the Neptune cluster and security group | `string` | `null` | no |
| <a name="input_vpc_security_group_ids"></a> [vpc\_security\_group\_ids](#input\_vpc\_security\_group\_ids) | (Optional) List of VPC security groups to associate with the Cluster | `list(string)` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_neptune_cluster_arn"></a> [neptune\_cluster\_arn](#output\_neptune\_cluster\_arn) | ARN of the Neptune cluster |
| <a name="output_neptune_cluster_endpoint"></a> [neptune\_cluster\_endpoint](#output\_neptune\_cluster\_endpoint) | The DNS endpoint of the Neptune cluster instance |
| <a name="output_neptune_cluster_endpoint_ids"></a> [neptune\_cluster\_endpoint\_ids](#output\_neptune\_cluster\_endpoint\_ids) | IDs of the Neptune cluster endpoints |
| <a name="output_neptune_cluster_id"></a> [neptune\_cluster\_id](#output\_neptune\_cluster\_id) | ID of the Neptune cluster |
| <a name="output_neptune_cluster_members"></a> [neptune\_cluster\_members](#output\_neptune\_cluster\_members) | List of Neptune Instances that are a part of this cluster |
| <a name="output_neptune_cluster_reader_endpoint"></a> [neptune\_cluster\_reader\_endpoint](#output\_neptune\_cluster\_reader\_endpoint) | The reader endpoint of the Neptune cluster |
| <a name="output_neptune_cluster_resource_id"></a> [neptune\_cluster\_resource\_id](#output\_neptune\_cluster\_resource\_id) | The resource ID of the Neptune cluster |
| <a name="output_neptune_cluster_snapshot_identifier"></a> [neptune\_cluster\_snapshot\_identifier](#output\_neptune\_cluster\_snapshot\_identifier) | The Identifier for the DB Cluster Snapshot |
| <a name="output_neptune_db_parameter_group_id"></a> [neptune\_db\_parameter\_group\_id](#output\_neptune\_db\_parameter\_group\_id) | ID of the Neptune DB parameter group |
| <a name="output_neptune_event_subscription_ids"></a> [neptune\_event\_subscription\_ids](#output\_neptune\_event\_subscription\_ids) | IDs of the Neptune event subscriptions |
| <a name="output_neptune_global_cluster_arn"></a> [neptune\_global\_cluster\_arn](#output\_neptune\_global\_cluster\_arn) | ARN of the Neptune global cluster |
| <a name="output_neptune_global_cluster_id"></a> [neptune\_global\_cluster\_id](#output\_neptune\_global\_cluster\_id) | ID of the Neptune global cluster |
| <a name="output_neptune_global_cluster_members"></a> [neptune\_global\_cluster\_members](#output\_neptune\_global\_cluster\_members) | A set of objects containing global cluster members |
| <a name="output_neptune_global_cluster_resource_id"></a> [neptune\_global\_cluster\_resource\_id](#output\_neptune\_global\_cluster\_resource\_id) | AWS Region-unique, immutable identifier for the global database cluster |
| <a name="output_neptune_iam_role_arn"></a> [neptune\_iam\_role\_arn](#output\_neptune\_iam\_role\_arn) | ARN of the IAM role for Neptune |
| <a name="output_neptune_parameter_group_id"></a> [neptune\_parameter\_group\_id](#output\_neptune\_parameter\_group\_id) | ID of the Neptune cluster parameter group |
| <a name="output_neptune_primary_instance_id"></a> [neptune\_primary\_instance\_id](#output\_neptune\_primary\_instance\_id) | ID of the primary Neptune cluster instance |
| <a name="output_neptune_read_replica_ids"></a> [neptune\_read\_replica\_ids](#output\_neptune\_read\_replica\_ids) | IDs of the Neptune read replica instances |
| <a name="output_neptune_security_group_id"></a> [neptune\_security\_group\_id](#output\_neptune\_security\_group\_id) | ID of the Neptune security group |
| <a name="output_neptune_subnet_group_id"></a> [neptune\_subnet\_group\_id](#output\_neptune\_subnet\_group\_id) | ID of the Neptune subnet group |
<!-- END_TF_DOCS -->
