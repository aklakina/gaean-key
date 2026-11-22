# E = 10m, W = 2m, t0 = 12:00
#   phase 1: [12:00, 12:10) and [12:18, 12:20)
#   phase 2: [12:08, 12:20)
#   consumers use phase 2 in [12:08, 12:18)

variables {
  start_time              = "2026-01-01T12:00:00Z"
  expiry_minutes          = 10
  rotation_window_minutes = 2
}

run "start_of_cycle_only_phase1" {
  command = plan
  variables {
    now = "2026-01-01T12:00:00Z"
  }
  assert {
    condition     = output.phase1_active && !output.phase2_active && !output.use_phase2
    error_message = "Only phase 1 should exist at the start of the cycle."
  }
}

run "first_window_both_phases_use_phase2" {
  command = plan
  variables {
    now = "2026-01-01T12:08:00Z"
  }
  assert {
    condition     = output.phase1_active && output.phase2_active && output.use_phase2
    error_message = "Both phases should exist and consumers should switch to phase 2 when the first window opens."
  }
}

run "phase1_expired" {
  command = plan
  variables {
    now = "2026-01-01T12:10:00Z"
  }
  assert {
    condition     = !output.phase1_active && output.phase2_active && output.use_phase2
    error_message = "Only phase 2 should exist after phase 1 expired."
  }
}

run "second_window_both_phases_use_phase1" {
  command = plan
  variables {
    now = "2026-01-01T12:18:00Z"
  }
  assert {
    condition     = output.phase1_active && output.phase2_active && !output.use_phase2
    error_message = "Both phases should exist and consumers should switch back to (the new) phase 1 when the second window opens."
  }
}

run "end_of_cycle" {
  command = plan
  variables {
    now = "2026-01-01T12:20:00Z"
  }
  assert {
    condition     = output.phase1_active && !output.phase2_active && !output.use_phase2
    error_message = "Only phase 1 should exist once the cycle is over (until the timer starts a new one)."
  }
}
