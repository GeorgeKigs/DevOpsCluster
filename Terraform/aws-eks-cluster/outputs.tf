output "eks_cluster_arn" {
  description = "ARN of the eks cluster"
  value       = aws_eks_cluster.eks_cluster.arn
}

output "eks_cluster_id" {
  description = "ARN of the eks cluster"
  value       = aws_eks_cluster.eks_cluster.id
}

output "eks_cluster_name" {
  description = "ARN of the eks cluster"
  value       = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_sg_id" {
  description = "The id of the created security group"
  value       = aws_security_group.eks_cluster.id
}

data "aws_eks_cluster" "eks_cluster_name" {
  name = aws_eks_cluster.eks_cluster.name

}

output "eks_cluster_created_sg_id" {
  value = data.aws_security_group.eks_created_sg.id
}