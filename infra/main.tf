terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.15"
    }
  }
  backend "s3" {
    bucket = "tfstate-grupo12-fiap-2025"
    key    = "notificacao.tfstate"
    region = "sa-east-1"
  }
}

provider "aws" {
  region = "sa-east-1"
}

resource "aws_sqs_queue" "email_queue" {
  name = "email-sqs-queue"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda-sqs-policy"
  description = "Policy for Lambda to access SQS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement : [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Effect   = "Allow",
        Resource = aws_sqs_queue.email_queue.arn
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "send_email_function" {
  function_name = "lambda_enviar_email_function"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "fiap.hackathon.enviar_email::fiap.hackathon.enviar_email.Function::FunctionHandler"
  runtime       = "dotnet8"
  memory_size   = 512
  timeout       = 30
  s3_bucket     = "hackathon-grupo12-fiap-code-bucket"
  s3_key        = "lambda_enviar_email_function.zip"

  environment {
    variables = {
      SENDGRID_API_KEY = var.sendgrid_api_key
      EMAIL_FROM       = var.email_from
      NAME_FROM        = var.name_from
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_policy_attachment]
}

resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  event_source_arn = aws_sqs_queue.email_queue.arn
  function_name    = aws_lambda_function.send_email_function.arn
  batch_size       = 10
  enabled          = true
}
