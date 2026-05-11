# ─────────────────────────────────────────────────────────────────────────────
# VPC MODULE — creates a complete AWS network for one environment.
#
# What is a VPC?
#   VPC = Virtual Private Cloud.
#   Think of it as your own private section of the AWS data center.
#   Like renting a floor in an office building — your own space,
#   your own network, isolated from other tenants.
#
# What this module creates:
#   1. VPC                  — the private network container
#   2. Internet Gateway     — the door to the internet
#   3. Public subnets       — rooms with internet access
#   4. Private subnets      — rooms with no internet access (safer)
#   5. VPC Flow Logs        — records all network traffic (like a CCTV log)
#   6. CloudWatch Log Group — where the flow logs are stored
#   7. IAM Role + Policy    — permission for VPC to write logs
# ─────────────────────────────────────────────────────────────────────────────

# ── VPC ───────────────────────────────────────────────────────────────────────
# The VPC is the container that holds everything else.
# All subnets, instances, and databases live inside this VPC.

resource "aws_vpc" "this" {
  cidr_block = var.cidr_block # IP range for the whole VPC (e.g. 10.0.0.0/16)

  # enable_dns_support = true means AWS provides a DNS server inside the VPC.
  # Resources can resolve domain names (e.g. google.com → IP address).
  enable_dns_support = true

  # enable_dns_hostnames = true means AWS gives each resource a hostname.
  # E.g. ip-10-0-1-5.us-east-1.compute.internal
  # Required if you want to use private DNS or connect to RDS by hostname.
  enable_dns_hostnames = true

  # merge() combines two tag maps into one.
  # var.tags = { environment = "dev", owner = "team" }
  # { Name = "dev-vpc" } = the name tag we add here
  # Result: { environment = "dev", owner = "team", Name = "dev-vpc" }
  tags = merge(var.tags, { Name = "${var.env}-vpc" })
}

# ── INTERNET GATEWAY ──────────────────────────────────────────────────────────
# The Internet Gateway (IGW) is the door between your VPC and the public internet.
# Without an IGW, nothing inside the VPC can reach the internet and vice versa.
# One IGW per VPC is all you need — it handles all traffic.

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id # attach the IGW to our VPC

  tags = merge(var.tags, { Name = "${var.env}-igw" })
}

# ── PUBLIC SUBNETS ────────────────────────────────────────────────────────────
# A subnet is a smaller network inside the VPC.
# Public subnet = resources here CAN talk to the internet (via the IGW).
# Examples of what goes in public subnets: load balancers, NAT gateways.
#
# count = how many subnets to create (based on how many CIDRs you pass in)

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs) # create one subnet per CIDR in the list

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidrs[count.index] # grab the Nth CIDR from the list
  availability_zone = var.availability_zones[count.index]  # spread across AZs for resilience

  # map_public_ip_on_launch = false means:
  # Resources launched in this subnet do NOT automatically get a public IP.
  # Why false? It is safer. If you need a public IP, assign it explicitly.
  # This also passes Checkov check CKV_AWS_130.
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.env}-public-${count.index + 1}" })
  # count.index starts at 0, so we add 1 to get: public-1, public-2, etc.
}

# ── PRIVATE SUBNETS ───────────────────────────────────────────────────────────
# Private subnet = resources here CANNOT directly reach the internet.
# Examples: databases (RDS), application servers, Lambda functions.
# They are safer because attackers on the internet cannot reach them directly.
# If they need internet access (e.g. to download updates), they go via a NAT gateway
# in the public subnet — the NAT gateway acts as a middleman.

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  # No map_public_ip_on_launch here — private subnets never get public IPs

  tags = merge(var.tags, { Name = "${var.env}-private-${count.index + 1}" })
}

# ── VPC FLOW LOGS ─────────────────────────────────────────────────────────────
# Flow logs record every network connection going in and out of your VPC.
# Like a security camera log: "at 14:32, IP 10.0.1.5 connected to 8.8.8.8 on port 443"
#
# Why important?
#   - Security investigation: "who connected to that server yesterday?"
#   - Compliance: many standards (SOC2, HIPAA) require network audit logs
#   - Checkov CKV2_AWS_11 requires this — without it, Checkov fails the scan
#
# Flow logs → CloudWatch Log Group → you can search/query them

resource "aws_flow_log" "this" {
  vpc_id       = aws_vpc.this.id
  traffic_type = "ALL" # log ALL traffic: accepted and rejected connections
  # "ACCEPT" would only log successful connections
  # "REJECT" would only log blocked connections
  # "ALL" is best for security — you want to see everything

  iam_role_arn    = aws_iam_role.flow_log.arn             # role that allows writing logs
  log_destination = aws_cloudwatch_log_group.flow_log.arn # where to write the logs
}

# ── CLOUDWATCH LOG GROUP ──────────────────────────────────────────────────────
# This is the storage location for flow logs in AWS CloudWatch (AWS's log service).
# Think of it as a folder where all the network logs are saved.

resource "aws_cloudwatch_log_group" "flow_log" {
  name = "/vpc/${var.env}/flow-logs" # log group name in CloudWatch
  # forward slashes create a folder structure

  # retention_in_days = how long to keep logs before auto-deleting them.
  # 90 days = 3 months of network history available for investigation.
  # Shorter = cheaper but less history. Longer = more history but higher cost.
  retention_in_days = 90
}

# ── IAM ROLE FOR FLOW LOGS ────────────────────────────────────────────────────
# The VPC flow log service needs permission to write logs to CloudWatch.
# This IAM role grants that permission.
#
# Think of it like this:
#   The flow log service says: "I need to write to CloudWatch"
#   AWS says: "Show me your badge (role)"
#   This role IS the badge — it says "allowed to write logs"

resource "aws_iam_role" "flow_log" {
  name = "${var.env}-vpc-flow-log-role"

  # Trust policy: who is allowed to USE this role?
  # "vpc-flow-logs.amazonaws.com" = only the VPC flow logs service can use this role.
  # Not a human, not GitHub Actions — only the flow logs service itself.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ── IAM POLICY FOR FLOW LOGS ──────────────────────────────────────────────────
# This policy defines WHAT the flow log role is allowed to do.
# It only grants the minimum permissions needed to write logs — nothing more.
# This is the principle of least privilege: only give what is actually needed.

resource "aws_iam_role_policy" "flow_log" {
  name = "${var.env}-vpc-flow-log-policy"
  role = aws_iam_role.flow_log.id # attach this policy to the flow log role

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",    # create a log group if it does not exist
        "logs:CreateLogStream",   # create a log stream (like a file) inside the group
        "logs:PutLogEvents",      # write log entries into the stream
        "logs:DescribeLogGroups", # list log groups (needed to find the right one)
        "logs:DescribeLogStreams" # list log streams
      ]
      Resource = "*" # applies to all CloudWatch log resources
      # In production, you would restrict this to just the specific log group ARN
    }]
  })
}
