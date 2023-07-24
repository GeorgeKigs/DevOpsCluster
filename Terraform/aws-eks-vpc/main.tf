## Data Block to use
data "aws_availability_zones" "available" {}

## VPC and Primary CIDR Block
resource "aws_vpc" "vpc" {
  # checkov:skip=CKV_AWS_130: Ensure VPC subnets do not assign public IP by default
  # checkov:skip=CKV2_AWS_11: Sandbox account ignoring vpc logging
  cidr_block           = var.primary_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-VPC"
    },
  )
}

# Secondary CIDR Block --- why do we need a secondary cidr block?
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.secondary_cidr
}

## Restrict inbound and outbound rules on default Security group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.vpc.id
}

## Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-IGW"
    },
  )
}

# Create the public subnets
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.public_subnets_cidr)

  cidr_block              = element(var.public_subnets_cidr, count.index)
  # three availabilty zones, what if there are more public subnets to be created?
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = var.public_map_public_ip_on_launch

  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-PublicSubnet0${count.index + 1}"
      "kubernetes.io/role/elb" = 1
    },
  )
}

# Create the private Application/EKS subnets
resource "aws_subnet" "private_eks" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.private_eks_subnets_cidr)

  cidr_block              = element(var.private_eks_subnets_cidr, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = false
  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-EKS-PrivateSubnet0${count.index + 3}"
      "kubernetes.io/role/internal-elb" = 1
    },
  )
}

# Create the private data subnets
resource "aws_subnet" "private_data" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.private_data_subnets_cidr)
  
  cidr_block              = element(var.private_data_subnets_cidr, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-DATA-PrivateSubnet0${count.index + 5}"
    },
  )
}

# Create the additional subnets on secondary CIDR for EKS  nodes
resource "aws_subnet" "eks_nodes" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.eks_nodes_subnets_cidr)
  cidr_block              = element(var.eks_nodes_subnets_cidr, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-EKS-Nodes-PrivateSubnet0${count.index + 11}"
    },
  )
}

resource "aws_eip" "elastic_ip" {
  vpc      = true
}

## Nat Gateway for private subnets
resource "aws_nat_gateway" "private_ngw" {
  # setting up the NAT in the initial subnet
  subnet_id         = element(aws_subnet.public.*.id, 0)
  connectivity_type = var.connectivity_type
  allocation_id = aws_eip.elastic_ip.id

  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-NatGW"
    },
  )
}

##Public Route Table with the IGW
resource "aws_route_table" "public_rtb" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block      = var.public_rtb_cidr
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-PublicSubnets-RouteTable"
    },
  )
}

resource "aws_route_table_association" "public_rtb_ass" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public_rtb.id
}

# Private Application subnet routing table and association ith the NAT Gateway
resource "aws_route_table" "private_eks_rtb" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block         = var.private_eks_rtb_cidr
    nat_gateway_id = aws_nat_gateway.private_ngw.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-PrivateSubnets03-04-RouteTable"
    },
  )
}

resource "aws_route_table_association" "private_eks_rtb_ass" {
  count          = length(var.private_eks_subnets_cidr)
  subnet_id      = element(aws_subnet.private_eks.*.id, count.index)
  route_table_id = aws_route_table.private_eks_rtb.id
}

# Private Data subnet routing table and association
resource "aws_route_table" "private_data_rtb" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block         = var.private_data_rtb_cidr
    nat_gateway_id = aws_nat_gateway.private_ngw.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-PrivateSubnets05-06-RouteTable"
    },
  )
}

resource "aws_route_table_association" "private_data_rtb_ass" {
  count          = length(var.private_data_subnets_cidr)
  subnet_id      = element(aws_subnet.private_data.*.id, count.index)
  route_table_id = aws_route_table.private_data_rtb.id
}

# Private EKS Workers routing table and association
resource "aws_route_table" "eks_nodes_rtb" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block     = var.eks_nodes_rtb_cidr
    nat_gateway_id = aws_nat_gateway.private_ngw.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-eks-Nodes-Subnets-RouteTable"
    },
  )
}

resource "aws_route_table_association" "eks_nodes_rtb_ass" {
  count          = length(var.eks_nodes_subnets_cidr)
  subnet_id      = element(aws_subnet.eks_nodes.*.id, count.index)
  route_table_id = aws_route_table.eks_nodes_rtb.id
}