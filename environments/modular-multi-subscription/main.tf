# APIM Gateway Module (deployed in primary subscription)
module "apim_gateway" {
  source = "../../modules-tf/apim-gateway"
  
  providers = {
    azurerm = azurerm.primary
  }

  # Basic Configuration
  subscription_id         = var.primary_subscription_id
  resource_group_name     = "apim-gateway-${var.app_suffix}"
  resource_group_location = var.apim_resource_location
  app_suffix              = var.app_suffix

  # APIM Configuration
  apim_resource_name     = var.apim_resource_name
  apim_resource_location = var.apim_resource_location
  apim_sku               = var.apim_sku
  apim_sku_capacity      = var.apim_sku_capacity

  # Network Configuration
  vnet_name                              = var.vnet_name
  vnet_address_space                     = var.vnet_address_space
  subnet_apim_address_space              = var.subnet_apim_address_space
  subnet_private_endpoints_address_space = var.subnet_private_endpoints_address_space

  # OpenAI API Configuration
  openai_api_spec_url = var.openai_api_spec_url

  # Auto Scaling
  enable_apim_autoscale       = var.enable_apim_autoscale
  apim_autoscale_min_capacity = var.apim_autoscale_min_capacity
  apim_autoscale_max_capacity = var.apim_autoscale_max_capacity

  # Backend pools from AI subscription modules
  backend_pools = [
    module.ai_subscription_1.backend_config,
    module.ai_subscription_2.backend_config,
  ]
}

# AI Services in Subscription 1
module "ai_subscription_1" {
  source = "../../modules-tf/ai-subscription"
  
  providers = {
    azurerm = azurerm.subscription1
  }

  # Basic Configuration
  subscription_id         = var.subscription_configs.subscription1.subscription_id
  resource_group_name     = var.subscription_configs.subscription1.resource_group_name
  resource_group_location = var.subscription_configs.subscription1.resource_group_location
  app_suffix              = var.app_suffix

  # OpenAI Configuration
  openai_config      = var.subscription_configs.subscription1.openai_config
  openai_deployments = var.subscription_configs.subscription1.openai_deployments
  openai_sku         = var.openai_sku

  # VNet Configuration
  vnet_name                          = var.subscription_configs.subscription1.vnet_name
  vnet_address_space                 = var.subscription_configs.subscription1.vnet_address_space
  subnet_ai_services_address_space   = var.subscription_configs.subscription1.subnet_ai_services_address_space

  # Integration with APIM (cross-subscription VNet peering)
  apim_vnet_id               = module.apim_gateway.apim_vnet_id
  apim_vnet_name             = module.apim_gateway.apim_vnet_name
  apim_subnet_id             = module.apim_gateway.apim_subnet_id
  apim_resource_group_name   = module.apim_gateway.resource_group_name
  apim_principal_id          = module.apim_gateway.apim_principal_id
  log_analytics_workspace_id = module.apim_gateway.log_analytics_workspace_id
}

# AI Services in Subscription 2  
module "ai_subscription_2" {
  source = "../../modules-tf/ai-subscription"
  
  providers = {
    azurerm = azurerm.subscription2
  }

  # Basic Configuration
  subscription_id         = var.subscription_configs.subscription2.subscription_id
  resource_group_name     = var.subscription_configs.subscription2.resource_group_name
  resource_group_location = var.subscription_configs.subscription2.resource_group_location
  app_suffix              = var.app_suffix

  # OpenAI Configuration
  openai_config      = var.subscription_configs.subscription2.openai_config
  openai_deployments = var.subscription_configs.subscription2.openai_deployments
  openai_sku         = var.openai_sku

  # VNet Configuration
  vnet_name                          = var.subscription_configs.subscription2.vnet_name
  vnet_address_space                 = var.subscription_configs.subscription2.vnet_address_space
  subnet_ai_services_address_space   = var.subscription_configs.subscription2.subnet_ai_services_address_space

  # Integration with APIM (cross-subscription VNet peering)
  apim_vnet_id               = module.apim_gateway.apim_vnet_id
  apim_vnet_name             = module.apim_gateway.apim_vnet_name
  apim_subnet_id             = module.apim_gateway.apim_subnet_id
  apim_resource_group_name   = module.apim_gateway.resource_group_name
  apim_principal_id          = module.apim_gateway.apim_principal_id
  log_analytics_workspace_id = module.apim_gateway.log_analytics_workspace_id
}
