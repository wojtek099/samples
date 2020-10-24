variable "app" {
    type        = string
    description = "application name used in resource names"
}

variable "batch_service_role_attachment" {
    type        = map
    description = "Batch Service Role attachment which Compute Environments depend on"
}

variable "name" {
    type        = string
}

variable "batch_service_role" {
    type        = string
    description = "Batch Service Role which Batch uses"
}

variable "desired_vcpus" {
    type        = number
}

variable "key" {
    type        = string
    description = "EC2 key pair"
}

variable "ecs_instance_profile" {
    type        = string
    description = "instance profile for ECS Container Instances"
}

variable "max_vcpus" {
    type        = number
}

variable "min_vcpus" {
    type        = number
}

variable "security_groups" {
    type        = list
    description = "list of security groups set in compute environments"
}

variable "subnets" {
    type        = list
    description = "list subnets set in compute environments (prv in platform VPC)"
}

variable "compute_type" {
    type        = string
    description = "EC2 | SPOT"
}

variable "instance_type" {
    type        = list
    description = "e.g. [m5]"
}