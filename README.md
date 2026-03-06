# Hub & Spoke Architecture for MFI

This repository contains OpenTofu configuration for a multi-VPC architecture on AWS, designed to support a Hub-and-Spoke model using Transit Gateway. It provides a scalable and secure foundation for isolating core services from workload-specific resources.

## Architecture Overview

The project implements a centralized networking strategy:

- **Core VPCs:** Hub VPCs for shared services, shared networking, or security inspection.
- **Workload VPCs:** Isolated spoke VPCs for application-specific resources.
- **Transit Gateway (TGW):** The central hub that interconnects all VPCs via TGW attachments.
- **Service Endpoints:** Centralized access to AWS services (e.g., S3) and internal Application Load Balancers (ALB) for service-to-service communication.

### Key Components

- **`modules/vpc`**: Manages VPC creation, subnets (Public, Private, Interfacing), Internet Gateways, and Route Tables.
- **`modules/twg`**: Deploys the Transit Gateway and manages VPC attachments.
- **`modules/endpoints`**: Configures Security Groups, internal ALBs, and Interface/Gateway VPC Endpoints.

## Project Structure

```text
.
├── main.tf                # Root module: orchestrates VPCs, TGW, and Endpoints
├── variables.tf           # Global variables
├── dev.tfvars             # Development environment configuration
├── modules/
│   ├── vpc/               # VPC, Subnets, NACL, and Basic Routing
│   ├── twg/               # Transit Gateway and VPC Attachments
│   └── endpoints/         # ALB and AWS Service Endpoints
```

## Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/) (>= 1.6.0)
- AWS CLI configured with appropriate credentials.
- An S3 bucket for remote state (as a sample of the service endpoints setup).

## Getting Started

### 1. Initialize OpenTofu

```bash
tofu init
```

### 2. Select Workspace

The current project setup is using **dev** workspace to spin up the infrastructure. 

```bash
tofu workspace select dev || tofu workspace new dev
```

### 3. Plan Deployment

Review the execution plan:

```bash
tofu plan -var-file="dev.tfvars"
```

### 4. Apply Changes

Deploy the infrastructure:

```bash
tofu apply -var-file="dev.tfvars"
```

## Configuration

The project uses `tfvars` files to define environment-specific settings. 

### VPC Configuration Example (`dev.tfvars`)

```hcl
aws_region = "ap-southeast-1"

core_vpcs = {
  internet = {
    cidr = "10.0.0.0/16"
    subnets = {
      "public" = {
        cidr = "10.0.1.0/24",
        type = "public",
        az = "ap-southeast-1a"
      },
      "firewall" = {
        cidr = "10.0.2.0/24",
        type = "private",
        az = "ap-southeast-1a",
        has_firewall = true
      },
      "interfacing" = {
        cidr = "10.0.3.0/24",
        type = "interfacing",
        az = "ap-southeast-1a"
      }
    }
  }
  gen = {
    cidr = "10.1.0.0/16"
    subnets = {
      "public" = {
        cidr = "10.1.1.0/24",
        type = "public",
        az = "ap-southeast-1a"
      },
      "interfacing" = {
        cidr = "10.1.2.0/24",
        type = "interfacing",
        az = "ap-southeast-1a"
      }
    }
  }
}

workload_vpcs = {
  "x" = {
    cidr = "10.2.0.0/16"
    subnets = {
      "web"         = {
        cidr = "10.2.1.0/24",
        type = "private",
        az = "ap-southeast-1a"
      }
      "compute"     = { 
        cidr = "10.2.2.0/24",
        type = "private",
        az = "ap-southeast-1a"
      }
      "data"        = { 
        cidr = "10.2.3.0/24",
        type = "private",
        az = "ap-southeast-1a"
      }
      "interfacing" = { 
        cidr = "10.2.4.0/24",
        type = "interfacing",
        az = "ap-southeast-1a"
      }
      "compute_b"     = { 
        cidr = "10.2.5.0/24",
        type = "private",
        az = "ap-southeast-1b"
      }
    }
  }
  "y" = {
    cidr = "10.3.0.0/16"
    subnets = {
      "interfacing" = {
        cidr = "10.3.1.0/24",
        type = "interfacing",
        az = "ap-southeast-1a"
      }
    }
  }
  "z" = {
    cidr = "10.4.0.0/16"
    subnets = {
      "interfacing" = {
        cidr = "10.4.1.0/24",
        type = "interfacing",
        az = "ap-southeast-1a"
      }
    }
  }
}
```

### Security Flaws ###
1. **Permissive NACL Setup** - The firewall_nacl allow all traffic on ingress ports 80/443 and egress for all ports. If an attacker gains control of a resource in a subnet protected by this NACL, they can use port 443 to exfiltrate the data to the internet. To improve on this, a Network firewall can be added to further strengthen the security in the system. However, for simplicity and cost-efficiency, I opted to go with a NACL setup for this example.
2. **Flat Routing Table** - The current Transit Gateway setup uses 10.0.0.0/8 range in every VPC's route table. This results to a direct and unrestricted path to every other segment at the routing level. An attacker can scan and map out the entire internal infrastructure with the TGW helping to attempt to route the pings to the resources. Resources such as database, internal load balancers, or other internal resources can be mapped out. The firewall subnet in the core-internet VPC may be bypassed as well given that the a more specific route table needs to be defined to instruct traffic to pass through the firewall subnet.
3. **Stateless Security** - The current infrastructure employs Network ACLs (NACLs) for select subnets. Because NACLs are stateless and only inspect traffic headers (IP/Port), they lack the context of a connection. This requires opening broad ephemeral port ranges for return traffic, which an attacker can exploit for reconnaissance. Furthermore, NACLs cannot distinguish between legitimate traffic and malicious payloads from a compromised "trusted" internal IP. To achieve a zero-trust architecture, the project should migrate to AWS Network Firewall to enable Deep Packet Inspection (DPI) and stateful traffic filtering.


### Trade Offs ###
1. **NACL vs AWS Network Firewall**
  Related to potential security flaw #1, this trade off is between **Cost/Simplicity** and **Advanced Protection**.
  - NACL: cost is free, however, setup must be done individually on the subnets that requires it.
  - AWS Network Firewall: cost is based on the usage, but provides a centralized model for network security.
2. **Transit Gateway vs Direct VPC Peering**
  - Transit Gateway has simplified management of inter-related VPCs that avoids mesh of peering connections. VPCs can interact between each other through the TGW.
  - Direct VPC Peering is a low cost solution for inter VPC connections. Provides high performance given that a direct line connection is created between 2 VPCs. Management could be challenging and could end up with a 'spaghetti' setup.
3. **Distributed Endpoints vs Centralized Shared Services VPC**
  - Current setup deploys resources such as Gateway Endpoints and Internal ALB in each of the workload VPCs (as defined). The cost is multiplied based on the number of VPCs that needs this setup.
  - Centralized Shared Service VPC will introduce another VPC solely for resources that are shared across the workload VPCs. The TGW will manage the traffic from a workload VPC to a Shared resources within this new VPC. However, the cost will also depend on the traffic being sent into the TGW.
