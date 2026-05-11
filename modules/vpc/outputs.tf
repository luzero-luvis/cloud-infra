# ─────────────────────────────────────────────────────────────────────────────
# VPC MODULE OUTPUTS — values the module sends back to the caller.
#
# When envs/dev/main.tf calls this module, it can access these outputs like:
#   module.vpc.vpc_id
#   module.vpc.public_subnet_ids
#
# This is how modules share information with each other.
# Example: another module creating EC2 instances needs to know the subnet IDs
# to put the instances in. It reads module.vpc.private_subnet_ids.
# ─────────────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "The ID of the VPC — used by other modules to attach resources to this VPC"
  value       = aws_vpc.this.id
  # Example value: vpc-0abc1234def56789
}

output "public_subnet_ids" {
  description = "List of public subnet IDs — pass these to load balancers or NAT gateways"
  value       = aws_subnet.public[*].id
  # [*] = collect the id from ALL public subnets into a list
  # Example value: ["subnet-0abc123", "subnet-0def456"]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs — pass these to databases, app servers"
  value       = aws_subnet.private[*].id
  # Example value: ["subnet-0ghi789", "subnet-0jkl012"]
}
