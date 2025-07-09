variable "resource_suffix" {
  description = "Unique suffix for resource naming"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "workspace_id" {
  description = "Resource ID of the Log Analytics workspace"
  type        = string
}

variable "workbook_cost_analysis_id" {
  description = "Resource ID of the Cost Analysis workbook"
  type        = string
}

variable "workbook_azure_openai_insights_id" {
  description = "Resource ID of the Azure OpenAI Insights workbook"
  type        = string
}

variable "workspace_openai_dimension" {
  description = "OpenAI dimension for workspace"
  type        = string
  default     = "openai"
}

variable "app_insights_id" {
  description = "Resource ID of Application Insights"
  type        = string
}

variable "app_insights_name" {
  description = "Name of Application Insights"
  type        = string
}
