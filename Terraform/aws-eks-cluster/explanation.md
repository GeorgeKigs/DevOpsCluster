### AWS EKS Cluster Module
The code in this repository creates a single EKS Cluster and its resources in AWS. The module is hosted in a private Terraform Enterprise registry. 

The most current and stable version is __0.0.28__

The given code snippets are part of a Terraform configuration that creates a single EKS Cluster and its resources in AWS. The configuration is split across  files: **[versions.tf](#versions)**,**[cluster_iamrole.tf](#cluster_iamrole)**,**[main.tf](#main)**, **[securitygroup.tf](#securitygroup)**,**[variables.tf](#variables)**, and **[outputs.tf](#outputs)**.

Below is a brief of what each file contains:

## versions
This is the versions.tf file in Terraform, which is used to specify the version requirements for Terraform and its providers. In this example, it is requiring Terraform version 1.2.7 or higher, and the AWS provider version 2.49 or higher.

The terraform block is used to specify the version requirements for Terraform itself, while the required_providers block is used to specify the version requirements for each provider that will be used in the configuration. In this case, it is specifying the aws provider and requiring version 2.49 or higher.

These version requirements ensure that the configuration will only work with the specified versions of Terraform and the AWS provider, which can help to avoid unexpected errors or compatibility issues.

## cluster_iamrole
The file creates an AWS Identity and Access Management (IAM) role and attaches policies to it. It also sets up the necessary roles and policies for the AWS Load Balancer Controller and AWS node pods.

The aws_iam_role resource creates the IAM role for the EKS cluster. The assume_role_policy attribute sets the permissions that are required to assume the role. In this case, the policy allows the EKS service to assume the role.

Two aws_iam_role_policy_attachment resources attach the AmazonEKSClusterPolicy and AmazonEKSServicePolicy policies to the IAM role. These policies define the permissions required to create and manage EKS clusters.

Two more aws_iam_role resources create the roles necessary to enable IAM roles for service accounts for the AWS node pods and the AWS Load Balancer Controller. These roles have assume_role_policy attributes that specify the permissions required to assume the roles. The managed_policy_arns attributes specify the managed policies that are attached to the roles.

The aws_iam_policy resource creates the AWSLoadBalancerControllerIAMPolicy policy, which defines the permissions required to manage load balancers. The policy contains a set of permissions for managing Elastic Load Balancing, Amazon EC2, AWS WAF, AWS Shield, and Amazon Certificate Manager.

The data resource aws_iam_policy_document creates the JSON policy document that allows the IAM roles for the AWS node pods and AWS Load Balancer Controller to assume the roles. The values attributes in the condition blocks define the Kubernetes service accounts that are allowed to assume the roles. The principals attributes define the OpenID Connect (OIDC) providers that are allowed to assume the roles.

## main
This file creates an Amazon Elastic Kubernetes Service (EKS) cluster on AWS.

Here's a brief summary of what each section of the configuration file does:

OIDC: The first section creates an OpenID Connect (OIDC) provider that is used to authenticate users to the EKS cluster. It creates an IAM OpenID Connect Provider resource with a thumbprint of the TLS certificate that is used to secure the OIDC endpoint.

EKS Cluster: The second section creates the EKS cluster resource itself. It defines the name, version, and VPC configuration of the cluster. It also enables logging for various components of the EKS control plane and specifies the IAM role that EKS will use to manage the cluster. Additionally, it configures encryption for Kubernetes secrets using a KMS key.

KMS Key and Alias: The third section creates an AWS KMS key and an alias for the key.

Addons: The fourth section adds addons to the EKS cluster. It installs the specified addon version and resolves conflicts if there are any. It also creates a service account role for the VPC CNI addon.

## securitygroup
The securitygroup.tf file contains Terraform code to create and configure AWS security groups for an EKS cluster.

The first resource defined is an aws_security_group resource that creates a security group to allow communication between the EKS cluster and worker nodes. The security group allows all outbound traffic and is tagged with a name based on the region and project variables.

The second resource is an aws_security_group_rule resource that creates a security group rule allowing inbound traffic from Cloud9 instances to the EKS cluster API server. The count parameter allows the rule to be created for multiple Cloud9 security groups, as specified by the cloud9_sg_id variable.

The final resource is a data resource that retrieves the security group created automatically by EKS for the cluster. This resource is tagged with a label that identifies it as being owned by the EKS cluster.

## variables
This file defines the input variables used in the Terraform code. These variables can be assigned values when the code is executed, and they allow for more flexibility and reusability in the code.

The file begins by defining a tags variable, which is a map of key-value pairs used for tagging resources in the project. The region and project variables are also defined to specify the AWS region and project name, respectively.

The next section defines variables used specifically for setting up an EKS cluster. These include cluster_policy_arn and service_policy_arn, which are the Amazon Resource Names (ARNs) of the IAM policies attached to the EKS cluster and the AWS service-linked role, respectively. flux_kustomize_sops_kms_arn is the ARN of the AWS KMS key used to encrypt the SOPS secret data for the EKS cluster.

The remaining variables are used for defining the security group for the EKS cluster. vpc_id specifies the ID of the VPC where the EKS cluster is to be created. eks_version is the version of EKS to be used. endpoint_private_access and endpoint_public_access are boolean values that specify whether the EKS cluster API server endpoint is private or public, respectively. public_access_cidrs is a list of CIDR blocks that are allowed to access the EKS cluster API server when it is publicly accessible. private_subnet_ids is a list of IDs for the subnets where the EKS cluster instances will be launched. cloud9_sg_id is a list of security group IDs for the Cloud9 instances that are allowed to access the EKS cluster API server. Finally, addons is a list of objects that define Kubernetes add-ons to be deployed with the EKS cluster.

## outputs
The outputs.tf file contains output declarations that specify the values to be outputted after the resources are created.

eks_cluster_arn: The Amazon Resource Name (ARN) of the EKS cluster.
eks_cluster_id: The unique identifier of the EKS cluster.
eks_cluster_name: The name of the EKS cluster.
eks_cluster_sg_id: The ID of the security group that controls inbound and outbound traffic for the EKS cluster.
eks_cluster_created_sg_id: The ID of the security group that is automatically created by the EKS cluster.

These outputs can be used by other Terraform modules or by the user to access the created resources or to perform further operations.

### Maintainers:
[DevSecOps-Platforms](mailto:devsecopsplatforms@safaricom.co.ke).

