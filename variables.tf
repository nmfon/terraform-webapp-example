variable "namespace" {
  description = "The project namespace to use for unique resource naming"
  type        = string
}

variable "owner" {
  description = "The owner to use for tagging each resource"
  type        = string
}

variable "region" {
  description = "AWS region"
  default     = "ap-southeast-2"
  type        = string
}

variable "ssh_keypair" {
  description = "SSH keypair to use for EC2 instance"
  default     = null
  type        = string
}
