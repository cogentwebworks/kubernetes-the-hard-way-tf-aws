variable "aws_region" {
  default = "ap-southeast-1"
}
variable "aws_profile" {
  default = "default"
}
variable "ami_type" {
  # Ubuntu 2020.04 ami
  default = "ami-0b8cf0f359b1335e1"
}
variable "instance_type" {
  default = "t3a.medium	"
}
variable "key_name" {
  default = "kubics-master"
}
variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}