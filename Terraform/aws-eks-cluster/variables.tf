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


## EKS Variables
### IAM role Variables.
variable "cluster_policy_arn" {
  description = "value"
  type        = string
}

variable "service_policy_arn" {
  description = "value"
  type        = string
}

variable "flux_kustomize_sops_kms_arn" {
  description = "arn to sops key"
  type        = string
}

## Security Group Variables
variable "vpc_id" {
  description = "VPC ID for target VPC"
  type        = string
}
variable "eks_version" {
  description = "The EKS version to use"
  type        = string
}

variable "endpoint_private_access" {
  type = bool
}

variable "endpoint_public_access" {
  type = bool
}

variable "public_access_cidrs" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cloud9_sg_id" {
  type    = list(string)
  default = []
}

variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))

  default = [
    {
      name    = "kube-proxy"
      version = "v1.27.1-eksbuild.1"
    }
  ]
}

