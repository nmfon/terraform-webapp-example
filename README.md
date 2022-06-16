# Terraform example - internal webapp in AWS

This repo contains a Terraform module to deploy an AWS environment to
host a production web application for *internal* teams, with a database
backend.

Assumptions:

- CI/CD for app is out of scope
- App will run on EC2 on port 443

## Architecture

VPC with the following subnets:

- database (accessible only from the webapp servers in the private subnets)
- private (for the webapp)
- public (not used, but would support a bastion host, for remote access to the webapp servers)

Load balancer:

- application load-balancer
- listen on port 443 (HTTPS)
- SSL/TLS termination at the load-balancer
- server certificate signed by private CA (using AWS ACM PCA)
- not public-facing

Webapp:

- hosted in tomcat (purely for the sake of this example)
- run on multiple EC2 instances that are part of an ASG

Database:

- use RDS MySQL (purely for the sake of this example)
- configured for Multi-AZ

## Configuration

Review (and update, if necessary) the values in:

- terraform.tfvars

## Deployment

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

## Tear down

```bash
terraform destroy
```

## Extensions (road map)

Beyond this very basic example, I would recommend the following:

- add support for per-environment config files
- add config for a pipeline (e.g. GitLab CI)
- store secrets in a secrets manager (e.g. AWS SSM Parameter Store, AWS Secrets Manager, etc.)
