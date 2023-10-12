# Implementation of Kubernetes the Hard Way on AWS

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
- [jq](https://stedolan.github.io/jq/download/)
- [cfssl]
- [cfssljson]

## Workflow
1. Create the infrastructure needed for the Kubernetes cluster

This will involve setting up the following AWS resources.
Network: VPC, Internet Gateway, Route Table, 2 Subnets, Security Groups
Compute: 4 EC2 instances, 2 for the controller and 2 for the worker node
Load Balancer: 1 Network ELB for the controller

Structure of the VPC
- The security group will also allow all traffic from the private IP address of the other EC2 instances
- The 2 cidr blocks for the subnets will be 10.0.0.0/25 (services cidr block) and 10.0.0.128/16 (pod cidr block)

Structure of the Nodes
- The EC2 instances will be created with the latest Ubuntu AMI
- The EC2 instances will be created with a key pair that will be used to SSH into the instances
- The EC2 instances will be created with a security group that will allow SSH access from the public IP address of the machine running the script



2. Provision the Kubernetes controllers