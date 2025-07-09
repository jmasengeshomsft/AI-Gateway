# FinOps Framework Terraform Configuration
# This file contains actual values for deployment - keep secure and do not commit to version control

# Resource configuration
resource_group_name       = "rg-finops-framework-test"
location                 = "East US"
openai_resource_location = "East US"
openai_api_version      = "2024-02-01"

# APIM SKU (use Developer for testing, Standard/Premium for production)
apim_sku = "Developer_1"

# Current user object ID for role assignments (replace with your object ID)
current_user_object_id = "7aa232e5-6824-4386-bb18-411ada42495b"

# OpenAI Model Deployments
openai_deployments = [
  {
    name     = "gpt-4o"
    model    = "gpt-4o"
    version  = "2024-08-06"
    capacity = 10
  },
  {
    name     = "gpt-4o-mini"
    model    = "gpt-4o-mini"
    version  = "2024-07-18"
    capacity = 10
  },
  {
    name     = "text-embedding-ada-002"
    model    = "text-embedding-ada-002"
    version  = "2"
    capacity = 10
  }
]

# APIM Products Configuration
apim_products_config = [
  {
    name         = "basic"
    display_name = "Basic"
    tpm          = 1000
  },
  {
    name         = "standard"
    display_name = "Standard"
    tpm          = 10000
  },
  {
    name         = "premium"
    display_name = "Premium"
    tpm          = 50000
  }
]

# APIM Users Configuration
apim_users_config = [
  {
    name       = "test-user"
    first_name = "Test"
    last_name  = "User"
    email      = "test.user@example.com"
  }
]

# APIM Subscriptions Configuration
apim_subscriptions_config = [
  {
    name         = "basic-subscription"
    display_name = "Basic Subscription"
    product      = "basic"
  },
  {
    name         = "standard-subscription"
    display_name = "Standard Subscription"
    product      = "standard"
  }
]
