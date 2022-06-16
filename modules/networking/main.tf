data "aws_availability_zones" "available" {}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"

  name               = "${var.namespace}-vpc"
  cidr               = "10.0.0.0/16"

  azs                = data.aws_availability_zones.available.names
  database_subnets   = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.51.0/24", "10.0.52.0/24", "10.0.53.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false

  tags = {
    Owner = var.owner
  }
}

module "lb_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/https-443"

  name        = "lb-sg"
  description = "Security group for load balancer (listening port 443) from within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [ module.vpc.vpc_cidr_block ]
}

module "websvr_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "websvr-sg"
  description = "Security group for web server (listening on port 8443) from load balancer SG"
  vpc_id      = module.vpc.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "https-8443-tcp"
      source_security_group_id = module.lb_sg.security_group_id
    }
  ]

  number_of_computed_ingress_with_source_security_group_id = 1
}

module "db_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "db-sg"
  description = "Security group for MySQL database (listening on port 3306) from web server SG"
  vpc_id      = module.vpc.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.websvr_sg.security_group_id
    }
  ]

  number_of_computed_ingress_with_source_security_group_id = 1
}
