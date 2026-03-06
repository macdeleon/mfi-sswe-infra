output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  value = { for k, v in aws_subnet.subnets : k => v.id }
}

output "interfacing_subnet_id" {
  value = try(aws_subnet.subnets["interfacing"].id, null)
}

output "interfacing_route_table_id" {
  value = try(aws_route_table.interfacing[0].id, null)
}

output "private_route_table_id" {
  value = try(aws_route_table.private[0].id, null)
}

output "public_route_table_id" {
  value = try(aws_route_table.public[0].id, null)
}
