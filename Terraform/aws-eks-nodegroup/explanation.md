### AWS EKS Nodes Module
The code in this repository creates a single EKS Node Group and its resources in AWS. The module is hosted in a private Terraform Enterprise registry. 

The most current and stable version is __0.0.__

The given code snippets are part of a Terraform configuration that creates a single EKS Node group and its resources in AWS. The configuration is split across  files: **[versions.tf](#versions)**,**[nodes_iamrole.tf](#nodes_iamrole)**,**[main.tf](#main)**, and **[variables.tf](#variables)**.

Below is a brief of what each file contains:

## versions
This is the versions.tf file in Terraform, which is used to specify the version requirements for Terraform and its providers. In this example, it is requiring Terraform version 1.2.7 or higher, and the AWS provider version 2.49 or higher.

The terraform block is used to specify the version requirements for Terraform itself, while the required_providers block is used to specify the version requirements for each provider that will be used in the configuration. In this case, it is specifying the aws provider and requiring version 2.49 or higher.

These version requirements ensure that the configuration will only work with the specified versions of Terraform and the AWS provider, which can help to avoid unexpected errors or compatibility issues.

## nodes_iamrole
This file defines and configures an AWS Identity and Access Management (IAM) role for Elastic Kubernetes Service (EKS) nodes, along with attaching different policies to the role.

The script first defines an AWS IAM role named "eks_nodes_role" with an assume role policy that allows EC2 instances to assume the role. The role is also tagged with a name that includes the region and project variables.

Then, the script defines five IAM role policy attachments that attach different AWS managed policies to the "eks_nodes_role" IAM role. These policies are:

AmazonEKSWorkerNodePolicy: provides permissions for the EKS worker nodes to join the cluster and communicate with the control plane.
AmazonEKS_CNI_Policy: provides permissions for the Amazon EKS CNI plugin to create and manage the necessary network interfaces on the worker nodes.
AmazonEC2ContainerRegistryReadOnly: provides read-only access to the Amazon Elastic Container Registry (ECR).
CloudWatchAgentServerPolicy: provides permissions for the CloudWatch agent to collect metrics and logs from the worker nodes.
AmazonElasticFileSystemFullAccess: provides full access to Amazon Elastic File System (EFS).
Overall, this script sets up an IAM role and the required permissions for EKS nodes to function correctly in an AWS environment.

## main
This Terraform code is used to provision an EKS (Elastic Kubernetes Service) nodes on AWS with a launch template and a node group.

The aws_iam_role resource creates an IAM role for the EKS worker nodes. The aws_iam_role_policy_attachment resources attach different policies to the role. These policies grant permissions to the worker nodes to perform actions on different AWS services, such as EC2 Container Registry, CloudWatch, and Elastic File System.

The aws_launch_template resource creates an EC2 launch template. This template is used to launch EC2 instances for the EKS worker nodes.

The aws_eks_node_group resource creates an EKS node group. This node group launches EC2 instances based on the launch template created earlier. It attaches the IAM role created earlier to the instances to grant them the necessary permissions to interact with AWS services.

The aws_eks_addon resource provisions an EKS addon. It depends on the aws_eks_node_group resource to ensure that the worker nodes are available before provisioning the addon.

The code uses variables to define the cluster's region, project name, node group name, and other configurations. It also uses locals to define whether to use a custom launch template or not.

The depends_on parameter is used to specify the dependencies between resources. This ensures that the resources are created in the correct order.

## variables
The variables.tf file contains the declaration of variables used in the main.tf file. Variables are a way to parameterize the Terraform code, allowing us to pass in values when we run terraform apply. Here's a brief explanation of the variables declared in this file:

1. tags: a map containing tags to be used on the project.
2. region: the AWS region used for the project.
3. project: the name of the project.
4. eks_cluster_id: the ID of the EKS cluster.
5. instance_type_lt: the instance type to use with EKS launch template.
6. volume_size: the size of the disk to be used.
7. volume_type: the type of volume to use.
8. eks_cluster_name: the name of the EKS cluster.
9. node_group_name: the prefix for the node group.
10. eks_worker_subnet_id: the subnet IDs of the EKS workers.
11. ami_type: the type of AMI to use.
12. lt_version: the version of the launch template.
13. desired_size: the desired size of EKS scaling.
14. max_size: the maximum size for EKS scaling.
15. min_size: the minimum size for EKS scaling.
16. create_launch_template: determines whether to create a launch template or not. If set to false, EKS will use its own default launch template.
17. capacity_type: the capacity type to use.
18. addons: a list of addons to install on the EKS cluster, with each addon having a name and version property. The default value is a list containing the coredns addon with a specific version.

### Maintainers:
[DevSecOps-Platforms](mailto:devsecopsplatforms@safaricom.co.ke).

