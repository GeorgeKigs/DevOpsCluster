## EKS Launch Template
locals {
  use_custom_launch_template = var.create_launch_template
}
resource "aws_launch_template" "eks-launch-template" {
  depends_on              = []
  description             = "to use with ${var.project} EKS cluster"
  disable_api_termination = false
  name                    = "${var.region}-${var.project}-EKS-launch-template"
  instance_type           = var.instance_type_lt
  vpc_security_group_ids  = []



  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.volume_size
      volume_type = var.volume_type
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      {
        Name = "${var.region}-${var.project}-eks-node"
      },
    )

  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.tags,
      {
        Name = "${var.region}-${var.project}-eks-node-volume"
      },
    )
  }
}

## Create the EKS cluster node group
resource "aws_eks_node_group" "node_group" {

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.AmazonSSMManagedInstanceCore,
    aws_iam_role_policy_attachment.AmazonElasticFileSystemFullAccess,
  ]

  cluster_name    = var.eks_cluster_name
  node_group_name = "${var.region}-${var.project}-${var.node_group_name}"
  node_role_arn   = aws_iam_role.eks_nodes_role.arn
  subnet_ids      = var.eks_worker_subnet_id
  ami_type        = var.ami_type

  launch_template {
    id      = aws_launch_template.eks-launch-template.id
    version = var.lt_version
  }
  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  timeouts {}

  update_config {
    max_unavailable = 1
  }

  tags = merge(
    var.tags,
    {
      Name                                                                 = "${var.region}-${var.project}-${var.node_group_name}"
      "k8s.io/cluster-autoscaler/${var.region}-${var.project}-EKS-Cluster" = "owned",
      "k8s.io/cluster-autoscaler/enabled"                                  = true
    },
  )
}

resource "aws_eks_addon" "addons" {
  depends_on        = [aws_eks_node_group.node_group]
  for_each          = { for addon in var.addons : addon.name => addon }
  cluster_name      = var.eks_cluster_name
  addon_name        = each.value.name
  addon_version     = each.value.version
  resolve_conflicts = "OVERWRITE"
}