package test

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// infraTestsEnabled returns true when the RUN_ACC_TESTS environment variable
// is set to "true". Acceptance tests that create real AWS resources are
// skipped unless this gate is open, preventing accidental spend in CI.
func infraTestsEnabled() bool {
	return os.Getenv("RUN_ACC_TESTS") == "true"
}

// TestNeptuneServerlessCluster deploys a minimal serverless Neptune cluster and
// asserts that all managed resources are created with the expected
// configuration.
//
// Requires: AWS credentials with permissions to create Neptune, IAM, EC2, and
// random provider resources.
func TestNeptuneServerlessCluster(t *testing.T) {
	if !infraTestsEnabled() {
		t.Skip("skipping acceptance test; set RUN_ACC_TESTS=true to run")
	}

	const (
		region      = "us-east-1"
		minCapacity = 2.5
		maxCapacity = 8.0
	)
	suffix := strings.ToLower(random.UniqueId())

	vpc := resolveVPCConfig(t, region)

	expectedTags := map[string]string{
		"Environment": "test",
		"Owner":       "terratest",
	}

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/test-fixture",
		Vars: map[string]interface{}{
			"suffix":                                 suffix,
			"subnet_ids":                             vpc.SubnetIDs,
			"vpc_id":                                 vpc.VPCID,
			"neptune_subnet_cidrs":                   []string{vpc.VPCCIDR},
			"engine_version":                         "1.4.7.0",
			"enable_serverless":                      true,
			"instance_class":                         "db.serverless",
			"min_capacity":                           minCapacity,
			"max_capacity":                           maxCapacity,
			"create_neptune_instance":                true,
			"read_replica_count":                     2,
			"create_neptune_iam_role":                true,
			"create_neptune_cluster_parameter_group": true,
			"create_neptune_parameter_group":         true,
			"neptune_family":                         "neptune1.4",
			"storage_encrypted":                      true,
			"backup_retention_period":                1,
			"create_neptune_cluster_snapshot":        true,
			"tags":                                   expectedTags,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": region,
		},
	})

	defer terraform.Destroy(t, opts)
	terraform.InitAndApply(t, opts)

	// ── Cluster outputs ──────────────────────────────────────────────────────

	clusterIDOut := terraform.Output(t, opts, "neptune_cluster_id")
	require.Contains(t, clusterIDOut, suffix, "cluster ID should contain the test suffix")

	clusterARN := terraform.Output(t, opts, "neptune_cluster_arn")
	require.True(t, strings.HasPrefix(clusterARN, "arn:"), "cluster ARN should be a valid ARN")

	clusterEndpoint := terraform.Output(t, opts, "neptune_cluster_endpoint")
	require.NotEmpty(t, clusterEndpoint, "cluster endpoint should be non-empty")
	require.Contains(t, clusterEndpoint, ".neptune.", "endpoint should be a Neptune DNS name")

	readerEndpoint := terraform.Output(t, opts, "neptune_cluster_reader_endpoint")
	require.NotEmpty(t, readerEndpoint, "reader endpoint should be non-empty")

	resourceID := terraform.Output(t, opts, "neptune_cluster_resource_id")
	require.True(t, strings.HasPrefix(resourceID, "cluster-"), "cluster resource ID should start with 'cluster-'")

	// ── Instance outputs ─────────────────────────────────────────────────────

	primaryInstanceID := terraform.Output(t, opts, "neptune_primary_instance_id")
	require.NotEmpty(t, primaryInstanceID, "primary instance ID should be set")

	publiclyAccessible := terraform.Output(t, opts, "neptune_primary_instance_publicly_accessible")
	require.Equal(t, "false", publiclyAccessible, "primary instance should not be publicly accessible by default")

	// ── Read replicas ────────────────────────────────────────────────────────

	replicaIDs := terraform.OutputList(t, opts, "neptune_read_replica_ids")
	require.Len(t, replicaIDs, 2, "expected exactly 2 read replica instances")

	for _, id := range replicaIDs {
		require.NotEqual(t, primaryInstanceID, id, "replica ID must differ from primary ID")
	}

	// ── IAM role ─────────────────────────────────────────────────────────────

	iamRoleARN := terraform.Output(t, opts, "neptune_iam_role_arn")
	require.True(t, strings.HasPrefix(iamRoleARN, "arn:"), "IAM role ARN should be a valid ARN")
	require.Contains(t, iamRoleARN, ":iam:", "ARN should reference IAM service")
	assertNeptuneTrustPolicy(t, roleNameFromARN(iamRoleARN), region)

	// ── Parameter groups ─────────────────────────────────────────────────────

	clusterPGID := terraform.Output(t, opts, "neptune_parameter_group_id")
	require.NotEmpty(t, clusterPGID, "cluster parameter group ID should be set")
	require.Contains(t, clusterPGID, "cluster-parameter-group-", "should use module naming convention")

	dbPGID := terraform.Output(t, opts, "neptune_db_parameter_group_id")
	require.NotEmpty(t, dbPGID, "DB parameter group ID should be set")
	require.Contains(t, dbPGID, "parameter-group-", "should use module naming convention")

	assertClusterParameterGroup(t, clusterIDOut, region, "cluster-parameter-group-")

	// ── Subnet group ─────────────────────────────────────────────────────────

	subnetGroupID := terraform.Output(t, opts, "neptune_subnet_group_id")
	require.NotEmpty(t, subnetGroupID, "subnet group ID should be set")

	assertSubnetGroupMembers(t, subnetGroupID, region, vpc.SubnetIDs)

	// ── Security group ───────────────────────────────────────────────────────

	sgID := terraform.Output(t, opts, "neptune_security_group_id")
	require.NotEmpty(t, sgID, "security group ID should be set")
	require.True(t, strings.HasPrefix(sgID, "sg-"), "security group ID should start with 'sg-'")

	assertSecurityGroupRules(t, sgID, vpc.VPCCIDR, region)
	assertServerlessScalingConfig(t, clusterIDOut, region, minCapacity, maxCapacity)
	assertClusterEncryption(t, clusterIDOut, region)

	// ── Tags ─────────────────────────────────────────────────────────────────

	actualTags := getTagsForNeptuneCluster(t, clusterARN, region)
	for k, v := range expectedTags {
		require.Equal(t, v, actualTags[k], "tag %q should have value %q", k, v)
	}

	// ── Snapshot ─────────────────────────────────────────────────────────────

	snapshotID := terraform.Output(t, opts, "neptune_cluster_snapshot_identifier")
	require.NotEmpty(t, snapshotID, "snapshot identifier should be set")
	require.Contains(t, snapshotID, clusterIDOut,
		"snapshot identifier %q should contain cluster ID %q", snapshotID, clusterIDOut)
}

// TestNeptuneDisabledResources deploys a minimal cluster with instances and IAM
// role disabled, and verifies those outputs are empty while the cluster itself
// is still created.
func TestNeptuneDisabledResources(t *testing.T) {
	if !infraTestsEnabled() {
		t.Skip("skipping acceptance test; set RUN_ACC_TESTS=true to run")
	}

	const region = "us-east-1"
	suffix := strings.ToLower(random.UniqueId())

	vpc := resolveVPCConfig(t, region)

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/test-fixture",
		Vars: map[string]interface{}{
			"suffix":                  suffix,
			"subnet_ids":              vpc.SubnetIDs,
			"vpc_id":                  vpc.VPCID,
			"engine_version":          "1.4.7.0",
			"enable_serverless":       true,
			"instance_class":          "db.serverless",
			"create_neptune_instance": false,
			"create_neptune_iam_role": false,
			"neptune_family":          "neptune1.4",
			"storage_encrypted":       true,
			"backup_retention_period": 1,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": region,
		},
	})

	defer terraform.Destroy(t, opts)
	terraform.InitAndApply(t, opts)

	// Cluster should still be created
	clusterID := terraform.Output(t, opts, "neptune_cluster_id")
	require.NotEmpty(t, clusterID, "cluster should be created even with instances and IAM disabled")

	// Instance outputs must be empty
	primaryInstanceID := terraform.Output(t, opts, "neptune_primary_instance_id")
	require.Empty(t, primaryInstanceID, "primary instance should not be created")

	replicaIDs := terraform.OutputList(t, opts, "neptune_read_replica_ids")
	require.Empty(t, replicaIDs, "no replicas should be created")

	// IAM role must be empty
	iamRoleARN := terraform.Output(t, opts, "neptune_iam_role_arn")
	require.Empty(t, iamRoleARN, "IAM role ARN should be empty when create_neptune_iam_role=false")
}

// copyModuleRootToTemp copies the entire module repository root to a temp
// directory and returns the path to examples/test-fixture within it. This
// preserves the relative source = "../../" reference in main.tf so that
// terraform init resolves the local module correctly.
func copyModuleRootToTemp(t *testing.T) string {
	t.Helper()
	repoRoot, err := files.CopyTerraformFolderToTemp("../", t.Name())
	require.NoError(t, err, "copy module root to temp")
	return repoRoot + "/examples/test-fixture"
}

// TestNeptuneValidation_ServerlessMismatch validates that a plan is rejected
// when enable_serverless=true but instance_class is not db.serverless.
//
// No AWS resources are created — this is a plan-only validation test. Run with:
// go test -v -run TestNeptuneValidation_ServerlessMismatch -timeout 5m
func TestNeptuneValidation_ServerlessMismatch(t *testing.T) {
	t.Parallel()

	// Copy the entire repo root to a temp directory so that the fixture's
	// relative module source ("../../") resolves correctly in isolation.
	fixtureDir := copyModuleRootToTemp(t)
	suffix := strings.ToLower(random.UniqueId())

	opts := &terraform.Options{
		TerraformDir: fixtureDir,
		Vars: map[string]interface{}{
			"suffix":                          suffix,
			"aws_region":                      "us-east-1",
			"aws_skip_credentials_validation": true,
			"subnet_ids":                      []string{"subnet-00000000"},
			"engine_version":                  "1.4.7.0",
			"enable_serverless":               true,
			"instance_class":                  "db.r5.large", // invalid with enable_serverless=true
			"create_neptune_instance":         false,
			"neptune_family":                  "neptune1.4",
			"storage_encrypted":               true,
			"backup_retention_period":         1,
		},
	}

	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err, "plan should fail when instance_class is not db.serverless with enable_serverless=true")
	require.Contains(t, err.Error(), "db.serverless", "error message should reference the required instance class")
}

// TestNeptuneValidation_MissingSubnetConfig validates that the subnet group
// precondition fires when neither subnet_ids nor subnet_name_filters is
// provided.
//
// No AWS resources are created — this is a plan-only validation test. Run with:
// go test -v -run TestNeptuneValidation_MissingSubnetConfig -timeout 5m
func TestNeptuneValidation_MissingSubnetConfig(t *testing.T) {
	t.Parallel()

	// Copy the entire repo root to a temp directory so that the fixture's
	// relative module source ("../../") resolves correctly in isolation.
	fixtureDir := copyModuleRootToTemp(t)
	suffix := strings.ToLower(random.UniqueId())

	opts := &terraform.Options{
		TerraformDir: fixtureDir,
		Vars: map[string]interface{}{
			"suffix":                          suffix,
			"aws_region":                      "us-east-1",
			"aws_skip_credentials_validation": true,
			"subnet_ids":                      []string{}, // empty — should trigger precondition
			"engine_version":                  "1.4.7.0",
			"enable_serverless":               true,
			"instance_class":                  "db.serverless",
			"create_neptune_instance":         false,
			"neptune_family":                  "neptune1.4",
			"storage_encrypted":               true,
			"backup_retention_period":         1,
		},
	}

	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err, "plan should fail without subnet_ids or subnet_name_filters")
	require.Contains(t, err.Error(), "subnet", "error message should reference subnet configuration")
}

// TestNeptuneValidation_PublicWithoutSubnet validates that the precondition
// fires when publicly_accessible = false and no subnet group is configured.
//
// No AWS resources are created — this is a plan-only validation test. Run with:
// go test -v -run TestNeptuneValidation_PublicWithoutSubnet -timeout 5m
func TestNeptuneValidation_PublicWithoutSubnet(t *testing.T) {
	t.Parallel()
	fixtureDir := copyModuleRootToTemp(t)
	suffix := strings.ToLower(random.UniqueId())

	opts := &terraform.Options{
		TerraformDir: fixtureDir,
		Vars: map[string]interface{}{
			"suffix":                          suffix,
			"aws_region":                      "us-east-1",
			"aws_skip_credentials_validation": true,
			"subnet_ids":                      []string{"subnet-00000000"},
			"engine_version":                  "1.4.7.0",
			"enable_serverless":               true,
			"instance_class":                  "db.serverless",
			"create_neptune_instance":         true,
			"neptune_family":                  "neptune1.4",
			"storage_encrypted":               true,
			"backup_retention_period":         1,
			"publicly_accessible":             false,
			"create_neptune_subnet_group":     false,
		},
	}

	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err, "plan should fail when publicly_accessible=false without subnet group")
	require.Contains(t, err.Error(), "neptune_subnet_group_name", "error should reference subnet group requirement")
}
