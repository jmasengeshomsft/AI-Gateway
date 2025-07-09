# Generate GUIDs for workbook names
resource "random_uuid" "alerts_workbook_id" {}
resource "random_uuid" "azure_openai_insights_workbook_id" {}
resource "random_uuid" "cost_analysis_workbook_id" {}

# Alerts Workbook
resource "azapi_resource" "alerts_workbook" {
  type      = "Microsoft.Insights/workbooks@2022-04-01"
  name      = random_uuid.alerts_workbook_id.result
  location  = azurerm_resource_group.main.location
  parent_id = azurerm_resource_group.main.id

  body = {
    kind = "shared"
    properties = {
      displayName    = "Alerts Workbook"
      serializedData = file("${path.module}/workbooks/alerts.json")
      sourceId       = azurerm_log_analytics_workspace.main.id
      category       = "workbook"
    }
  }
}

# Azure OpenAI Insights Workbook
resource "azapi_resource" "azure_openai_insights_workbook" {
  type      = "Microsoft.Insights/workbooks@2022-04-01"
  name      = random_uuid.azure_openai_insights_workbook_id.result
  location  = azurerm_resource_group.main.location
  parent_id = azurerm_resource_group.main.id

  body = {
    kind = "shared"
    properties = {
      displayName    = "Azure OpenAI Insights"
      serializedData = jsonencode(jsondecode(file("${path.module}/workbooks/azure-openai-insights.json")))
      sourceId       = azurerm_log_analytics_workspace.main.id
      category       = "workbook"
    }
  }
}

# Cost Analysis Workbook
resource "azapi_resource" "cost_analysis_workbook" {
  type      = "Microsoft.Insights/workbooks@2022-04-01"
  name      = random_uuid.cost_analysis_workbook_id.result
  location  = azurerm_resource_group.main.location
  parent_id = azurerm_resource_group.main.id

  body = {
    kind = "shared"
    properties = {
      displayName    = "Cost Analysis"
      serializedData = replace(file("${path.module}/workbooks/cost-analysis.json"), "{workspace-id}", azurerm_log_analytics_workspace.main.id)
      sourceId       = azurerm_log_analytics_workspace.main.id
      category       = "workbook"
    }
  }
}
