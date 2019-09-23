data "aws_iam_policy_document" "slowquery_es_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "es:*",
    ]

    resources = [
      "arn:aws:es:ap-northeast-1:${data.aws_caller_identity.current.account_id}:domain/slowquery/*", # FIXME:
    ]
  }
}

resource "aws_elasticsearch_domain" "slowquery" {
  domain_name           = "slowquery"
  elasticsearch_version = "7.1"

  cluster_config {
    instance_type = "t2.small.elasticsearch"
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp2"
    volume_size = 35
  }

  access_policies = "${data.aws_iam_policy_document.slowquery_es_policy.json}"
}
