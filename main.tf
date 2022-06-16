module "networking" {
  source    = "./modules/networking"

  namespace = var.namespace
  owner     = var.owner
}

module "database" {
  source    = "./modules/database"

  namespace = var.namespace
  owner     = var.owner

  vpc = module.networking.vpc
  sg  = module.networking.sg
}

module "autoscaling" {
  source      = "./modules/autoscaling"

  namespace   = var.namespace
  owner       = var.owner
  ssh_keypair = var.ssh_keypair

  vpc       = module.networking.vpc
  sg        = module.networking.sg
  db_config = module.database.db_config
}
