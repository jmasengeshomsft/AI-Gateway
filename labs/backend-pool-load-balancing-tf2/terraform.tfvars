
app_suffix              = "eqwmcl"
resource_group_name     = "openai-ai-gateway-demo"
subscription_id         = "38bfc61d-d89a-4df6-b8fb-0c14568dcf29"
resource_group_location = "eastus"
apim_resource_location = "eastus"
apim_sku                = "StandardV2"
apim_sku_capacity       = 1
openai_api_version      = "2024-10-21"
openai_config           = {
    openai-1 = {
      name     = "openai1",
      location = "eastus",
      priority = 1,
      weight   = 100
    },
    openai-2 = {
      name     = "openai2",
      location = "eastus",
      priority = 1,
      weight   = 100
    }
    # openai-frc = {
    #   name     = "openai3",
    #   location = "eastus",
    #   priority = 2,
    #   weight   = 50
    # }
  }

openai_deployments = {
  gpt = {
    deployment_name = "gpt-4o"
    model_name      = "gpt-4o"
    model_version   = "2024-08-06"
    model_capacity  = 50
  }
  embedding = {
    deployment_name = "embedding"
    model_name      = "text-embedding-3-small"
    model_version   = "1"
    model_capacity  = 50
  }
}

vnet_name                          = "ai-gateway-network"
vnet_address_space                 = "10.0.254.0/24"
subnet_apim_address_space          = "10.0.254.0/27"
subnet_private_endpoints_address_space = "10.0.254.128/25"

