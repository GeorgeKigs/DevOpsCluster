## AWS_EKS_Node Group

This module creates an EKS node group Resources.

## Deploys Elastic Kubernetes Service Nodes on AWS Environment

This Terraform module deploys Amazon Elastic Kubernetes Service Node Group.

> Note: For the module to work, it needs several required variables corresponding to existing resources in AWS. Please refer to the variable section for the list of required variables.

## Getting started

The following example contains the bare minimum options to be configured for Elastic Kubernetes Service Node Group deployment. 


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
      version = "~> 2.2.0"
    }
  }
}
```


Next, create `main.tf` file

Coy the code below:

```hcl

```

Next, create `variables.tf` file

Coy the code below:

```hcl

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
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.62.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.addons](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_eks_node_group.node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_role.eks_nodes_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.AmazonElasticFileSystemFullAccess](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.AmazonSSMManagedInstanceCore](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.CloudWatchAgentServerPolicy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.eks-launch-template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addons"></a> [addons](#input\_addons) | n/a | <pre>list(object({<br>    name    = string<br>    version = string<br>  }))</pre> | <pre>[<br>  {<br>    "name": "coredns",<br>    "version": "v1.9.3-eksbuild.2"<br>  }<br>]</pre> | no |
| <a name="input_ami_type"></a> [ami\_type](#input\_ami\_type) | ami type to use | `string` | n/a | yes |
| <a name="input_capacity_type"></a> [capacity\_type](#input\_capacity\_type) | Capacity type to use | `string` | n/a | yes |
| <a name="input_create_launch_template"></a> [create\_launch\_template](#input\_create\_launch\_template) | Determines whether to create a launch template or not. If set to `false`, EKS will use its own default launch template | `bool` | `true` | no |
| <a name="input_desired_size"></a> [desired\_size](#input\_desired\_size) | Desired size of eks scaling | `number` | n/a | yes |
| <a name="input_eks_cluster_id"></a> [eks\_cluster\_id](#input\_eks\_cluster\_id) | ID to the EKS cluster | `string` | n/a | yes |
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | The name of the cluster | `string` | n/a | yes |
| <a name="input_eks_worker_subnet_id"></a> [eks\_worker\_subnet\_id](#input\_eks\_worker\_subnet\_id) | The EKS workers subnet ids | `list(string)` | n/a | yes |
| <a name="input_instance_type_lt"></a> [instance\_type\_lt](#input\_instance\_type\_lt) | Instance type to use with EKS launch template | `string` | n/a | yes |
| <a name="input_lt_version"></a> [lt\_version](#input\_lt\_version) | The version of the launch template | `string` | n/a | yes |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Max size for eks scaling | `number` | n/a | yes |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Min size for eks scaling | `number` | n/a | yes |
| <a name="input_node_group_name"></a> [node\_group\_name](#input\_node\_group\_name) | The end prefix for the node group | `string` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | project name | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region used for project | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | tags to be used on project | `map(any)` | n/a | yes |
| <a name="input_volume_size"></a> [volume\_size](#input\_volume\_size) | Disk size to be used | `number` | n/a | yes |
| <a name="input_volume_type"></a> [volume\_type](#input\_volume\_type) | volume type to use | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->