output "repositories" {
    value = {
        "sitedata" = {
            "repository_url" = aws_ecr_repository.sitedata.repository_url
        }
        "ssp_to_s3" = {
            "repository_url" = aws_ecr_repository.ssp_to_s3.repository_url
        }
        "data_utils" = {
            "repository_url" = aws_ecr_repository.data_utils.repository_url
        }
    }
}

output "batch_service_role_attachment" {
    value = aws_iam_role_policy_attachment.batch
    description = "Batch Service Role attachment which Compute Environments depend on"
}

output "batch_service_role" {
    value = aws_iam_role.batch.arn
    description = "Batch Service Role which Batch uses"
}

output "ecs_instance_profile" {
    value = aws_iam_instance_profile.ecs_instance.arn
    description = "instance profile for ECS Container Instances"
}

output "task_role" {
    value = aws_iam_role.task.arn
    description = "task role ARN for jobs definitions"
}

output "event_role" {
    value = aws_iam_role.event.arn
    description = "event role ARN for CloudWatch events definitions"
}