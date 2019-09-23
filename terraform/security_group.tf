data "aws_security_group" "default" {
  vpc_id = "${var.vpc_id}"
  name   = "${var.security_group_name}"
}
