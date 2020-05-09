variable "aws_region" {
  default = "ap-southeast-1"
}
variable "aws_profile" {
  default = "default"
}
variable "ami_type" {
  # Ubuntu bionic 18.04 LTS ami
  default = "ami-0e763a959ec839f5e"
}
variable "instance_type" {
  default = "t3a.small"
}
variable "key_name" {
  default = "kubics-master"
}
variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}