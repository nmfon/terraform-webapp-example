resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "database" {
  engine                 = "mysql"
  engine_version         = "8.0"

  instance_class         = "db.t2.micro"
  allocated_storage      = 10

  identifier             = "${var.namespace}-db-instance"
  db_name                = "example"
  username               = "admin"
  password               = random_password.db_password.result

  db_subnet_group_name   = var.vpc.database_subnet_group
  vpc_security_group_ids = [var.sg.db]

  multi_az               = true
  skip_final_snapshot    = true

  tags = {
    Owner = var.owner
  }
}
