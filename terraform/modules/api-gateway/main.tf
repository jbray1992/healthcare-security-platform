# REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project}-api"
  description = "Healthcare Security Platform API"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
  tags = {
    Name    = "${var.project}-api"
    Purpose = "REST API for patient records"
  }
}

# /patients resource
resource "aws_api_gateway_resource" "patients" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "patients"
}

# /patients/{patient_id} resource
resource "aws_api_gateway_resource" "patient" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.patients.id
  path_part   = "{patient_id}"
}

# Request validator: validates body and parameters
resource "aws_api_gateway_request_validator" "main" {
  name                        = "${var.project}-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = true
}

# JSON schema for POST /patients body
resource "aws_api_gateway_model" "patient_create" {
  rest_api_id  = aws_api_gateway_rest_api.main.id
  name         = "PatientCreate"
  description  = "Schema for creating a patient record"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "PatientCreate"
    type      = "object"
    required  = ["patient_id"]
    properties = {
      patient_id = {
        type      = "string"
        minLength = 1
        maxLength = 64
        pattern   = "^[A-Za-z0-9_-]+$"
      }
      record_type = {
        type = "string"
        enum = ["DEMOGRAPHICS", "MEDICAL", "BILLING"]
      }
      sensitive_data = {
        type = "object"
      }
      non_sensitive_data = {
        type = "object"
      }
    }
  })
}

# POST /patients - Create patient (validated, API key required)
resource "aws_api_gateway_method" "create_patient" {
  rest_api_id          = aws_api_gateway_rest_api.main.id
  resource_id          = aws_api_gateway_resource.patients.id
  http_method          = "POST"
  authorization        = "NONE"
  api_key_required     = true
  request_validator_id = aws_api_gateway_request_validator.main.id

  request_models = {
    "application/json" = aws_api_gateway_model.patient_create.name
  }
}

resource "aws_api_gateway_integration" "create_patient" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.patients.id
  http_method             = aws_api_gateway_method.create_patient.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# GET /patients/{patient_id} - Get patient (validated, API key required)
resource "aws_api_gateway_method" "get_patient" {
  rest_api_id          = aws_api_gateway_rest_api.main.id
  resource_id          = aws_api_gateway_resource.patient.id
  http_method          = "GET"
  authorization        = "NONE"
  api_key_required     = true
  request_validator_id = aws_api_gateway_request_validator.main.id

  request_parameters = {
    "method.request.path.patient_id" = true
  }
}

resource "aws_api_gateway_integration" "get_patient" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.patient.id
  http_method             = aws_api_gateway_method.get_patient.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# DELETE /patients/{patient_id} - Delete patient (validated, API key required)
resource "aws_api_gateway_method" "delete_patient" {
  rest_api_id          = aws_api_gateway_rest_api.main.id
  resource_id          = aws_api_gateway_resource.patient.id
  http_method          = "DELETE"
  authorization        = "NONE"
  api_key_required     = true
  request_validator_id = aws_api_gateway_request_validator.main.id

  request_parameters = {
    "method.request.path.patient_id" = true
  }
}

resource "aws_api_gateway_integration" "delete_patient" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.patient.id
  http_method             = aws_api_gateway_method.delete_patient.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  depends_on = [
    aws_api_gateway_integration.create_patient,
    aws_api_gateway_integration.get_patient,
    aws_api_gateway_integration.delete_patient
  ]

  # Force redeploy when methods, integrations, or validator change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.create_patient.id,
      aws_api_gateway_method.get_patient.id,
      aws_api_gateway_method.delete_patient.id,
      aws_api_gateway_integration.create_patient.id,
      aws_api_gateway_integration.get_patient.id,
      aws_api_gateway_integration.delete_patient.id,
      aws_api_gateway_request_validator.main.id,
      aws_api_gateway_model.patient_create.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage with throttling and CloudWatch logging
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  tags = {
    Name    = "${var.project}-${var.environment}-stage"
    Purpose = "API Gateway stage"
  }
}

# Method settings: throttling on all methods
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
    metrics_enabled        = true
  }
}

# API Key
resource "aws_api_gateway_api_key" "main" {
  name        = "${var.project}-api-key"
  description = "API key for ${var.project}"
  enabled     = true
}

# Usage plan (rate limits + quotas at the key level)
resource "aws_api_gateway_usage_plan" "main" {
  name        = "${var.project}-usage-plan"
  description = "Usage plan for ${var.project} API"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  throttle_settings {
    burst_limit = 20
    rate_limit  = 10
  }

  quota_settings {
    limit  = 10000
    period = "MONTH"
  }
}

# Bind API key to usage plan
resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.main.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
