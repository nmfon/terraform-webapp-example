output "vpc" {
  value = module.vpc
}

output "sg" {
  value = {
    lb     = module.lb_sg.security_group_id
    db     = module.db_sg.security_group_id
    websvr = module.websvr_sg.security_group_id
  }
}
