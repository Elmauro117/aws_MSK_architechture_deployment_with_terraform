// Desplieuge de APIGW y SQS


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

variable "region" {
  default = "us-east-1"
  type    = string
}

provider "aws" {
  region     = "${var.region}"
  access_key = "XXXXXXXXXXXXXXX"
  secret_key = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}


output "test_cURL" {
  value = "curl -X POST -H 'Content-Type: application/json' -d '{\"id\":\"test\", \"docs\":[{\"key\":\"value\"}]}' ${aws_api_gateway_deployment.api.invoke_url}/"
}

resource "aws_sqs_queue" "queue" {
  name                      = "my-sqs-queue"
  delay_seconds             = 0              // how long to delay delivery of records
  max_message_size          = 262144         // = 256KiB, which is the limit set by AWS
  message_retention_seconds = 86400          // = 1 day in seconds
  receive_wait_time_seconds = 10             // how long to wait for a record to stream in when ReceiveMessage is called
  visibility_timeout_seconds = 370           // 
}

resource "aws_iam_role" "api" {
  name = "my-api-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "api" {
  name = "my-api-perms"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility",
          "sqs:ListDeadLetterSourceQueues",
          "sqs:SendMessageBatch",
          "sqs:PurgeQueue",
          "sqs:ReceiveMessage",
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:CreateQueue",
          "sqs:ListQueueTags",
          "sqs:ChangeMessageVisibilityBatch",
          "sqs:SetQueueAttributes"
        ],
        "Resource": "${aws_sqs_queue.queue.arn}"
      },
      {
        "Effect": "Allow",
        "Action": "sqs:ListQueues",
        "Resource": "*"
      }      
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "api" {
  role       = "${aws_iam_role.api.name}"
  policy_arn = "${aws_iam_policy.api.arn}"
}














resource "aws_api_gateway_rest_api" "api" {
  name        = "my-sqs-api"
  description = "POST records to SQS queue"
}








resource "aws_api_gateway_request_validator" "api" {
  rest_api_id           = "${aws_api_gateway_rest_api.api.id}"
  name                  = "payload-validator"
  validate_request_body = false ## Creo q esta era la vaina, antes era "true"
}

resource "aws_api_gateway_model" "api" {
  rest_api_id  = "${aws_api_gateway_rest_api.api.id}"
  name         = "PayloadValidator"
  description  = "validate the json body content conforms to the below spec"
  content_type = "application/json"  ## Esto valida que lo que se mande al APIGW sea un JSON

  schema = jsonencode({})
}

resource "aws_api_gateway_method" "api" {
  rest_api_id          = "${aws_api_gateway_rest_api.api.id}"
  resource_id          = "${aws_api_gateway_rest_api.api.root_resource_id}"
  api_key_required     = false
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = "${aws_api_gateway_request_validator.api.id}"

  request_models = {
    "application/json" = "${aws_api_gateway_model.api.name}"
  }
  
}

//INTEGRACION CON SQS
resource "aws_api_gateway_integration" "api" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method             = "POST"
  type                    = "AWS"
  integration_http_method = "POST"
  passthrough_behavior    = "WHEN_NO_MATCH"
  credentials             = "${aws_iam_role.api.arn}"
  uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${aws_sqs_queue.queue.name}"
  
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
    #"application/json" = "{\"MessageBody\": $input.json('$')}" ## Esta viana no sirve
  }
}






resource "aws_api_gateway_integration_response" "_200" {
  rest_api_id       = "${aws_api_gateway_rest_api.api.id}"
  resource_id       = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method       = "${aws_api_gateway_method.api.http_method}"
  status_code       = "${aws_api_gateway_method_response._200.status_code}"
  selection_pattern = "^2[0-9][0-9]"                                       // regex pattern for any 200 message that comes back from SQS

  response_templates = {
    "application/json" = "{\"message\": \"great success!\"}"
  }

  depends_on = ["aws_api_gateway_integration.api"]
}




resource "aws_api_gateway_method_response" "_200" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_rest_api.api.root_resource_id}"
  http_method = "${aws_api_gateway_method.api.http_method}"
  status_code = 200

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "publish"

  depends_on = ["aws_api_gateway_integration.api",]
}