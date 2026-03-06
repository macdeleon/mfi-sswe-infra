resource "aws_security_group" "alb_sg" {
  name        = "${var.name}-alb-sg"
  description = "Security group for the ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTPS from internal network"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "Allow HTTP for redirect to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    description = "Allow egress to internal targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name = "${var.name}-alb-sg"
  }
}

resource "aws_lb" "alb" {
  name               = "${var.name}-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids

  tags = {
    Name = "${var.name}-alb"
  }
}

# Consuming API (e.g. S3 service)
resource "aws_vpc_endpoint" "s3_consuming_endpoint" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.ap-southeast-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = {
    Name = "${var.name}-s3-consuming-endpoint"
  }
}