# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster" {
  name        = "${var.region}-${var.project}-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow outbound Communication from Cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    var.tags,
    {
      Name = "${var.region}-${var.project}-cluster-sg"
    },
  )
}

resource "aws_security_group_rule" "cluster_inbound" {
  count                    = length(var.cloud9_sg_id)
  description              = "Allow Cloud9 to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = element(var.cloud9_sg_id, count.index)
  to_port                  = 443
  type                     = "ingress"
}

##EKS Autocreated Security group
data "aws_security_group" "eks_created_sg" {
  vpc_id = aws_eks_cluster.eks_cluster.vpc_config[0].vpc_id
  tags = {
    "kubernetes.io/cluster/${aws_eks_cluster.eks_cluster.name}" = "owned",
    "aws:eks:cluster-name" = "${aws_eks_cluster.eks_cluster.name}"
  }
  depends_on = [aws_eks_cluster.eks_cluster]
}