## Common Variables
variable "region" {
  description = "Region to create  resources"
  type        = string
}

variable "project" {
  description = "Name of project"
  type        = string
}

variable "tags" {
  description = "tags to be used on project"
  type        = map(any)
}

## Networking Variables
variable "primary_cidr" {
  type        = string
  description = "The cidr block value for the project vpc"
}

variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "secondary_cidr" {
  description = "List of secondary CIDR blocks to associate with the VPC to extend the IP Address pool"
  type        = string
}

variable "public_subnets_cidr" {
  description = "CIDR Blocks to use for public subnets"
  type        = list(string)
}

variable "public_map_public_ip_on_launch" {
  description = "Are we enabling public ip on public subnets"
  type        = bool
  default     = true
}


variable "private_eks_subnets_cidr" {
  description = "CIDR Blocks to use for private application/EKS subnets"
  type        = list(string)
}

variable "private_data_subnets_cidr" {
  description = "CIDR Blocks to use for private data subnets"
  type        = list(string)
}


variable "eks_nodes_subnets_cidr" {
  description = "CIDR Blocks to use for EKS nodes subnets"
  type        = list(string)
}

variable "connectivity_type" {
  description = "The connectivity type for the nat gateway"
  type        = string
  default     = "public"
}

variable "public_rtb_cidr" {
  description = "The cidr block value for public route table"
  type        = string
}

variable "private_eks_rtb_cidr" {
  description = "The cidr block value for private application route table"
  type        = string
}


variable "private_data_rtb_cidr" {
  description = "The cidr block value for private data route table"
  type        = string
}

variable "eks_nodes_rtb_cidr" {
  description = "The Cidr block value for the eks worker route table"
  type        = string
}