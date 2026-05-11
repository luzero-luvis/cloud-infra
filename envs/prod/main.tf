module "vpc" {
  source = "../../modules/vpc"

  env        = "prod"
  cidr_block = "10.1.0.0/16"

  tags = local.common_tags
}
