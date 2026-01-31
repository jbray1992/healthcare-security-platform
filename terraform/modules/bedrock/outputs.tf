output "guardrail_id" {
  description = "ID of the Bedrock Guardrail"
  value       = aws_bedrock_guardrail.pii_filter.guardrail_id
}

output "guardrail_arn" {
  description = "ARN of the Bedrock Guardrail"
  value       = aws_bedrock_guardrail.pii_filter.guardrail_arn
}

output "guardrail_version" {
  description = "Version of the Bedrock Guardrail"
  value       = aws_bedrock_guardrail_version.pii_filter.version
}
