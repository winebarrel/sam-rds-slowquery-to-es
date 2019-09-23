data "aws_iam_policy_document" "rds_slowquery_to_es_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_slowquery_to_es" {
  name               = "rds-slowquery-to-es"
  assume_role_policy = "${data.aws_iam_policy_document.rds_slowquery_to_es_assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "rds_slowquery_to_es_aws_lambda_basic_execution_role" {
  role       = "${aws_iam_role.rds_slowquery_to_es.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
