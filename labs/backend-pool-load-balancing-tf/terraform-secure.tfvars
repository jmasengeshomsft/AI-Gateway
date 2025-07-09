
app_suffix              = "eq9wMc4L"
resource_group_name     = "lab-backend-pool-load-balancing-tf"
resource_group_location = "westeurope"
apim_sku                = "StandardV2"
openai_deployment_name  = "gpt-4o"
openai_model_name       = "gpt-4o"
openai_model_version    = "2024-08-06"
openai_model_capacity   = "10"
openai_api_version      = "2024-10-21"
openai_config           = {
    openai-uks = {
      name     = "openai1",
      location = "eastus",
      priority = 1,
      weight   = 100
    },
    openai-swc = {
      name     = "openai2",
      location = "eastus",
      priority = 2,
      weight   = 50
    },
    openai-frc = {
      name     = "openai3",
      location = "eastus",
      priority = 2,
      weight   = 50
    }
  }

openai_deployments = {
  gpt = {
    deployment_name = "gpt-4o"
    model_name      = "gpt-4o"
    model_version   = "2024-08-06"
    model_capacity  = 8
  }
  embedding = {
    deployment_name = "embedding"
    model_name      = "text-embedding-3-small"
    model_version   = "1"
    model_capacity  = 8
  }
}

vnet_name                          = "my-vnet"
vnet_address_space                 = "10.0.254.0/24"
subnet_apim_address_space          = "10.0.254.0/27"
subnet_private_endpoints_address_space = "10.0.254.128/25"

