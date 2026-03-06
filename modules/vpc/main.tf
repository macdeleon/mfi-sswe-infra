resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "subnets" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${var.vpc_name}-${each.key}"
    Type = each.value.type
  }
}

resource "aws_internet_gateway" "igw" {
  count  = anytrue([for s in var.subnets : s.type == "public"]) ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_route_table" "public" {
  count  = anytrue([for s in var.subnets : s.type == "public"]) ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = anytrue([for s in var.subnets : s.type == "private"]) ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-private-rt"
  }
}

resource "aws_route_table" "interfacing" {
  count  = anytrue([for s in var.subnets : s.type == "interfacing"]) ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-interfacing-rt"
  }
}

resource "aws_route_table_association" "assoc" {
  for_each  = aws_subnet.subnets
  subnet_id = each.value.id
  route_table_id = (
    var.subnets[each.key].type == "public" ? aws_route_table.public[0].id :
    var.subnets[each.key].type == "interfacing" ? aws_route_table.interfacing[0].id :
    aws_route_table.private[0].id
  )
}

# Network ACL for Firewall subnet
resource "aws_network_acl" "firewall_nacl" {
  count  = anytrue([for s in var.subnets : s.has_firewall]) ? 1 : 0
  vpc_id = aws_vpc.main.id

  # Internet -> HTTP
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Internet -> HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # VPC -> VPC (Internal communication)
  ingress {
    protocol   = "-1"
    rule_no    = 120
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Forwading to internal subnets
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Outbound web traffic to Internet
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 443
  }

  # Forwading to internal subnets
  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "${var.vpc_name}-firewall-nacl"
  }
}

resource "aws_network_acl_association" "firewall_assoc" {
  for_each = {
    for k, v in aws_subnet.subnets : k =>
    v.id if var.subnets[k].has_firewall
  }
  network_acl_id = aws_network_acl.firewall_nacl[0].id
  subnet_id      = each.value
}