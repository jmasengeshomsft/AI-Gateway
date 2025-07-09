# FinOps Framework - Terraform

This directory contains the Terraform version of the complete FinOps framework for Azure API Management and OpenAI services. This deployment includes comprehensive monitoring, cost management, and automated subscription management capabilities.

## Architecture

The deployment creates:

- **Log Analytics Workspace** with custom tables for pricing and subscription quota data
- **Data Collection Rules (DCRs)** for custom log ingestion
- **Application Insights** with custom metrics support
- **API Management Service** with OpenAI API integration
- **Cognitive Services (OpenAI)** with model deployments
- **Azure Monitor Workbooks** for cost analysis and OpenAI insights
- **Logic App** for automated subscription management
- **Action Groups and Alert Rules** for quota monitoring
- **Portal Dashboard** for comprehensive monitoring

## Prerequisites

1. **Terraform** installed (version 1.0 or later)
2. **Azure CLI** installed and authenticated
3. **Azure subscription** with appropriate permissions
4. **Azure AD Object ID** for role assignments

## Quick Start

1. **Clone and navigate to the directory:**
   ```bash
   cd labs/finops-framework-tf
   ```

2. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Update terraform.tfvars with your values:**
   - Set your Azure AD Object ID
   - Configure OpenAI deployments
   - Set up APIM products and subscriptions

4. **Initialize Terraform:**
   ```bash
   terraform init
   ```

5. **Validate the configuration:**
   ```bash
   terraform validate
   ```

6. **Plan the deployment:**
   ```bash
   terraform plan
   ```

7. **Apply the deployment:**
   ```bash
   terraform apply -auto-approve
   ```

## Configuration

### Required Variables

- `current_user_object_id`: Your Azure AD Object ID for role assignments

### Optional Variables

- `resource_group_name`: Name of the resource group (default: "rg-finops-framework")
- `location`: Azure region (default: "East US")
- `apim_sku`: API Management SKU (default: "Developer_1")
- `openai_deployments`: List of OpenAI model deployments
- `apim_products_config`: APIM products configuration
- `apim_users_config`: APIM users configuration
- `apim_subscriptions_config`: APIM subscriptions configuration

## File Structure

```
finops-framework-tf/
├── main.tf                    # Core infrastructure resources
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── apim.tf                    # API Management configuration
├── workbooks.tf               # Azure Monitor workbooks
├── logic-app.tf               # Logic App for subscription management
├── alerts.tf                  # Action groups and alert rules
├── dashboard.tf               # Portal dashboard module
├── modules/
│   └── dashboard/
│       ├── main.tf            # Dashboard resource
│       ├── variables.tf       # Dashboard variables
│       └── dashboard.json     # Dashboard template
├── policies/
│   ├── openai-policy.xml      # OpenAI API policy
│   └── products-policy.xml    # Product rate limiting policy
├── workbooks/
│   ├── alerts.json            # Alerts workbook
│   ├── azure-openai-insights.json  # OpenAI insights workbook
│   └── cost-analysis.json     # Cost analysis workbook
├── terraform.tfvars.example   # Example configuration
└── README.md                  # This file
```

## Features

### Cost Management
- Real-time cost tracking and quota monitoring
- Automated subscription suspension when quotas exceeded
- Cost analysis workbooks and dashboards

### Monitoring & Alerting
- Comprehensive Application Insights integration
- Custom Log Analytics tables for pricing and quota data
- Automated alert rules with Logic App integration
- Portal dashboard with key metrics

### API Management
- Token-based rate limiting per product
- Circuit breaker patterns for resilience
- Comprehensive diagnostic logging
- Managed identity authentication to OpenAI

### Workbooks
- **Alerts Workbook**: Monitor system alerts and notifications
- **Azure OpenAI Insights**: Detailed OpenAI usage analytics
- **Cost Analysis**: Subscription cost tracking and quota management

## Outputs

After deployment, the following outputs are available:

- `application_insights_app_id`: Application Insights Application ID
- `apim_gateway_url`: API Management gateway URL
- `apim_subscriptions`: List of subscription keys (sensitive)
- `pricing_dcr_endpoint`: Data Collection Rule endpoint for pricing data
- `subscription_quota_dcr_endpoint`: Data Collection Rule endpoint for quota data

## Clean Up

To destroy the deployment:

```bash
terraform destroy
```

## Troubleshooting

1. **Authentication Issues**: Ensure you're logged in to Azure CLI
2. **Permission Issues**: Verify you have Contributor access to the subscription
3. **Resource Naming**: Some resources require globally unique names
4. **Policy Errors**: Ensure APIM policies are valid XML

## Links

- [Original Bicep Version](../finops-framework/)
- [Azure Portal Dashboard](https://portal.azure.com/#dashboard)
- [Application Insights](https://portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.Insights%2Fcomponents)
- [API Management](https://portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.ApiManagement%2Fservice)
