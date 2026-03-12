package test

import (
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// infraTestsEnabled returns true when the RUN_ACC_TESTS environment variable
// is set to "true". Acceptance tests that create real AWS resources are
// skipped unless this gate is open, preventing accidental spend in CI.
func infraTestsEnabled() bool {
	return os.Getenv("RUN_ACC_TESTS") == "true"
}

// TestNeptuneServerlessCluster deploys a minimal serverless Neptune cluster and
// asserts that all managed resources are created with the expected configuration.
//
// Requires: AWS credentials with permissions to create Neptune, IAM, EC2, and
// random provider resources.
//
// Run with: RUN_ACC_TESTS=true go test -v -run TestNeptuneServerlessCluster -timeout 60m
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
			"create_neptune_iam_role":                true,
			"create_neptune_cluster_parameter_group": true,
			"create_neptune_parameter_group":         true,
			"neptune_family":                         "neptune1.4",
			"storage_encrypted":                      true,
			"backup_retention_period":                1,
			"tags": map[string]string{
				"Test": "TestNeptuneServerlessCluster",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": region,
		},
	})

	defer terraform.Destroy(t, opts)
	terraform.InitAndApply(t, opts)

	// ── Cluster outputs ──────────────────────────────────────────────────────

	clusterIDOut := terraform.Output(t, opts, "neptune_cluster_id")
	// Assert the suffix is present rather than requiring exact equality. This
	// is resilient to module-level naming changes that preserve uniqueness.
	assert.Contains(t, clusterIDOut, suffix, "cluster ID should contain the test suffix")

	clusterARN := terraform.Output(t, opts, "neptune_cluster_arn")
	assert.True(t, strings.HasPrefix(clusterARN, "arn:"), "cluster ARN should be a valid ARN")

	clusterEndpoint := terraform.Output(t, opts, "neptune_cluster_endpoint")
	assert.NotEmpty(t, clusterEndpoint, "cluster endpoint should be non-empty")
	assert.Contains(t, clusterEndpoint, ".neptune.", "endpoint should be a Neptune DNS name")

	readerEndpoint := terraform.Output(t, opts, "neptune_cluster_reader_endpoint")
	assert.NotEmpty(t, readerEndpoint, "reader endpoint should be non-empty")

	resourceID := terraform.Output(t, opts, "neptune_cluster_resource_id")
	assert.True(t, strings.HasPrefix(resourceID, "cluster-"), "cluster resource ID should start with 'cluster-'")

	// ── Instance outputs ─────────────────────────────────────────────────────

	primaryInstanceID := terraform.Output(t, opts, "neptune_primary_instance_id")
	assert.NotEmpty(t, primaryInstanceID, "primary instance ID should be set")

	replicaIDs := terraform.OutputList(t, opts, "neptune_read_replica_ids")
	assert.Empty(t, replicaIDs, "no read replicas expected with read_replica_count=0")

	publiclyAccessible := terraform.Output(t, opts, "neptune_primary_instance_publicly_accessible")
	assert.Equal(t, "false", publiclyAccessible, "primary instance should not be publicly accessible by default")

	// ── IAM role ─────────────────────────────────────────────────────────────

	iamRoleARN := terraform.Output(t, opts, "neptune_iam_role_arn")
	assert.True(t, strings.HasPrefix(iamRoleARN, "arn:"), "IAM role ARN should be a valid ARN")
	assert.Contains(t, iamRoleARN, ":iam:", "ARN should reference IAM service")
	assertNeptuneTrustPolicy(t, roleNameFromARN(iamRoleARN), region)

	// ── Parameter groups ─────────────────────────────────────────────────────

	clusterPGID := terraform.Output(t, opts, "neptune_parameter_group_id")
	assert.NotEmpty(t, clusterPGID, "cluster parameter group ID should be set")
	assert.Contains(t, clusterPGID, "cluster-parameter-group-", "should use module naming convention")

	dbPGID := terraform.Output(t, opts, "neptune_db_parameter_group_id")
	assert.NotEmpty(t, dbPGID, "DB parameter group ID should be set")
	assert.Contains(t, dbPGID, "parameter-group-", "should use module naming convention")

	assertClusterParameterGroup(t, clusterIDOut, region, "cluster-parameter-group-")

	// ── Subnet group ─────────────────────────────────────────────────────────

	subnetGroupID := terraform.Output(t, opts, "neptune_subnet_group_id")
	assert.NotEmpty(t, subnetGroupID, "subnet group ID should be set")

	assertSubnetGroupMembers(t, subnetGroupID, region, vpc.SubnetIDs)

	// ── Security group ───────────────────────────────────────────────────────

	sgID := terraform.Output(t, opts, "neptune_security_group_id")
	assert.NotEmpty(t, sgID, "security group ID should be set")
	assert.True(t, strings.HasPrefix(sgID, "sg-"), "security group ID should start with 'sg-'")

	assertSecurityGroupRules(t, sgID, vpc.VPCCIDR, region)
	assertServerlessScalingConfig(t, clusterIDOut, region, minCapacity, maxCapacity)
	assertClusterEncryption(t, clusterIDOut, region)
}

// TestNeptuneReadReplicas deploys a cluster with two read replicas and verifies
// the correct number of instances is created.
//
// Run with: RUN_ACC_TESTS=true go test -v -run TestNeptuneReadReplicas -timeout
// 60m
func TestNeptuneReadReplicas(t *testing.T) {
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
			"neptune_subnet_cidrs":    []string{vpc.VPCCIDR},
			"engine_version":          "1.4.7.0",
			"enable_serverless":       true,
			"instance_class":          "db.serverless",
			"min_capacity":            2.5,
			"max_capacity":            8,
			"create_neptune_instance": true,
			"read_replica_count":      2,
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

	replicaIDs := terraform.OutputList(t, opts, "neptune_read_replica_ids")
	assert.Len(t, replicaIDs, 2, "expected exactly 2 read replica instances")

	primaryInstanceID := terraform.Output(t, opts, "neptune_primary_instance_id")
	assert.NotEmpty(t, primaryInstanceID, "primary instance should still be created")

	for _, id := range replicaIDs {
		assert.NotEqual(t, primaryInstanceID, id, "replica ID must differ from primary ID")
	}
}

// TestNeptuneNoInstanceCreated validates that create_neptune_instance=false
// results in no instance resources while the cluster is still created.
//
// Run with: RUN_ACC_TESTS=true go test -v -run TestNeptuneNoInstanceCreated
// -timeout 45m
func TestNeptuneNoInstanceCreated(t *testing.T) {
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
	assert.NotEmpty(t, clusterID, "cluster should be created even without instances")

	// Instance outputs must be empty
	primaryInstanceID := terraform.Output(t, opts, "neptune_primary_instance_id")
	assert.Empty(t, primaryInstanceID, "primary instance should not be created")

	replicaIDs := terraform.OutputList(t, opts, "neptune_read_replica_ids")
	assert.Empty(t, replicaIDs, "no replicas should be created")
}

// TestNeptuneNoIAMRole validates that create_neptune_iam_role=false produces no
// IAM role output.
//
// Run with: RUN_ACC_TESTS=true go test -v -run TestNeptuneNoIAMRole -timeout
// 45m
func TestNeptuneNoIAMRole(t *testing.T) {
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

	iamRoleARN := terraform.Output(t, opts, "neptune_iam_role_arn")
	assert.Empty(t, iamRoleARN, "IAM role ARN should be empty when create_neptune_iam_role=false")
}

// TestNeptuneTagsApplied verifies that caller-supplied tags appear on the
// cluster.
//
// Run with: RUN_ACC_TESTS=true go test -v -run TestNeptuneTagsApplied -timeout
// 45m
func TestNeptuneTagsApplied(t *testing.T) {
	if !infraTestsEnabled() {
		t.Skip("skipping acceptance test; set RUN_ACC_TESTS=true to run")
	}

	const region = "us-east-1"
	suffix := strings.ToLower(random.UniqueId())

	vpc := resolveVPCConfig(t, region)
	expectedTags := map[string]string{
		"Environment": "test",
		"Owner":       "terratest",
	}

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
			"neptune_family":          "neptune1.4",
			"storage_encrypted":       true,
			"backup_retention_period": 1,
			"tags":                    expectedTags,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": region,
		},
	})

	defer terraform.Destroy(t, opts)
	terraform.InitAndApply(t, opts)

	clusterARN := terraform.Output(t, opts, "neptune_cluster_arn")
	require.NotEmpty(t, clusterARN)

	actualTags := getTagsForNeptuneCluster(t, clusterARN, region)
	for k, v := range expectedTags {
		assert.Equal(t, v, actualTags[k], "tag %q should have value %q", k, v)
	}
}

// TestNeptuneClusterSnapshot validates that a snapshot is created and its
// identifier contains the cluster ID.
//
// Run with: RUN_ACC_TESTS=true go test -v -run TestNeptuneClusterSnapshot
// -timeout 60m
func TestNeptuneClusterSnapshot(t *testing.T) {
	if !infraTestsEnabled() {
		t.Skip("skipping acceptance test; set RUN_ACC_TESTS=true to run")
	}

	const region = "us-east-1"
	suffix := strings.ToLower(random.UniqueId())

	vpc := resolveVPCConfig(t, region)

	opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../examples/test-fixture",
		Vars: map[string]interface{}{
			"suffix":                          suffix,
			"subnet_ids":                      vpc.SubnetIDs,
			"vpc_id":                          vpc.VPCID,
			"engine_version":                  "1.4.7.0",
			"enable_serverless":               true,
			"instance_class":                  "db.serverless",
			"create_neptune_instance":         false,
			"neptune_family":                  "neptune1.4",
			"storage_encrypted":               true,
			"backup_retention_period":         1,
			"create_neptune_cluster_snapshot": true,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": region,
		},
	})

	defer terraform.Destroy(t, opts)
	terraform.InitAndApply(t, opts)

	clusterIDOut := terraform.Output(t, opts, "neptune_cluster_id")

	snapshotID := terraform.Output(t, opts, "neptune_cluster_snapshot_identifier")
	assert.NotEmpty(t, snapshotID, "snapshot identifier should be set")
	// Use Contains rather than HasPrefix so the assertion holds if the module
	// ever changes its naming scheme while keeping the cluster ID embedded.
	assert.Contains(t, snapshotID, clusterIDOut,
		"snapshot identifier %q should contain cluster ID %q", snapshotID, clusterIDOut)
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
	assert.Contains(t, err.Error(), "db.serverless", "error message should reference the required instance class")
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
	assert.Contains(t, err.Error(), "subnet", "error message should reference subnet configuration")
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
	assert.Contains(t, err.Error(), "neptune_subnet_group_name", "error should reference subnet group requirement")
}
