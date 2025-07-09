resource "azurerm_portal_dashboard" "finops" {
  name                = "${var.resource_suffix}-finops-dashboard"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = {
    "hidden-title" = "APIM❤️OpenAI- FinOps dashboard"
  }

  dashboard_properties = templatefile("${path.module}/dashboard.json", {
    subscription_id                   = data.azurerm_client_config.current.subscription_id
    resource_group_name               = var.resource_group_name
    resource_group_id                 = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
    workspace_id                      = var.workspace_id
    workspace_name                    = var.workspace_name
    workbook_cost_analysis_id         = var.workbook_cost_analysis_id
    workbook_azure_openai_insights_id = var.workbook_azure_openai_insights_id
    app_insights_id                   = var.app_insights_id
    app_insights_name                 = var.app_insights_name
  })
}

data "azurerm_client_config" "current" {}
