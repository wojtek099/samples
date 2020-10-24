terraform {
  backend "s3" {
    region = "eu-west-1"
  }
}

provider "aws" {
  region = var.region
}

module "common" {
  source            = "./modules/common"
  app               = var.app
  ENV               = var.ENV
  ssp_to_s3_image   = "ssp-to-s3"
  data_utils_image  = "data-utils"
  sitedata_image    = "sitedata"
}

module "compute_environment" {
  for_each = var.compute_environments

  source                        = "./modules/compute_environment"
  app                           = var.app
  batch_service_role_attachment = module.common.batch_service_role_attachment
  name                          = each.value.name   
  batch_service_role            = module.common.batch_service_role
  desired_vcpus                 = each.value.desired_vcpus
  key                           = var.key[var.ENV]
  ecs_instance_profile          = module.common.ecs_instance_profile
  max_vcpus                     = each.value.max_vcpus
  min_vcpus                     = each.value.min_vcpus
  security_groups               = var.security_groups
  subnets                       = var.subnets
  compute_type                  = each.value.type
  instance_type                 = each.value.instance_type
}

module "queue" {
  for_each = var.queues

  source                = "./modules/queue"
  name                  = each.key
  app                   = var.app
  state                 = each.value.state
  priority              = each.value.priority
  compute_environments  = [
    for compute_env in each.value.compute_environment: 
    module.compute_environment[compute_env].arn
  ]
}

module "batch_job" {
  for_each = var.batch_jobs

  source          = "./modules/batch_job"
  app             = var.app
  ENV             = var.ENV
  name            = each.key
  command         = each.value.command
  repository_url  = module.common.repositories[each.value.repository].repository_url
  task_role       = module.common.task_role
  memory          = each.value.memory
  vcpus           = each.value.vcpus
  timeout         = each.value.timeout
}

module "event_rule" {
  for_each = var.event_rules

  source              = "./modules/event_rule"
  app                 = var.app
  description         = each.value.description
  is_enabled          = each.value.is_enabled
  name                = "${var.app}-${each.key}"
  schedule_expression = each.value.schedule_expression
  event_role          = module.common.event_role
  queue               = module.queue[each.value.queue].arn
  job_definition      = module.batch_job[each.value.job_definition].arn
}