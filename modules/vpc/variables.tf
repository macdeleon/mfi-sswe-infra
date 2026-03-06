variable "vpc_name" {
  description = "Name tag for the VPC"
  type = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type = string
}

variable "subnets" {
  description = "A map of subnet name to CIDR and type (private/public)"
  type = map(object({
    cidr = string
    type = string
    az = string
    has_firewall = optional(bool, false)
  }))
}