variable "aws_region" {
  default = "ap-southeast-1"
}

variable "aws_profile" {
  default = "sysops"
}

variable "ami_type" {
  # Ubuntu bionic 18.04 LTS ami
  default = "ami-0e763a959ec839f5e"
}

variable "instance_type" {
  default = "m5a.large"
}

variable "instance_optimize_type" {
  default = "c5a.large"
}

variable "key_name" {
  default = "kube-master"
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}