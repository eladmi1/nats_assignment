variable "http_monitoring_port" {
  type    = number
  default = 8222
  description = "The HTTP monitoring port"
}
variable "client_port" {
  type    = number
  default = 4222
  description = "The client port"
}
variable "route_port" {
  type    = number
  default = 6222
  description = "The route port"
}
variable "aws_region" {
  type    = string
  default = "eu-west-1"
  description = "The AWS Region to use"
}