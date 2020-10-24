data "aws_ssm_parameter" "opsgenie_ecs_alerts_endpoint" {
  name = "/general/opsgenie-ecs-alerts-endpoint"
}

data "aws_caller_identity" "current" {}