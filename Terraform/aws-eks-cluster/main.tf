
## Create OIDC
data "tls_certificate" "eks_cluster_oidc_cert" {
  url = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
}

resource "aws_iam_openid_connect_provider" "eks_cluster_oidc" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_cluster_oidc_cert.certificates.0.sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
}

## Creating the EKS cluster
resource "aws_eks_cluster" "eks_cluster" {
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]
  name     = "${var.region}-${var.project}-EKS-Cluster"
  role_arn = aws_iam_role.iam_role_eks_cluster.arn
  version  = var.eks_version


  # Adding VPC Configuration

  vpc_config { # Configure EKS with vpc and network settings 
    security_group_ids      = ["${aws_security_group.eks_cluster.id}"]
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.encyption_key.arn
    }
    resources = ["secrets"]
  }

  depends_on = [
    /* aws_iam_openid_connect_provider.eks_cluster_oidc, */
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSServicePolicy,
  ]
  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-EKS-Cluster"
    },
  )
}

## Encryption

resource "aws_kms_key" "encyption_key" {
  description         = "${var.project} EKS Key UAT"
  enable_key_rotation = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project}-eks-key2"
    },
  )
}

resource "aws_kms_alias" "key_alias" {
  name          = "alias/${var.project}-eks-key2"
  target_key_id = aws_kms_key.encyption_key.key_id
}

resource "aws_eks_addon" "addons" {
  for_each          = { for addon in var.addons : addon.name => addon }
  cluster_name      = aws_eks_cluster.eks_cluster.id
  addon_name        = each.value.name
  addon_version     = each.value.version
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "cni_addons" {
  cluster_name             = aws_eks_cluster.eks_cluster.id
  addon_name               = "vpc-cni"
  addon_version            = "v1.12.6-eksbuild.2"
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = aws_iam_role.cni_role.arn
}