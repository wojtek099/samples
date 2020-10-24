variable "ENV" {
  type = string
  default = "stage"
}
variable "app" {
  type = string
}
variable "region" {
  type = string
  description = "region for AWS provider"
  default = "eu-west-1"
}

variable "key" {
  type = map
  description = "EC2 key pairs"
  default = {
    "stage" = "jp-dev"
    "prod" = "jp-prod"
  }
}

variable "security_groups" {
  type = list
  description = "list of security groups set in compute environments"
}

variable "subnets" {
  type = list
  description = "list subnets set in compute environments (prv in platform VPC)"
}

variable "compute_environments" {}

variable "queues" {}

variable "batch_jobs" {}

variable "event_rules" {}