
app_suffix              = "eywwcl"
subscription_id         = "38bfc61d-d89a-4df6-b8fb-0c14568dcf29"
resource_group_name     = "openai-ai-gateway-demo"
resource_group_location = "eastus"
apim_resource_location = "eastus"
apim_sku                = "StandardV2"
openai_api_version      = "2024-10-21"
openai_config           = {
    openai-1 = {
      name     = "openai1",
      location = "eastus",
      priority = 1,
      weight   = 50
    },
    # openai-1 = {
    #   name     = "openai2",
    #   location = "eastus",
    #   priority = 1,
    #   weight   = 50
    # },
    # openai-3 = {
    #   name     = "openai3",
    #   location = "eastus",
    #   priority = 1,
    #   weight   = 50
    # }
  }

vnet_name                          = "ai-gateway-vnet"
vnet_address_space                 = "10.0.254.0/24"
subnet_apim_address_space          = "10.0.254.0/27"
subnet_private_endpoints_address_space = "10.0.254.128/25"

