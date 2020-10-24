# -------------------------------
# IAM resources
# -------------------------------

# ECS instance profile

data "aws_iam_policy_document" "ecs_instance_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_instance" {
  name               = "${var.app}-EcsInstanceRoles"
  assume_role_policy = data.aws_iam_policy_document.ecs_instance_assume.json

  tags = {
    app   = var.app
  }
}

# https://stackoverflow.com/questions/45002292/terraform-correct-way-to-attach-aws-managed-policies-to-a-role#comment107176446_49456921
data "aws_iam_policy" "AmazonEC2ContainerServiceforEC2Role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = data.aws_iam_policy.AmazonEC2ContainerServiceforEC2Role.arn
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.app}-IamInstanceProfile"
  role = aws_iam_role.ecs_instance.name
}


# Batch service role

data "aws_iam_policy_document" "batch_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["batch.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "batch" {
  name               = "${var.app}-BatchServiceRole"
  assume_role_policy = data.aws_iam_policy_document.batch_assume.json

  tags = {
    app   = var.app
  }  
}

data "aws_iam_policy" "AWSBatchServiceRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_iam_role_policy_attachment" "batch" {
  role       = aws_iam_role.batch.name
  policy_arn = data.aws_iam_policy.AWSBatchServiceRole.arn
}


# Event role

data "aws_iam_policy_document" "event_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "event" {
  name               = "${var.app}-EventRole"
  assume_role_policy = data.aws_iam_policy_document.event_assume.json

  tags = {
    app   = var.app
  }
}

data "aws_iam_policy_document" "event_submit_batch" {
  statement {
    actions = [
      "batch:SubmitJob"
    ]
    resources = [
      "arn:aws:batch:*:*:job-queue/*",
      "arn:aws:batch:*:*:job-definition/*:*"
    ]
  }
}

resource "aws_iam_role_policy" "event_submit_batch" {
  name    = "batch"
  role    = aws_iam_role.event.id
  policy  = data.aws_iam_policy_document.event_submit_batch.json
}


# Task/Job role

data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "${var.app}-TaskRole"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json

  tags = {
    app   = var.app
  }
}

# - ssm
data "aws_iam_policy_document" "task_ssm" {
  statement {
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter"
    ]
    resources = [
      "arn:aws:ssm:*:*:parameter/data/*"
    ]
  }
}

resource "aws_iam_role_policy" "task_ssm" {
  name    = "ssm"
  role    = aws_iam_role.task.id
  policy  = data.aws_iam_policy_document.task_ssm.json
}

# - batch
data "aws_iam_policy_document" "task_batch" {
  statement {
    actions = [
      "batch:ListJobs",
      "batch:SubmitJob"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy" "task_batch" {
  name    = "batch"
  role    = aws_iam_role.task.id
  policy  = data.aws_iam_policy_document.task_batch.json
}

# - s3
data "aws_iam_policy_document" "task_s3" {
  statement {
    actions = [
      "s3:List*",
      "s3:Get*",
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::<redacted>-*/*",
      "arn:aws:s3:::<redacted>-*",
      "arn:aws:s3:::<redacted>-${var.ENV}/*",
      "arn:aws:s3:::<redacted>-${var.ENV}"
    ]
  }
}

resource "aws_iam_role_policy" "task_s3" {
  name    = "s3"
  role    = aws_iam_role.task.id
  policy  = data.aws_iam_policy_document.task_s3.json
}

# -------------------------------
# ECR Repositories
# -------------------------------

resource "aws_ecr_repository" "ssp_to_s3" {
  name = var.ssp_to_s3_image

  tags = {
    app = var.app
  }

  lifecycle {
    prevent_destroy = true
  }
}

# data "aws_iam_policy_document" "repos_lifecycle_policy" {
#   statement {
#     actions   = ["*"]
#     resources = ["*"]
#   }
# }

resource "aws_ecr_lifecycle_policy" "ssp_to_s3" {
  repository = aws_ecr_repository.ssp_to_s3.name

  # https://github.com/terraform-providers/terraform-provider-aws/pull/6133
  # policy = data.aws_iam_policy_document.repos_lifecycle_policy.json
  
  policy = <<-EOF
    {
      "rules": [
      {
        "rulePriority": 1,
        "description": "Only keep 8 images",
        "selection": {
          "tagStatus": "any",
          "countType": "imageCountMoreThan",
          "countNumber": 8
        },
        "action": { "type": "expire" }
      }]
    }
    EOF
}

resource "aws_ecr_repository" "data_utils" {
  name = var.data_utils_image

  tags = {
    app = var.app
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_lifecycle_policy" "data_utils" {
  repository = aws_ecr_repository.data_utils.name
  
  policy = <<-EOF
    {
      "rules": [
      {
        "rulePriority": 1,
        "description": "Only keep 8 images",
        "selection": {
          "tagStatus": "any",
          "countType": "imageCountMoreThan",
          "countNumber": 8
        },
        "action": { "type": "expire" }
      }]
    }
    EOF
}

resource "aws_ecr_repository" "sitedata" {
  name = var.sitedata_image

  tags = {
    app = var.app
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_lifecycle_policy" "sitedata" {
  repository = aws_ecr_repository.sitedata.name
  
  policy = <<-EOF
    {
      "rules": [
      {
        "rulePriority": 1,
        "description": "Only keep 8 images",
        "selection": {
          "tagStatus": "any",
          "countType": "imageCountMoreThan",
          "countNumber": 8
        },
        "action": { "type": "expire" }
      }]
    }
    EOF
}


# --------------------------
# ECS Events errors to SNS
# --------------------------

resource "aws_sns_topic" "events_opsgenie" {
  name = "events-opsgenie"
}

resource "aws_sns_topic_policy" "events_opsgenie" {
  arn = aws_sns_topic.events_opsgenie.arn

  policy = data.aws_iam_policy_document.events_opsgenie.json
}

data "aws_iam_policy_document" "events_opsgenie" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        data.aws_caller_identity.current.account_id,
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.events_opsgenie.arn,
    ]

    sid = "__default_statement_ID"
  }

  statement {
    actions = [
      "sns:Publish"
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [
      aws_sns_topic.events_opsgenie.arn,
    ]

    sid = "AWSEvents_ecs_container_failures"
  }
}

resource "aws_sns_topic_subscription" "events-opsgenie" {
  topic_arn               = aws_sns_topic.events_opsgenie.arn
  protocol                = "https"
  endpoint                = data.aws_ssm_parameter.opsgenie_ecs_alerts_endpoint.value
  endpoint_auto_confirms  = true
}

resource "aws_cloudwatch_event_rule" "ecs_tasks_failures" {
  description = "ECS Task failures"
  is_enabled  = false
  name        = "ecs-tasks-failures"
  event_pattern = <<-EOF
  {
    "source": [
      "aws.ecs"
    ],
    "detail-type": [
      "ECS Task State Change"
    ],
    "detail": {
      "lastStatus": [
        "STOPPED"
      ],
      "stoppedReason": [
        "Essential container in task exited"
      ],
      "containers": {
        "exitCode": [
          {
            "anything-but": 0
          }
        ]
      }
    }
  }
  EOF
}

resource "aws_cloudwatch_event_target" "sns-events-opsgenie" {
  rule      = aws_cloudwatch_event_rule.ecs_tasks_failures.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.events_opsgenie.arn
}