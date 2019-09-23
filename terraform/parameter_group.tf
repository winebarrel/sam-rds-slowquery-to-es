resource "aws_rds_cluster_parameter_group" "slowquery_source_dbcluster_aurora56" {
  name        = "slowquery-source-dbcluster-aurora56"
  description = "slowquery-source-dbcluster-aurora56"
  family      = "aurora5.6"

  parameter {
    name         = "log_output"
    value        = "file"
    apply_method = "immediate"
  }

  parameter {
    name         = "long_query_time"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "slow_query_log"
    value        = "1"
    apply_method = "immediate"
  }
}

resource "aws_db_parameter_group" "slowquery_source_aurora56" {
  name        = "slowquery-source-aurora56"
  family      = "aurora5.6"
  description = "slowquery-source-aurora56"
}
