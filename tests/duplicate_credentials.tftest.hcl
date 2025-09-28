# Test Case A: Plan and apply should fail if there is a secret configuration
# with the same ID in the same service (copying dynamic-cred.yml as static-cred.yml)
# Note: The duplicate configuration file needs to be created before running this test

run "test_duplicate_credential_conflict_plan" {
  command = plan

  expect_failures = [
    terraform_data.conflict_check,
  ]
}
