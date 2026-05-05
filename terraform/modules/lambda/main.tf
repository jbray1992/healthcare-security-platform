# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project}-lambda-role"
    Purpose = "IAM role for patient records Lambda function"
  }
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query"
        ]
        Resource = var.dynamodb_table_arn
      },
      {
        Sid    = "KMSEncryptDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Sid    = "ParameterStoreAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = var.kms_key_parameter_arn
      },
      {
        Sid    = "ParameterStoreDecrypt"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.parameter_store_key_arn
      },
      {
        Sid    = "BedrockAccess"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:ApplyGuardrail"
        ]
        Resource = "*"
      }
    ]
  })
}

# Build directory: copy source + install deps into a clean staging dir
resource "null_resource" "lambda_build" {
  triggers = {
    source_hash       = filemd5("${path.module}/../../../lambda-functions/patient-records/index.py")
    requirements_hash = filemd5("${path.module}/../../../lambda-functions/patient-records/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e
      BUILD_DIR="${path.module}/build"
      SRC_DIR="${path.module}/../../../lambda-functions/patient-records"
      rm -rf "$BUILD_DIR"
      mkdir -p "$BUILD_DIR"
      cp "$SRC_DIR/index.py" "$BUILD_DIR/"
      pip install \
        --platform manylinux2014_x86_64 \
        --target "$BUILD_DIR" \
        --implementation cp \
        --python-version 3.12 \
        --only-binary=:all: \
        --upgrade \
        -r "$SRC_DIR/requirements.txt"
    EOT
  }
}

# Zip the built Lambda directory
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/build"
  output_path = "${path.module}/lambda-function.zip"

  depends_on = [null_resource.lambda_build]
}

# Lambda Function
resource "aws_lambda_function" "patient_records" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project}-patient-records"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      TABLE_NAME        = var.dynamodb_table_name
      KMS_KEY_PARAMETER = var.kms_key_parameter_name
      GUARDRAIL_ID      = var.guardrail_id
      GUARDRAIL_VERSION = var.guardrail_version
    }
  }

  tags = {
    Name    = "${var.project}-patient-records"
    Purpose = "CRUD operations for patient records with envelope encryption"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.patient_records.function_name}"
  retention_in_days = 14

  tags = {
    Name    = "${var.project}-lambda-logs"
    Purpose = "Lambda function logs"
  }
}
