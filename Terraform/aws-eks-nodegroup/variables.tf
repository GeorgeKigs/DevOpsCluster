variable "tags" {
  description = "tags to be used on project"
  type        = map(any)
}

variable "region" {
  description = "Region used for project"
  type        = string
}

variable "project" {
  description = "project name"
  type        = string
}

## EKS Nodes Variables

# Launch Template Variables
variable "eks_cluster_id" {
  description = "ID to the EKS cluster"
  type        = string
}

variable "instance_type_lt" {
  description = "Instance type to use with EKS launch template"
  type        = string
}

variable "volume_size" {
  description = "Disk size to be used"
  type        = number
}

variable "volume_type" {
  description = "volume type to use"
  type        = string
}

variable "eks_cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "node_group_name" {
  description = "The end prefix for the node group"
  type        = string
}

variable "eks_worker_subnet_id" {
  description = "The EKS workers subnet ids"
  type        = list(string)
}

variable "ami_type" {
  description = "ami type to use"
  type        = string
}

variable "lt_version" {
  description = "The version of the launch template"
  type        = string
}
variable "desired_size" {
  description = "Desired size of eks scaling"
  type        = number
}

variable "max_size" {
  description = "Max size for eks scaling"
  type        = number
}

variable "min_size" {
  description = "Min size for eks scaling"
  type        = number
}
variable "create_launch_template" {
  description = "Determines whether to create a launch template or not. If set to `false`, EKS will use its own default launch template"
  type        = bool
  default     = true
}

variable "capacity_type" {
  description = "Capacity type to use"
  type        = string
}

variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))
}

## Karpenter Variables
/* variable "karpenter_namespace" {
  type = string
}

variable "karpenter_version" {
  type = string
} */

/* variable "launch_template" {
  type = string
} */


/* variable "karpenter_target_nodegroup" {
  description = "The node group to deploy Karpenter to"
  type        = string
} */

variable "bottlerocket_k8s_version" {
  description = "Kubernetes version for bottlerocket AMI"
  default     = "1.25"
  type        = string
}

/* variable "karpenter_ec2_instance_types" {
  description = "List of instance types that can be used by Karpenter"
  type        = list(string)
}

variable "karpenter_vpc_az" {
  description = "List of availability zones for the Karpenter to provision resources"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "karpenter_ec2_arch" {
  description = "List of CPU architecture for the EC2 instances provisioned by Karpenter"
  type        = list(string)
  default     = ["amd64"]
}


variable "karpenter_ec2_capacity_type" {
  description = "EC2 provisioning capacity type"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "karpenter_ttl_seconds_after_empty" {
  description = "Node lifetime after empty"
  type        = number
}

variable "karpenter_ttl_seconds_until_expired" {
  description = "Node maximum lifetime"
  type        = number
} */
