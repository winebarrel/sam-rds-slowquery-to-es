#!/bin/bash
ELASTICSEARCH_URL=https://search-slowquery-xxx.ap-northeast-1.es.amazonaws.com

curl -XPUT -H 'Content-Type: application/json' $ELASTICSEARCH_URL/_template/slowquery_index_template -d '
{
  "index_patterns": ["aws_rds_*_slowquery-*"],
  "mappings": {
    "dynamic_templates": [
      {
        "rule1": {
          "mapping": {
            "type": "text",
            "fields": {
              "keyword": {
                "ignore_above": 2048,
                "type": "keyword"
              }
            }
          },
          "match_mapping_type": "string",
          "match": "sql_fingerprint"
        }
      }
    ]
  }
}
'
