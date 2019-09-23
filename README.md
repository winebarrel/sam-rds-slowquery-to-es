# rds-slowquery-to-es

[AWS SAM](https://aws.amazon.com/serverless/sam/) app that sends slowqueries from CloudWatch Logs to Elasticsearch.

![](https://user-images.githubusercontent.com/117768/65479870-2d859500-deca-11e9-876e-4df6ee55b13e.png)

![](https://user-images.githubusercontent.com/117768/65502267-6ee36800-defd-11e9-9a7c-17ef2c546568.png)
![](https://user-images.githubusercontent.com/117768/65502270-70ad2b80-defd-11e9-8ba4-f1b561996878.png)
![](https://user-images.githubusercontent.com/117768/65502272-71de5880-defd-11e9-8acd-80ad1d253003.png)

## Setup

```sh
#pip install aws-sam-cli
bundle install
bundle exec rake docker:lambda-ruby-bundle:build
bundle exec rake sam:bundle
bundle exec rake pt-fingerprint:download

cp template.yaml.sample template.yaml
vi template.yaml # Fix Role/ELASTICSEARCH_URL
```

### Environment variables

```sh
export AWS_DEFAULT_REGION=ap-northeast-1
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export S3_BUCKET=...
```

### Setup AWS resources using Terraform

```sh
cd terraform
cp variables.tfvars.sample variables.tfvars
vi variables.tfvars
terraform init
terraform plan -var-file=variables.tfvars
terraform apply -var-file=variables.tfvars

# After deploying SAM app
vi cloudwatch_logs.tf
# Uncomment aws_cloudwatch_log_subscription_filter.rds_slowquery_to_es
terraform plan -var-file=variables.tfvars
terraform apply -var-file=variables.tfvars
```

## Invoke Lambda locally

```sh
docker-compose up -d
bundle exec rake sam:local:invoke
open http://localhost:5601
```

### Create Kibana index pattern

1. `Management` -> `Create index pattern`
1. Create index pattern:
    * Index pattern: `aws_rds_*_slowquery-*`
    * Time Filter field name: `timestamp`

## Run tests

```sh
bundle exec rake
```

## Deploy

```sh
bundle exec rake sam:deploy-noop
bundle exec rake sam:deploy
```

## Invoke Lambda remotely

```sh
# tail -f function log
sam logs -n sam-rds-slowquery-to-es -t
```

```sh
bundle exec rake sam:invoke
```
