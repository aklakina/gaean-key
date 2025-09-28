variables {
  test_environment = "tftest"
}

# Test Case B: Standard run with no failures expected
# Resources should deploy, wait 1 minute, next run deploys 2 new resources and modifies 1 existing,
# wait 1 minute, then 2 resources should be destroyed

run "initial_deployment" {
  command = apply

  # Verify initial deployment succeeds without conflicts
  assert {
    condition     = length(local.duplicate_ids) == 0
    error_message = "No conflicts should exist in standard run"
  }

  assert {
    condition     = length(keys(local.merged_credentials)) > 0
    error_message = "No credentials were deployed in initial run"
  }
}

run "rotation_cycle_deployment" {
  command = apply

  # This run should deploy new resources and modify existing ones
  # The rotation module should handle credential lifecycle
  assert {
    condition     = length(local.duplicate_ids) == 0
    error_message = "No conflicts should occur during rotation"
  }

  assert {
    condition     = local.merged_credentials != null
    error_message = "Credentials should be present after rotation cycle"
  }
}

run "verify_final_state" {
  command = apply

  # After the rotation cycles, verify the system is in a clean state
  assert {
    condition     = length(local.duplicate_ids) == 0
    error_message = "Final state should have no conflicts"
  }

  assert {
    condition     = local.merged_credentials != null
    error_message = "Credential management system should be operational"
  }
}
