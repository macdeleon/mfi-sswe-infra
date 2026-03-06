variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "core_vpcs" {
  description = "Configuration for the core VPCs"
  type = map(object({
    cidr = string
    subnets = map(object({
      cidr         = string
      type         = string
      az           = string
      has_firewall = optional(bool, false)
    }))
  }))
}

variable "workload_vpcs" {
  description = "Configuration for the workload VPCs"
  type = map(object({
    cidr = string
    subnets = map(object({
      cidr         = string
      type         = string
      az           = string
      has_firewall = optional(bool, false)
    }))
  }))
}