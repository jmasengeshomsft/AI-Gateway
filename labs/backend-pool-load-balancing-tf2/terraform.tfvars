
app_suffix              = "az0005"
resource_group_name     = "deepdraft"
subscription_id         = "5a552781-da94-4df2-b0d3-e36e2a4de7f9"
resource_group_location = "eastus2"
apim_resource_location = "eastus2"
apim_sku                = "StandardV2"
apim_sku_capacity       = 1
openai_api_version      = "2024-10-21"
openai_config           = {
    openai-1 = {
      name     = "openai1",
      location = "eastus2",
      priority = 1,
      weight   = 100
    },
    # openai-2 = {
    #   name     = "openai2",
    #   location = "eastus",
    #   priority = 1,
    #   weight   = 100
    # }
  }

openai_deployments = {
  gpt-5 = {
    deployment_name = "gpt-5-chat"
    model_name      = "gpt-5-chat"
    model_version   = "2025-08-07"
    model_capacity  = 3
  }
  gpt4-1 = {
    deployment_name = "gpt-4.1"
    model_name      = "gpt-4.1"
    model_version   = "2025-04-14"
    model_capacity  = 3
  }
  # embedding = {
  #   deployment_name = "embedding"
  #   model_name      = "text-embedding-3-small"
  #   model_version   = "1"
  #   model_capacity  = 10
  # }
}

vnet_name                          = "ai-gateway-network"
vnet_address_space                 = "10.0.254.0/24"
subnet_apim_address_space          = "10.0.254.0/27"
subnet_private_endpoints_address_space = "10.0.254.128/25"


