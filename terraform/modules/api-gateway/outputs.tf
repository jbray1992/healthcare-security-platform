output "api_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_endpoint" {
  description = "Invoke URL for the API"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_execution_arn" {
  description = "Execution ARN of the API"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_key_id" {
  description = "ID of the API key (use to retrieve value via aws apigateway get-api-key)"
  value       = aws_api_gateway_api_key.main.id
}

output "api_key_value" {
  description = "Value of the API key (use as x-api-key header)"
  value       = aws_api_gateway_api_key.main.value
  sensitive   = true
}
