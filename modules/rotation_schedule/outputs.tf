output "phase1_active" {
  description = "Whether the phase 1 credential exists now."
  value       = module.phases.phase1_active
}

output "phase2_active" {
  description = "Whether the phase 2 credential exists now."
  value       = module.phases.phase2_active
}

output "use_phase2" {
  description = "Whether consumers get the phase 2 credential (otherwise phase 1)."
  value       = module.phases.use_phase2
}

output "start_time" {
  description = "Start (t0) of the current 2 x expires_in cycle."
  value       = terraform_data.deterministic_time.input.time
}
