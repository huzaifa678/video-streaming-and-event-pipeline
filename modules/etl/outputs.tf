output "glue_job_name" {
  value = aws_glue_job.rekognition_to_redshift.name
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.glue_orchestrator.arn
}
