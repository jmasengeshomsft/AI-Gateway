
resource_group_name     = "lab-backend-pool-load-balancing-tf"
resource_group_location = "westeurope"
apim_sku                = "StandardV2"
openai_deployment_name  = "gpt-4o"
openai_model_name       = "gpt-4o"
openai_model_version    = "2024-08-06"
openai_model_capacity   = "8"
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

