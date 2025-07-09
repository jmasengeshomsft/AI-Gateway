# Test file to check azurerm_cognitive_deployment syntax
resource "azurerm_cognitive_deployment" "test" {
  name                 = "test"
  cognitive_account_id = "test"

  model {
    format  = "OpenAI"
    name    = "gpt-4"
    version = "1"
  }
  sku {
    name     = "Standard"
    capacity = 1
  }
}
