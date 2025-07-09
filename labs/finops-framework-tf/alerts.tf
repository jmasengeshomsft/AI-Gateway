# Action Group for subscription management
resource "azurerm_monitor_action_group" "update_subscription" {
  name                = "actiongroup-update-sub-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "Update Sub"
  enabled             = true

  logic_app_receiver {
    name                    = "update-subscription-state"
    resource_id             = azurerm_logic_app_workflow.update_subscription.id
    callback_url            = azurerm_logic_app_workflow.update_subscription.access_endpoint
    use_common_alert_schema = true
  }
}

# Scheduled Query Rule to suspend subscriptions when quota exceeded
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "suspend_subscription" {
  name                = "alert-suspend-sub-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "West Europe"

  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [azurerm_log_analytics_workspace.main.id]
  severity             = 3
  enabled              = true

  criteria {
    query                   = <<-QUERY
AppMetrics
| where TimeGenerated >= startofmonth(now()) and TimeGenerated <= endofmonth(now())
| where Name == "Prompt Tokens" or Name == "Completion Tokens"
| extend SubscriptionName = tostring(Properties["Subscription ID"])
| extend ProductName = tostring(Properties["Product"])
| extend ModelName = tostring(Properties["Model"])
| extend Region = tostring(Properties["Region"])
| join kind=inner (
    PRICING_CL
    | summarize arg_max(TimeGenerated, *) by Model
    | project Model, InputTokensPrice, OutputTokensPrice
    )
    on $left.ModelName == $right.Model
| summarize
    PromptTokens = sumif(Sum, Name == "Prompt Tokens"),
    CompletionTokens = sumif(Sum, Name == "Completion Tokens")
    by SubscriptionName, InputTokensPrice, OutputTokensPrice
| extend InputCost = PromptTokens / 1000 * InputTokensPrice
| extend OutputCost = CompletionTokens / 1000 * OutputTokensPrice
| extend TotalCost = InputCost + OutputCost
| summarize TotalCost = sum(TotalCost) by SubscriptionName
| join kind=inner (
    SUBSCRIPTION_QUOTA_CL
    | summarize arg_max(TimeGenerated, *) by Subscription
    | project Subscription, CostQuota
) on $left.SubscriptionName == $right.Subscription
| project SubscriptionName, CostQuota, TotalCost
| where TotalCost > CostQuota
QUERY
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    dimension {
      name     = "SubscriptionName"
      operator = "Exclude"
      values   = ["null"]
    }

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  auto_mitigation_enabled          = false
  workspace_alerts_storage_enabled = false
  description                      = "Alert to suspend subscriptions when quota is exceeded"
  display_name                     = "alert-suspend-subscriptions"
  query_time_range_override        = "P2D"

  action {
    action_groups = [azurerm_monitor_action_group.update_subscription.id]
  }

  depends_on = [
    azapi_resource.pricing_table,
    azapi_resource.subscription_quota_table
  ]
}

# Scheduled Query Rule to activate subscriptions when under quota
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "activate_subscription" {
  name                = "alert-activate-sub-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "West Europe"

  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [azurerm_log_analytics_workspace.main.id]
  severity             = 3
  enabled              = true

  criteria {
    query                   = <<-QUERY
AppMetrics
| where TimeGenerated >= startofmonth(now()) and TimeGenerated <= endofmonth(now())
| where Name == "Prompt Tokens" or Name == "Completion Tokens"
| extend SubscriptionName = tostring(Properties["Subscription ID"])
| extend ProductName = tostring(Properties["Product"])
| extend ModelName = tostring(Properties["Model"])
| extend Region = tostring(Properties["Region"])
| join kind=inner (
    PRICING_CL
    | summarize arg_max(TimeGenerated, *) by Model
    | project Model, InputTokensPrice, OutputTokensPrice
    )
    on $left.ModelName == $right.Model
| summarize
    PromptTokens = sumif(Sum, Name == "Prompt Tokens"),
    CompletionTokens = sumif(Sum, Name == "Completion Tokens")
    by SubscriptionName, InputTokensPrice, OutputTokensPrice
| extend InputCost = PromptTokens / 1000 * InputTokensPrice
| extend OutputCost = CompletionTokens / 1000 * OutputTokensPrice
| extend TotalCost = InputCost + OutputCost
| summarize TotalCost = sum(TotalCost) by SubscriptionName
| join kind=inner (
    SUBSCRIPTION_QUOTA_CL
    | summarize arg_max(TimeGenerated, *) by Subscription
    | project Subscription, CostQuota
) on $left.SubscriptionName == $right.Subscription
| project SubscriptionName, CostQuota, TotalCost
| where TotalCost <= CostQuota
QUERY
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    dimension {
      name     = "SubscriptionName"
      operator = "Exclude"
      values   = ["null"]
    }

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  auto_mitigation_enabled          = false
  workspace_alerts_storage_enabled = false
  description                      = "Alert to activate subscriptions when under quota"
  display_name                     = "alert-activate-subscriptions"
  query_time_range_override        = "P2D"

  action {
    action_groups = [azurerm_monitor_action_group.update_subscription.id]
  }

  depends_on = [
    azapi_resource.pricing_table,
    azapi_resource.subscription_quota_table
  ]
}
