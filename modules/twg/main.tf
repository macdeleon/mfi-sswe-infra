resource "aws_ec2_transit_gateway" "main" {
  description = "Central Transit Gateway for all VPCs"

  tags = {
    Name = "central-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attachments" {
  for_each           = var.vpc_attachments
  subnet_ids         = [each.value.subnet_id]
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = each.value.vpc_id

  tags = {
    Name = "${each.key}-tgw-attachment"
  }
}