provider "aws" {
  region = var.aws_region
}

# VPCs
module "core_vpcs" {
  for_each = var.core_vpcs
  source = "./modules/vpc"
  vpc_name = "${each.key}-vpc"
  vpc_cidr = each.value.cidr
  subnets = each.value.subnets
}

module "workload_vpcs" {
  for_each = var.workload_vpcs
  source = "./modules/vpc"
  vpc_name = "workload-${each.key}-vpc"
  vpc_cidr = each.value.cidr
  subnets = each.value.subnets
}

# Transit Gateway
module "tgw" {
  source = "./modules/twg"
  vpc_attachments = merge(
    {
      for k, v in module.core_vpcs : k => { 
        vpc_id = v.vpc_id,
        subnet_id = v.interfacing_subnet_id
      }
    },
    {
      for k, v in module.workload_vpcs : "workload-${k}" => { 
        vpc_id = v.vpc_id,
        subnet_id = v.interfacing_subnet_id
      }
    }
  )
}

# Routes to TGW
resource "aws_route" "core_interfacing_to_tgw" {
  for_each = { 
    for k, v in var.core_vpcs : k => v 
    if anytrue([for s in v.subnets : s.type == "interfacing"])
  }
  route_table_id = module.core_vpcs[each.key].interfacing_route_table_id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id = module.tgw.tgw_id
}

resource "aws_route" "workload_interfacing_to_tgw" {
  for_each = { 
    for k, v in var.workload_vpcs : k => v 
    if anytrue([for s in v.subnets : s.type == "interfacing"])
  }
  route_table_id = module.workload_vpcs[each.key].interfacing_route_table_id
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id = module.tgw.tgw_id
}

# Endpoints to workload x
module "endpoints_workload_x" {
  source = "./modules/endpoints"
  name = "workload-x"
  vpc_id = module.workload_vpcs["x"].vpc_id

  subnet_ids = [
    module.workload_vpcs["x"].subnet_ids["compute"],
    module.workload_vpcs["x"].subnet_ids["compute_b"]
  ]

  route_table_ids = [module.workload_vpcs["x"].private_route_table_id]
}