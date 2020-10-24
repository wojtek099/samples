resource "random_id" "compute_environment" {
  prefix = "${var.name}-"
  byte_length = 4

  keepers = {
    role_attachment     = jsonencode(var.batch_service_role_attachment)
    service_role        = var.batch_service_role
    desired_vcpus       = var.desired_vcpus
    ec2_key_pair        = var.key
    instance_role       = var.ecs_instance_profile
    max_vcpus           = var.max_vcpus
    min_vcpus           = var.min_vcpus
    security_group_ids  = join(", ", var.security_groups)
    subnets             = join(", ", var.subnets)
    type                = var.compute_type
    instance_type       = join(", ", var.instance_type)
    app                 = var.app
  }
}

resource "aws_batch_compute_environment" "environment" {
  depends_on = [var.batch_service_role_attachment]

  compute_environment_name  = random_id.compute_environment.b64_url
  service_role              = var.batch_service_role
  type                      = "MANAGED"

  compute_resources {
    desired_vcpus       = var.desired_vcpus
    ec2_key_pair        = var.key
    instance_role       = var.ecs_instance_profile
    max_vcpus           = var.max_vcpus
    min_vcpus           = var.min_vcpus
    security_group_ids  = var.security_groups
    subnets             = var.subnets
    type                = var.compute_type

    instance_type = var.instance_type

    tags = {
      Name  = var.name
      app   = var.app
    }
  }

  lifecycle {
    ignore_changes = [compute_resources[0].desired_vcpus]

    create_before_destroy = true
  }
}