# Bedrock Guardrail for PII detection and filtering
resource "aws_bedrock_guardrail" "pii_filter" {
  name                      = "${var.project}-pii-guardrail"
  description               = "Guardrail to detect and filter PII from patient clinical notes"
  blocked_input_messaging   = "Your input contains sensitive information that cannot be processed."
  blocked_outputs_messaging = "The response contains sensitive information that cannot be displayed."

  sensitive_information_policy_config {
    pii_entities_config {
      action = "BLOCK"
      type   = "US_SOCIAL_SECURITY_NUMBER"
    }
    pii_entities_config {
      action = "BLOCK"
      type   = "CREDIT_DEBIT_CARD_NUMBER"
    }
    pii_entities_config {
      action = "ANONYMIZE"
      type   = "EMAIL"
    }
    pii_entities_config {
      action = "ANONYMIZE"
      type   = "PHONE"
    }
    pii_entities_config {
      action = "ANONYMIZE"
      type   = "NAME"
    }
    pii_entities_config {
      action = "ANONYMIZE"
      type   = "US_INDIVIDUAL_TAX_IDENTIFICATION_NUMBER"
    }
  }

  tags = {
    Name    = "${var.project}-pii-guardrail"
    Purpose = "PII detection and filtering for clinical notes"
  }
}

# Guardrail version
resource "aws_bedrock_guardrail_version" "pii_filter" {
  guardrail_arn = aws_bedrock_guardrail.pii_filter.guardrail_arn
  description   = "Initial version"
}
