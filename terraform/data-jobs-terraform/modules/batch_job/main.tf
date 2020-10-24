resource "aws_batch_job_definition" "job_definition" {
  name = var.name
  type = "container"

  container_properties = <<-CONTAINER_PROPERTIES
    {
      "command": ${var.command},
      "environment": [
          {"name": "ENV", "value": "${var.ENV}"}
      ],
      "image": "${var.repository_url}",
      "jobRoleArn": "${var.task_role}",
      "memory": ${var.memory},
      "vcpus": ${var.vcpus}
    }
    CONTAINER_PROPERTIES

  timeout {
    attempt_duration_seconds = var.timeout
  }
}