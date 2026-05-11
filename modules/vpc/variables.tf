# ─────────────────────────────────────────────────────────────────────────────
# VPC MODULE VARIABLES — inputs the caller must (or can optionally) provide.
#
# A module is like a function in programming.
# Variables are the function's parameters — what the caller passes in.
# ─────────────────────────────────────────────────────────────────────────────

variable "env" {
  description = "Environment name — used to name all resources (e.g. dev-vpc, prod-vpc)"
  type        = string
  # No default — the caller MUST provide this. Terraform errors if missing.
}

variable "cidr_block" {
  description = "IP address range for the entire VPC (e.g. 10.0.0.0/16)"
  type        = string
  # /16 = 65,536 IP addresses available inside the VPC
  # dev uses 10.0.0.0/16, prod uses 10.1.0.0/16 — they do not overlap
}

variable "availability_zones" {
  description = "Which AWS data centers (AZs) to spread subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  # AWS has multiple data centers in each region.
  # Spreading across 2+ AZs means if one data center has a problem,
  # your app keeps running in the other one. This is called high availability.
}

variable "public_subnet_cidrs" {
  description = "IP ranges for public subnets (resources here can reach the internet)"
  type        = list(string)
  default     = []
  # Public subnet = has a route to the internet gateway
  # Used for: load balancers, NAT gateways, bastion hosts
  # Default empty — add subnet CIDRs when you need public resources
}

variable "private_subnet_cidrs" {
  description = "IP ranges for private subnets (no direct internet access)"
  type        = list(string)
  default     = []
  # Private subnet = no direct route to the internet
  # Used for: databases, application servers, anything that should not be public
  # Traffic can still reach the internet via a NAT gateway in the public subnet
}

variable "tags" {
  description = "Tags to apply to all resources in this module"
  type        = map(string) # a key-value map, e.g. { environment = "dev", owner = "team" }
  default     = {}          # empty by default — caller can pass common_tags from locals.tf
}
