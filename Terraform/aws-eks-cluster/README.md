## AWS_EKS_Cluster

This module creates an EKS cluster Resources.

## Deploys Elastic Kubernetes Service Cluster on AWS Environment

This Terraform module deploys Amazon Elastic Kubernetes Service Cluster.

> Note: For the module to work, it needs several required variables corresponding to existing resources in AWS. Please refer to the variable section for the list of required variables.

## Getting started

The following example contains the bare minimum options to be configured for Elastic Kubernetes Service Cluster deployment. 


First, create a `version.tf` file.

Next, copy the code below.

```hcl
terraform {
  backend "remote" {
    hostname     = "terraform.safaricom.net"
    organization = "safaricom-dit"

    workspaces {
      name = "uat"
    }
  }
  required_providers {
    vsphere = {
      source  = "hashicorp/aws"
      version = ">= 2.49"
    }
  }
}
```


Next, create `main.tf` file

Coy the code below:

```hcl
module "eks_cluster" {
  source  = "terraform.safaricom.net/safaricom-dit/eks-cluster/aws"
  version = "0.0.2" *Confirm latest Version from Terraform Enterprise

  cluster_policy_arn = "${var.eks_cluster_cluster_policy_arn}"
  eks_version = "${var.eks_cluster_eks_version}"
  endpoint_private_access = "${var.eks_cluster_endpoint_private_access}"
  endpoint_public_access = "${var.eks_cluster_endpoint_public_access}"
  node_sg = "${var.eks_cluster_node_sg}"
  private_subnet1 = "${var.eks_cluster_private_subnet1}"
  private_subnet2 = "${var.eks_cluster_private_subnet2}"
  project = "${var.eks_cluster_project}"
  public_access_cidrs = "${var.eks_cluster_public_access_cidrs}"
  region = "${var.eks_cluster_region}"
  security_group_create_timeout = "${var.eks_cluster_security_group_create_timeout}"
  security_group_delete_timeout = "${var.eks_cluster_security_group_delete_timeout}"
  security_group_inbound_rule_description = "${var.eks_cluster_security_group_inbound_rule_description}"
  security_group_inbound_rule_port = "${var.eks_cluster_security_group_inbound_rule_port}"
  security_group_item = "${var.eks_cluster_security_group_item}"
  security_group_outbound_rule_description = "${var.eks_cluster_security_group_outbound_rule_description}"
  security_group_outbound_rule_port = "${var.eks_cluster_security_group_outbound_rule_port}"
  security_group_project = "${var.eks_cluster_security_group_project}"
  security_group_region = "${var.eks_cluster_security_group_region}"
  security_group_revoke_rules_on_delete = "${var.eks_cluster_security_group_revoke_rules_on_delete}"
  security_group_security_group_description = "${var.eks_cluster_security_group_security_group_description}"
  security_group_source_sg = "${var.eks_cluster_security_group_source_sg}"
  security_group_tags = "${var.eks_cluster_security_group_tags}"
  security_group_vpc = "${var.eks_cluster_security_group_vpc}"
  service_policy_arn = "${var.eks_cluster_service_policy_arn}"
  tags = "${var.eks_cluster_tags}"
  vpc = "${var.eks_cluster_vpc}"
}
```

Next, create `variables.tf` file

Coy the code below:

```hcl
variable "eks_cluster_cluster_policy_arn" {}
variable "eks_cluster_eks_version" {}
variable "eks_cluster_endpoint_private_access" {}
variable "eks_cluster_endpoint_public_access" {}
variable "eks_cluster_node_sg" {}
variable "eks_cluster_private_subnet1" {}
variable "eks_cluster_private_subnet2" {}
variable "eks_cluster_project" {}
variable "eks_cluster_public_access_cidrs" {}
variable "eks_cluster_region" {}
variable "eks_cluster_security_group_create_timeout" {}
variable "eks_cluster_security_group_delete_timeout" {}
variable "eks_cluster_security_group_inbound_rule_description" {}
variable "eks_cluster_security_group_inbound_rule_port" {}
variable "eks_cluster_security_group_item" {}
variable "eks_cluster_security_group_outbound_rule_description" {}
variable "eks_cluster_security_group_outbound_rule_port" {}
variable "eks_cluster_security_group_project" {}
variable "eks_cluster_security_group_region" {}
variable "eks_cluster_security_group_revoke_rules_on_delete" {}
variable "eks_cluster_security_group_security_group_description" {}
variable "eks_cluster_security_group_source_sg" {}
variable "eks_cluster_security_group_tags" {}
variable "eks_cluster_security_group_vpc" {}
variable "eks_cluster_service_policy_arn" {}
variable "eks_cluster_tags" {}
variable "eks_cluster_vpc" {}
```

Finally, push your code to gitlab, terraform enterprise will pick from there.

## Contributing

This module is the work of the below contributors. We appreciate your help!

 1. Noah Makau

## License

[MIT](LICENSE)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 2.49 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.60.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.4 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.addons](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_addon.cni_addons](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_cluster.eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_iam_openid_connect_provider.eks_cluster_oidc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_policy.alb_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.dxl_sa_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.flux_kustomize_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.web_sa_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.alb_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.cni_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.dxl_sa_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.flux_kustomize_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.iam_role_eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.web_sa_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eks_cluster_AmazonEKSServicePolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.encyption_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_security_group.eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.cluster_inbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_eks_cluster.eks_cluster_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_policy_document.alb_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cluster_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.dxl_sa_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.flux_kustomize_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.web_sa_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_security_group.eks_created_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group) | data source |
| [tls_certificate.eks_cluster_oidc_cert](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addons"></a> [addons](#input\_addons) | n/a | <pre>list(object({<br>    name    = string<br>    version = string<br>  }))</pre> | <pre>[<br>  {<br>    "name": "kube-proxy",<br>    "version": "v1.24.9-eksbuild.1"<br>  }<br>]</pre> | no |
| <a name="input_cloud9_sg_id"></a> [cloud9\_sg\_id](#input\_cloud9\_sg\_id) | n/a | `list(string)` | `[]` | no |
| <a name="input_cluster_policy_arn"></a> [cluster\_policy\_arn](#input\_cluster\_policy\_arn) | value | `string` | n/a | yes |
| <a name="input_eks_version"></a> [eks\_version](#input\_eks\_version) | The EKS version to use | `string` | n/a | yes |
| <a name="input_endpoint_private_access"></a> [endpoint\_private\_access](#input\_endpoint\_private\_access) | n/a | `bool` | n/a | yes |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | n/a | `bool` | n/a | yes |
| <a name="input_flux_kustomize_sops_kms_arn"></a> [flux\_kustomize\_sops\_kms\_arn](#input\_flux\_kustomize\_sops\_kms\_arn) | arn to sops key | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | project name | `string` | n/a | yes |
| <a name="input_public_access_cidrs"></a> [public\_access\_cidrs](#input\_public\_access\_cidrs) | n/a | `list(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region used for project | `string` | n/a | yes |
| <a name="input_service_policy_arn"></a> [service\_policy\_arn](#input\_service\_policy\_arn) | value | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | tags to be used on project | `map(any)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID for target VPC | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_eks_cluster_arn"></a> [eks\_cluster\_arn](#output\_eks\_cluster\_arn) | ARN of the eks cluster |
| <a name="output_eks_cluster_created_sg_id"></a> [eks\_cluster\_created\_sg\_id](#output\_eks\_cluster\_created\_sg\_id) | n/a |
| <a name="output_eks_cluster_id"></a> [eks\_cluster\_id](#output\_eks\_cluster\_id) | ARN of the eks cluster |
| <a name="output_eks_cluster_name"></a> [eks\_cluster\_name](#output\_eks\_cluster\_name) | ARN of the eks cluster |
| <a name="output_eks_cluster_sg_id"></a> [eks\_cluster\_sg\_id](#output\_eks\_cluster\_sg\_id) | The id of the created security group |
<!-- END_TF_DOCS -->