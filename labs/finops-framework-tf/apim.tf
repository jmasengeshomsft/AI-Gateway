# Read the OpenAI policy file
locals {
  openai_policy_content   = file("${path.module}/policies/openai-policy.xml")
  product_policy_template = file("${path.module}/policies/products-policy.xml")
}

# OpenAI API in APIM
resource "azurerm_api_management_api" "openai" {
  name                  = "openai"
  resource_group_name   = azurerm_resource_group.main.name
  api_management_name   = azapi_resource.apim.name
  revision              = "1"
  display_name          = "OpenAI"
  path                  = "openai"
  protocols             = ["https"]
  description           = "OpenAI Inference API"
  subscription_required = true

  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }

  import {
    content_format = "openapi-link"
    content_value  = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/${var.openai_api_version}/inference.json"
  }
}

# API Policy
resource "azurerm_api_management_api_policy" "openai_policy" {
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.main.name
  xml_content         = local.openai_policy_content
}

# OpenAI Backend
resource "azurerm_api_management_backend" "openai" {
  name                = "openai-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azapi_resource.apim.name
  protocol            = "http"
  url                 = "${azurerm_cognitive_account.openai.endpoint}/openai"
  description         = "OpenAI backend"
}

# API Diagnostics for Application Insights
resource "azurerm_api_management_api_diagnostic" "openai_diagnostics" {
  identifier               = "applicationinsights"
  resource_group_name      = azurerm_resource_group.main.name
  api_management_name      = azapi_resource.apim.name
  api_name                 = azurerm_api_management_api.openai.name
  api_management_logger_id = azurerm_api_management_logger.main.id

  sampling_percentage       = 100.0
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "verbose"
  http_correlation_protocol = "W3C"

  frontend_request {
    body_bytes     = local.log_settings.body.bytes
    headers_to_log = local.log_settings.headers
  }

  frontend_response {
    body_bytes     = local.log_settings.body.bytes
    headers_to_log = local.log_settings.headers
  }

  backend_request {
    body_bytes     = local.log_settings.body.bytes
    headers_to_log = local.log_settings.headers
  }

  backend_response {
    body_bytes     = local.log_settings.body.bytes
    headers_to_log = local.log_settings.headers
  }
}

# APIM Products
resource "azurerm_api_management_product" "products" {
  for_each = { for idx, product in var.apim_products_config : idx => product }

  product_id            = each.value.name
  api_management_name   = azapi_resource.apim.name
  resource_group_name   = azurerm_resource_group.main.name
  display_name          = each.value.display_name
  description           = each.value.display_name
  subscription_required = true
  approval_required     = false
  published             = true
}

# Link OpenAI API to Products
resource "azurerm_api_management_product_api" "product_api_links" {
  for_each = { for idx, product in var.apim_products_config : idx => product }
  api_name            = azurerm_api_management_api.openai.name
  product_id          = azurerm_api_management_product.products[each.key].product_id
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.main.name
}

# Product Policies (Rate Limiting)
resource "azurerm_api_management_product_policy" "product_policies" {
  for_each = { for idx, product in var.apim_products_config : idx => product }
  product_id          = azurerm_api_management_product.products[each.key].product_id
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.main.name
  xml_content         = replace(local.product_policy_template, "{tokens-per-minute}", tostring(each.value.tpm))
}

# APIM Users
resource "azurerm_api_management_user" "users" {
  for_each = { for idx, user in var.apim_users_config : idx => user }
  user_id             = each.value.name
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.main.name
  first_name          = each.value.first_name
  last_name           = each.value.last_name
  email               = each.value.email
  state               = "active"
}

# APIM Subscriptions
resource "azurerm_api_management_subscription" "subscriptions" {
  for_each = { for idx, subscription in var.apim_subscriptions_config : idx => subscription }
  subscription_id     = each.value.name
  api_management_name = azapi_resource.apim.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = each.value.display_name
  product_id          = azurerm_api_management_product.products[index(var.apim_products_config[*].name, each.value.product)].id
  state               = "active"
  allow_tracing       = true

  depends_on = [
    azurerm_api_management_product.products,
    azurerm_api_management_product_policy.product_policies
  ]
}
