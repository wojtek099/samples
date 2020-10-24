resource "aws_cloudwatch_event_rule" "rule" {
  description         = var.description
  is_enabled          = var.is_enabled
  name                = var.name
  schedule_expression = var.schedule_expression

  tags = {
    app   = var.app
  }  
}

resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.rule.name
  target_id = "TargetBatch"
  arn       = var.queue
  role_arn  = var.event_role

  batch_target {
    job_definition  = var.job_definition
    job_name        = var.name
  }
}