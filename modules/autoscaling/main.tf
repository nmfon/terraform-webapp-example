resource "aws_iam_instance_profile" "websvr_profile" {
  name = "websvr_profile"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "websvr_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

data "cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/conf/cloud-config.yaml", var.db_config)
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20220420"]
  }

  owners = ["099720109477"]
}

resource "aws_launch_template" "webserver" {
  name_prefix   = var.namespace

  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  user_data     = data.cloudinit_config.config.rendered
  key_name      = var.ssh_keypair

  iam_instance_profile {
    name = aws_iam_instance_profile.websvr_profile.name
  }

  tags = {
    Owner = var.owner
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.namespace}-tomcat"
    }
  }

  vpc_security_group_ids = [var.sg.websvr]
}

resource "aws_autoscaling_group" "webserver" {
  name                = "${var.namespace}-asg"

  desired_capacity    = 3
  min_size            = 3
  max_size            = 6

  vpc_zone_identifier = var.vpc.private_subnets
  target_group_arns   = module.alb.target_group_arns

  launch_template {
    id      = aws_launch_template.webserver.id
    version = aws_launch_template.webserver.latest_version
  }

  tag {
    key                 = "Owner"
    value               = var.owner
    propagate_at_launch = true
  }
}


resource "aws_route53_zone" "example" {
  name = "${var.namespace}.local"

  vpc {
    vpc_id = var.vpc.vpc_id
  }

  tags = {
    Owner = var.owner
  }
}


# Private CA (its state will be PENDING until its root CA cert
# is imported, see below)

resource "aws_acmpca_certificate_authority" "example" {
  type = "ROOT"

  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name = "${var.namespace}.local"
    }
  }

  tags = {
    Owner = var.owner
  }
}

# Create root CA cert for private CA

resource "aws_acmpca_certificate" "root_ca" {
  certificate_authority_arn   = aws_acmpca_certificate_authority.example.arn
  certificate_signing_request = aws_acmpca_certificate_authority.example.certificate_signing_request
  signing_algorithm           = "SHA512WITHRSA"

  template_arn = "arn:aws:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 3
  }
}

# Import root CA cert to private CA

resource "aws_acmpca_certificate_authority_certificate" "example" {
  certificate_authority_arn = aws_acmpca_certificate_authority.example.arn

  certificate       = aws_acmpca_certificate.root_ca.certificate
  certificate_chain = aws_acmpca_certificate.root_ca.certificate_chain
}


# Server cert for ALB

resource "tls_private_key" "key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "csr" {
  private_key_pem = tls_private_key.key.private_key_pem

  subject {
    common_name = "webapp.${var.namespace}.local"
  }
}

resource "aws_acm_certificate" "example" {
  domain_name                 = "webapp.${var.namespace}.local"
  certificate_authority_arn   = aws_acmpca_certificate_authority.example.arn
}


# ALB for web servers

module "alb" {
  source             = "terraform-aws-modules/alb/aws"
  version            = "~> 5.0"
  name               = var.namespace

  load_balancer_type = "application"
  internal           = true

  vpc_id             = var.vpc.vpc_id
  subnets            = var.vpc.private_subnets
  security_groups    = [var.sg.lb]

  https_listeners = [
    {
      port               = 443,
      protocol           = "HTTPS"
      certificate_arn    = aws_acm_certificate.example.arn
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name_prefix      = "websvr",
      backend_protocol = "HTTP",
      backend_port     = 8080
      target_type      = "instance"
    }
  ]

  tags = {
    Owner = var.owner
  }
}

# DNS record for ALB

resource "aws_route53_record" "example" {
  zone_id         = aws_route53_zone.example.zone_id
  name            = "webapp.${var.namespace}.local"
  type            = "CNAME"
  ttl             = 60
  records         = [module.alb.this_lb_dns_name]

  allow_overwrite = true
}
