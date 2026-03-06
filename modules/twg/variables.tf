variable "vpc_attachments" {
  description = "Map of VPC names to their IDs and subnet ID (interfacing)"
  type = map(object({
    vpc_id = string
    subnet_id = string
  }))
}