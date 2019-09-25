resource "aws_cloudwatch_log_group" "slowquery_source_slowquery" {
  name = "/aws/rds/cluster/${aws_rds_cluster.slowquery_source.id}/slowquery"
}

/* TODO:
data "aws_lambda_function" "sam_rds_slowquery_to_es" {
  function_name = "sam-rds-slowquery-to-es"
}

resource "aws_cloudwatch_log_subscription_filter" "rds_slowquery_to_es" {
  name            = "LambdaStream_${data.aws_lambda_function.sam_rds_slowquery_to_es.function_name}"
  distribution    = "ByLogStream"
  log_group_name  = "${aws_cloudwatch_log_group.slowquery_source_slowquery.name}"
  filter_pattern  = ""
  destination_arn = "${data.aws_lambda_function.sam_rds_slowquery_to_es.arn}"
}
*/
