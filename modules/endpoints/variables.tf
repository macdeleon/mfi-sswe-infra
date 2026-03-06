variable "vpc_id" {
  description = "VPC ID where endpoints will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB and Endpoint"
  type        = list(string)
}

variable "route_table_ids" {
  description = "List of route table IDs to associate with the Gateway Endpoint"
  type        = list(string)
  default     = []
}

variable "name" {
  description = "Name prefix for the resource"
  type        = string
}