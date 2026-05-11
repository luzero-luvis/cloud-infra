locals {
  common_tags = {
    environment  = "prod"
    project      = "cloud-infra"
    owner        = "platform-team"
    cost_center  = "engineering"
    managed_by   = "terraform"
  }
}
