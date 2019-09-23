resource "aws_rds_cluster" "slowquery_source" {
  cluster_identifier              = "slowquery-source"
  master_username                 = "root"
  master_password                 = "password"
  db_subnet_group_name            = "${var.db_subnet_group_name}"
  db_cluster_parameter_group_name = "${aws_rds_cluster_parameter_group.slowquery_source_dbcluster_aurora56.name}"
  skip_final_snapshot             = true
  apply_immediately               = true

  vpc_security_group_ids = [
    "${data.aws_security_group.default.id}",
  ]

  enabled_cloudwatch_logs_exports = [
    "slowquery",
  ]
}

resource "aws_rds_cluster_instance" "slowquery_source" {
  identifier              = "slowquery-source"
  cluster_identifier      = "${aws_rds_cluster.slowquery_source.id}"
  instance_class          = "db.t2.small"
  db_parameter_group_name = "${aws_db_parameter_group.slowquery_source_aurora56.name}"
  publicly_accessible     = true
  apply_immediately       = true
}
