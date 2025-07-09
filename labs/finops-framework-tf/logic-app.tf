# Logic App for subscription management
resource "azurerm_logic_app_workflow" "update_subscription" {
  name                = "la-update-sub-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }
  workflow_schema = jsonencode({
    "$schema"      = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
    contentVersion = "1.0.0.0"
    parameters     = {}
    triggers = {
      When_an_Alert_is_Received = {
        type = "Request"
        kind = "Http"
        inputs = {
          schema = {
            type = "object"
            properties = {
              schemaId = {
                type = "string"
              }
              data = {
                type = "object"
                properties = {
                  essentials = {
                    type = "object"
                    properties = {
                      alertId = {
                        type = "string"
                      }
                      alertRule = {
                        type = "string"
                      }
                      targetResourceType = {
                        type = "string"
                      }
                      alertRuleID = {
                        type = "string"
                      }
                      severity = {
                        type = "string"
                      }
                      signalType = {
                        type = "string"
                      }
                      monitorCondition = {
                        type = "string"
                      }
                      targetResourceGroup = {
                        type = "string"
                      }
                      monitoringService = {
                        type = "string"
                      }
                      alertTargetIDs = {
                        type = "array"
                        items = {
                          type = "string"
                        }
                      }
                      configurationItems = {
                        type = "array"
                        items = {
                          type = "string"
                        }
                      }
                      originAlertId = {
                        type = "string"
                      }
                      firedDateTime = {
                        type = "string"
                      }
                      description = {
                        type = "string"
                      }
                      essentialsVersion = {
                        type = "string"
                      }
                      alertContextVersion = {
                        type = "string"
                      }
                      investigationLink = {
                        type = "string"
                      }
                    }
                  }
                  alertContext = {
                    type = "object"
                    properties = {
                      properties = {
                        type       = "object"
                        properties = {}
                      }
                      conditionType = {
                        type = "string"
                      }
                      condition = {
                        type = "object"
                        properties = {
                          windowSize = {
                            type = "string"
                          }
                          allOf = {
                            type = "array"
                            items = {
                              type = "object"
                              properties = {
                                searchQuery = {
                                  type = "string"
                                }
                                metricMeasureColumn = {}
                                targetResourceTypes = {
                                  type = "string"
                                }
                                operator = {
                                  type = "string"
                                }
                                threshold = {
                                  type = "string"
                                }
                                timeAggregation = {
                                  type = "string"
                                }
                                dimensions = {
                                  type = "array"
                                  items = {
                                    type = "object"
                                    properties = {
                                      name = {
                                        type = "string"
                                      }
                                      value = {
                                        type = "string"
                                      }
                                    }
                                    required = [
                                      "name",
                                      "value"
                                    ]
                                  }
                                }
                                metricValue = {
                                  type = "integer"
                                }
                                failingPeriods = {
                                  type = "object"
                                  properties = {
                                    numberOfEvaluationPeriods = {
                                      type = "integer"
                                    }
                                    minFailingPeriodsToAlert = {
                                      type = "integer"
                                    }
                                  }
                                }
                                linkToSearchResultsUI = {
                                  type = "string"
                                }
                                linkToFilteredSearchResultsUI = {
                                  type = "string"
                                }
                                linkToSearchResultsAPI = {
                                  type = "string"
                                }
                                linkToFilteredSearchResultsAPI = {
                                  type = "string"
                                }
                                event = {}
                              }
                              required = [
                                "searchQuery",
                                "metricMeasureColumn",
                                "targetResourceTypes",
                                "operator",
                                "threshold",
                                "timeAggregation",
                                "dimensions",
                                "metricValue",
                                "failingPeriods",
                                "linkToSearchResultsUI",
                                "linkToFilteredSearchResultsUI",
                                "linkToSearchResultsAPI",
                                "linkToFilteredSearchResultsAPI",
                                "event"
                              ]
                            }
                          }
                          windowStartTime = {
                            type = "string"
                          }
                          windowEndTime = {
                            type = "string"
                          }
                        }
                      }
                    }
                  }
                  customProperties = {
                    type       = "object"
                    properties = {}
                  }
                }
              }
            }
          }        }
      }
    }
    actions = {
      Update_APIM_Subscription_Status = {
        runAfter = {}
        type     = "Http"
        inputs = {
          uri    = "https://management.azure.com/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.ApiManagement/service/${azapi_resource.apim.name}/subscriptions/@{triggerBody()?['data']?['alertContext']?['condition']?['allOf']?[0]?['dimensions']?[0]?['value']}?api-version=2024-06-01-preview"
          method = "PATCH"
          headers = {
            "Content-Type" = "application/json"
          }
          body = {
            properties = {
              state = "@if(contains(triggerBody()?['data']?['essentials']?['alertRule'],'suspend'),'suspended','active')"
            }
          }
          authentication = {
            type     = "ManagedServiceIdentity"
            audience = "https://management.azure.com/"
          }
        }
        runtimeConfiguration = {
          contentTransfer = {
            transferMode = "Chunked"
          }
        }
      }
    }
    outputs = {}  })
}

# Diagnostic settings for Logic App
resource "azurerm_monitor_diagnostic_setting" "workflow_diagnostics" {
  name                       = "workflowDiagnosticSettings"
  target_resource_id         = azurerm_logic_app_workflow.update_subscription.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "AllLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Role assignment for Logic App to manage APIM subscriptions
resource "azurerm_role_assignment" "apim_contributor_role" {
  scope              = azapi_resource.apim.id
  role_definition_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/312a565d-c81f-4fd8-895a-4e21e48d571c"
  principal_id       = azurerm_logic_app_workflow.update_subscription.identity[0].principal_id
  principal_type     = "ServicePrincipal"
}
