# Dashboard module
module "finops_dashboard" {
  source = "./modules/dashboard"

  resource_suffix                   = local.resource_suffix
  resource_group_name               = azurerm_resource_group.main.name
  location                          = azurerm_resource_group.main.location
  workspace_name                    = azurerm_log_analytics_workspace.main.name
  workspace_id                      = azurerm_log_analytics_workspace.main.id
  workbook_cost_analysis_id         = azapi_resource.cost_analysis_workbook.id
  workbook_azure_openai_insights_id = azapi_resource.azure_openai_insights_workbook.id
  workspace_openai_dimension        = "openai"
  app_insights_id                   = azurerm_application_insights.main.id
  app_insights_name                 = azurerm_application_insights.main.name
}
