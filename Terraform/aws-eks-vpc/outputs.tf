output "vpc_id" {
  description = "The ID to the VPC Created"
  value = aws_vpc.vpc.id
}

output "igw_id" {
  description = "The ID to Internet Gateway"
  value = aws_internet_gateway.igw.id
}
output "public_subnets_id" {
  description = "The IDs to the public subnets created"
  value = ["${aws_subnet.public.*.id}"]
}

output "private_subnets_id" {
  description = "The IDs to the private eks/application subnets created"
  value = ["${aws_subnet.private_eks.*.id}"]
}
output "data_subnets_id" {
  description = "The IDs to the data subnets created"
  value = ["${aws_subnet.private_data.*.id}"]
}

output "eks_nodes_subnets_id" {
  description = "The IDs to the eks nodes subnets created"
  value = ["${aws_subnet.eks_nodes.*.id}"]
}

output "private_ngw_id" {
  description = "The ID to the private nat gateway created"
  value = ["${aws_nat_gateway.private_ngw.id}"]
}

