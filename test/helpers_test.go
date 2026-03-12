package test

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/neptune"
	terraaws "github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/stretchr/testify/require"
)

// vpcConfig holds the resolved VPC ID, subnet IDs, and CIDR for a test.
type vpcConfig struct {
	VPCID     string
	SubnetIDs []string
	VPCCIDR   string
}

// resolveVPCConfig returns VPC configuration for tests. Values are read from
// environment variables when present and fall back to the default VPC in the
// given region.
//
//   - TEST_VPC_ID        — VPC ID to use
//   - TEST_SUBNET_IDS    — comma-separated subnet IDs
//   - TEST_VPC_CIDR      — VPC CIDR block
func resolveVPCConfig(t *testing.T, region string) vpcConfig {
	t.Helper()

	vpcID := os.Getenv("TEST_VPC_ID")
	rawSubnets := os.Getenv("TEST_SUBNET_IDS")
	vpcCIDR := os.Getenv("TEST_VPC_CIDR")

	if vpcID != "" && rawSubnets != "" && vpcCIDR != "" {
		ids := strings.Split(rawSubnets, ",")
		for i := range ids {
			ids[i] = strings.TrimSpace(ids[i])
		}
		return vpcConfig{VPCID: vpcID, SubnetIDs: ids, VPCCIDR: vpcCIDR}
	}

	// Fall back to default VPC — may not exist in all AWS accounts.
	vpc := terraaws.GetDefaultVpc(t, region)
	ids := terraaws.GetDefaultSubnetIDsForVpc(t, *vpc)
	require.NotEmpty(t, ids, "no subnets found in default VPC in region %s; set TEST_VPC_ID, TEST_SUBNET_IDS, TEST_VPC_CIDR", region)

	cfg := newAWSConfig(t, region)
	svc := ec2.NewFromConfig(cfg)
	out, err := svc.DescribeVpcs(context.Background(), &ec2.DescribeVpcsInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("isDefault"), Values: []string{"true"}},
		},
	})
	require.NoError(t, err)
	require.NotEmpty(t, out.Vpcs, "no default VPC found in region %s; set TEST_VPC_ID, TEST_SUBNET_IDS, TEST_VPC_CIDR", region)

	return vpcConfig{
		VPCID:     vpc.Id,
		SubnetIDs: ids,
		VPCCIDR:   aws.ToString(out.Vpcs[0].CidrBlock),
	}
}

// newAWSConfig creates an AWS config for the given region.
func newAWSConfig(t *testing.T, region string) aws.Config {
	t.Helper()
	cfg, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(region))
	require.NoError(t, err)
	return cfg
}

// getTagsForNeptuneCluster returns the tags on a Neptune cluster as a map.
func getTagsForNeptuneCluster(t *testing.T, clusterARN, region string) map[string]string {
	t.Helper()
	cfg := newAWSConfig(t, region)
	svc := neptune.NewFromConfig(cfg)

	out, err := svc.ListTagsForResource(context.Background(), &neptune.ListTagsForResourceInput{
		ResourceName: aws.String(clusterARN),
	})
	require.NoError(t, err)

	tags := make(map[string]string, len(out.TagList))
	for _, tag := range out.TagList {
		tags[aws.ToString(tag.Key)] = aws.ToString(tag.Value)
	}
	return tags
}

// roleNameFromARN extracts the role name from an IAM role ARN, handling both
// simple ("role/my-role") and path-prefixed ("role/path/my-role") formats.
func roleNameFromARN(arn string) string {
	// ARN format: arn:partition:service:region:account:resource
	// resource field for a role: "role/[path/]name"
	const rolePrefix = "role/"
	idx := strings.Index(arn, rolePrefix)
	if idx == -1 {
		return arn
	}
	resource := arn[idx+len(rolePrefix):]
	parts := strings.Split(resource, "/")
	return parts[len(parts)-1]
}

// assumeRolePolicyDocument represents the structure of an IAM trust policy.
type assumeRolePolicyDocument struct {
	Statement []struct {
		Principal struct {
			Service interface{} `json:"Service"`
		} `json:"Principal"`
	} `json:"Statement"`
}

// assertNeptuneTrustPolicy fetches the IAM role's trust policy and asserts that
// neptune.amazonaws.com is listed as a principal.
//
// IAM is eventually consistent, the assertion is retried up to five times with
// a back-off to tolerate propagation delays.
func assertNeptuneTrustPolicy(t *testing.T, roleName, region string) {
	t.Helper()
	cfg := newAWSConfig(t, region)
	svc := iam.NewFromConfig(cfg)

	_, err := retry.DoWithRetryE(t, "verify IAM trust policy", 5, 5*time.Second, func() (string, error) {
		out, err := svc.GetRole(context.Background(), &iam.GetRoleInput{
			RoleName: aws.String(roleName),
		})
		if err != nil {
			return "", fmt.Errorf("GetRole: %w", err)
		}

		// AssumeRolePolicyDocument is URL-encoded in the API response.
		raw, err := url.QueryUnescape(aws.ToString(out.Role.AssumeRolePolicyDocument))
		if err != nil {
			return "", fmt.Errorf("url.QueryUnescape: %w", err)
		}

		var doc assumeRolePolicyDocument
		if err := json.Unmarshal([]byte(raw), &doc); err != nil {
			return "", fmt.Errorf("parse trust policy JSON: %w", err)
		}

		foundNeptune := false
		foundRDS := false
		for _, stmt := range doc.Statement {
			switch v := stmt.Principal.Service.(type) {
			case string:
				if v == "neptune.amazonaws.com" {
					foundNeptune = true
				}
				if v == "rds.amazonaws.com" {
					foundRDS = true
				}
			case []interface{}:
				for _, s := range v {
					if str, ok := s.(string); ok {
						if str == "neptune.amazonaws.com" {
							foundNeptune = true
						}
						if str == "rds.amazonaws.com" {
							foundRDS = true
						}
					}
				}
			}
		}

		if !foundNeptune {
			return "", fmt.Errorf("IAM trust policy does not yet include neptune.amazonaws.com")
		}
		if foundRDS {
			return "", fmt.Errorf("IAM trust policy unexpectedly includes rds.amazonaws.com")
		}
		return "ok", nil
	})
	require.NoError(t, err, "assertNeptuneTrustPolicy: retry exhausted")
}

// assertSecurityGroupRules fetches the security group and verifies that:
//   - There is an ingress rule on Neptune port 8182 sourced from allowedCIDR.
//   - There is at least one egress rule (open outbound is typical).
func assertSecurityGroupRules(t *testing.T, sgID, allowedCIDR, region string) {
	t.Helper()
	cfg := newAWSConfig(t, region)
	svc := ec2.NewFromConfig(cfg)
	neptunePort := int32(8182)

	out, err := svc.DescribeSecurityGroups(context.Background(), &ec2.DescribeSecurityGroupsInput{
		GroupIds: []string{sgID},
	})
	require.NoError(t, err)
	require.Len(t, out.SecurityGroups, 1, "expected exactly one security group for id %s", sgID)

	sg := out.SecurityGroups[0]

	foundIngress := false
	for _, perm := range sg.IpPermissions {
		if aws.ToInt32(perm.FromPort) == neptunePort && aws.ToInt32(perm.ToPort) == neptunePort {
			for _, r := range perm.IpRanges {
				if aws.ToString(r.CidrIp) == allowedCIDR {
					foundIngress = true
				}
			}
		}
	}
	require.True(t, foundIngress,
		"security group %s must allow ingress on port 8182 from %s", sgID, allowedCIDR)

	require.NotEmpty(t, sg.IpPermissionsEgress,
		"security group %s must have at least one egress rule", sgID)
}

// assertSubnetGroupMembers fetches the Neptune DB subnet group and verifies
// that it contains at least the expected subnet IDs.
func assertSubnetGroupMembers(t *testing.T, subnetGroupName, region string, expectedSubnetIDs []string) {
	t.Helper()
	cfg := newAWSConfig(t, region)
	svc := neptune.NewFromConfig(cfg)

	out, err := svc.DescribeDBSubnetGroups(context.Background(), &neptune.DescribeDBSubnetGroupsInput{
		DBSubnetGroupName: aws.String(subnetGroupName),
	})
	require.NoError(t, err)
	require.Len(t, out.DBSubnetGroups, 1, "expected exactly one subnet group named %s", subnetGroupName)

	group := out.DBSubnetGroups[0]
	actual := make([]string, 0, len(group.Subnets))
	for _, s := range group.Subnets {
		actual = append(actual, aws.ToString(s.SubnetIdentifier))
	}

	require.Len(t, actual, len(expectedSubnetIDs),
		"subnet group %s: expected %d subnets, got %d: %v",
		subnetGroupName, len(expectedSubnetIDs), len(actual), actual)

	for _, id := range expectedSubnetIDs {
		require.Contains(t, actual, id,
			"subnet group %s should contain subnet %s", subnetGroupName, id)
	}
}

// assertServerlessScalingConfig fetches the Neptune cluster and verifies the
// ServerlessV2ScalingConfiguration matches the expected min/max capacity.
func assertServerlessScalingConfig(t *testing.T, clusterID, region string, minCapacity, maxCapacity float64) {
	t.Helper()
	cfg := newAWSConfig(t, region)
	svc := neptune.NewFromConfig(cfg)

	out, err := svc.DescribeDBClusters(context.Background(), &neptune.DescribeDBClustersInput{
		DBClusterIdentifier: aws.String(clusterID),
	})
	require.NoError(t, err)
	require.Len(t, out.DBClusters, 1, "expected exactly one cluster with id %s", clusterID)

	cluster := out.DBClusters[0]
	require.NotNil(t, cluster.ServerlessV2ScalingConfiguration,
		"cluster %s must have ServerlessV2ScalingConfiguration set", clusterID)

	scaling := cluster.ServerlessV2ScalingConfiguration
	require.InDelta(t, minCapacity, aws.ToFloat64(scaling.MinCapacity), 0.01,
		"cluster %s min capacity: expected %.2f", clusterID, minCapacity)
	require.InDelta(t, maxCapacity, aws.ToFloat64(scaling.MaxCapacity), 0.01,
		"cluster %s max capacity: expected %.2f", clusterID, maxCapacity)
}

// assertClusterEncryption fetches the Neptune cluster and verifies that
// StorageEncrypted is true.
func assertClusterEncryption(t *testing.T, clusterID, region string) {
	t.Helper()
	cfg := newAWSConfig(t, region)
	svc := neptune.NewFromConfig(cfg)

	out, err := svc.DescribeDBClusters(context.Background(), &neptune.DescribeDBClustersInput{
		DBClusterIdentifier: aws.String(clusterID),
	})
	require.NoError(t, err)
	require.Len(t, out.DBClusters, 1, "expected exactly one cluster with id %s", clusterID)

	require.True(t, aws.ToBool(out.DBClusters[0].StorageEncrypted),
		"cluster %s must have StorageEncrypted=true", clusterID)
}

// assertClusterParameterGroup fetches the Neptune cluster and verifies that
// the attached cluster parameter group name contains the expected substring.
func assertClusterParameterGroup(t *testing.T, clusterID, region, expectedSubstring string) {
	t.Helper()
	cfg := newAWSConfig(t, region)
	svc := neptune.NewFromConfig(cfg)

	out, err := svc.DescribeDBClusters(context.Background(), &neptune.DescribeDBClustersInput{
		DBClusterIdentifier: aws.String(clusterID),
	})
	require.NoError(t, err)
	require.Len(t, out.DBClusters, 1, "expected exactly one cluster with id %s", clusterID)

	pgName := aws.ToString(out.DBClusters[0].DBClusterParameterGroup)
	require.Contains(t, pgName, expectedSubstring,
		"cluster %s parameter group %q should contain %q", clusterID, pgName, expectedSubstring)
}
