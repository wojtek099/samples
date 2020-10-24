variable "app" {
    type        = string
}

variable "ENV" {
    type        = string
}

variable "name" {
    type        = string
}

variable "command" {
    type        = string
}

variable "repository_url" {
    type        = string
}

variable "task_role" {
    type        = string
}

variable "memory" {
    type        = number
}

variable "vcpus" {
    type        = number
}

variable "timeout" {
    type        = number
}