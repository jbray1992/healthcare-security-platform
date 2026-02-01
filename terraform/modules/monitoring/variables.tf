variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "alert_email" {
  description = "Email address for security alerts"
  type        = string
  default     = ""
}
