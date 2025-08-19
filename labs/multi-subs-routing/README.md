# Multi-Subscription AI Gateway with APIM

This lab demonstrates how to set up Azure API Management (APIM) to route traffic across Azure OpenAI services deployed in multiple Azure subscriptions, providing load balancing, high availability, and centralized management.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                               APIM Gateway                               │
│                        (Primary Subscription)                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Backend Pool                                 │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐│   │
│  │  │   OpenAI1   │ │   OpenAI2   │ │   OpenAI3   │ │   OpenAI4   ││   │
│  │  │  Priority:1 │ │  Priority:1 │ │  Priority:2 │ │  Priority:2 ││   │
│  │  │  Weight:50  │ │  Weight:50  │ │  Weight:30  │ │  Weight:30  ││   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘│   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
            │                                   │
            ▼                                   ▼
┌─────────────────────────┐         ┌─────────────────────────┐
│    Subscription 1       │         │    Subscription 2       │
│  ┌─────────┬─────────┐  │         │  ┌─────────┬─────────┐  │
│  │ OpenAI1 │ OpenAI2 │  │         │  │ OpenAI3 │ OpenAI4 │  │
│  │ EastUS2 │ EastUS  │  │         │  │ EastUS  │ WestUS  │  │
│  └─────────┴─────────┘  │         │  └─────────┴─────────┘  │
└─────────────────────────┘         └─────────────────────────┘
```

## Key Components

### 1. APIM Gateway (Primary Subscription)
- **StandardV2 SKU** with VNet integration
- **Backend Pool** with 4 OpenAI services across 2 subscriptions
- **Priority-based routing** (Primary: Sub1, Secondary: Sub2)
- **Circuit breakers** for resilience and failure handling
- **Managed Identity** for secure authentication

### 2. OpenAI Services Distribution
- **Subscription 1**: OpenAI1 (EastUS2), OpenAI2 (EastUS)
- **Subscription 2**: OpenAI3 (EastUS), OpenAI4 (WestUS)
- **Deployments**:
  - All services: `embedding` (text-embedding-3-small)
  - Sub2 only: `gpt-4o` (GPT-4o model)

## Networking Architecture

### VNet Configuration
```
APIM VNet (10.0.254.0/24)
├── APIM Subnet (10.0.254.0/27)
└── Private Endpoints Subnet (10.0.254.32/27)

Subscription 1 VNet (10.1.0.0/16)
└── AI Services Subnet (10.1.1.0/24)

Subscription 2 VNet (10.2.0.0/16)
└── AI Services Subnet (10.2.1.0/24)
```

### VNet Peering
- **APIM ↔ Subscription 1**: Bidirectional peering with remote gateway transit
- **APIM ↔ Subscription 2**: Bidirectional peering with remote gateway transit
- **Network connectivity**: Allows APIM to reach OpenAI services across subscriptions

### Network Security
```hcl
# OpenAI Services Network ACLs
networkAcls = {
  default_action = "Deny"  # Deny all by default
  virtual_network_rules = [
    {
      subnet_id                            = apim_subnet_id
      ignore_missing_vnet_service_endpoint = false
    }
  ]
}
```

## Authentication & Permissions

### 1. Managed Identity Configuration
- **APIM System-Assigned Managed Identity** created automatically
- **Cross-subscription role assignments** for each OpenAI service

### 2. Role Assignments
```hcl
# Each OpenAI service gets role assignment
resource "azurerm_role_assignment" "cognitive_services_openai_user" {
  scope              = azurerm_ai_services.ai_services[each.key].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id       = var.apim_principal_id  # APIM Managed Identity
}
```

### 3. API Authentication
- **Subscription Key**: Required for APIM access
- **Header**: `api-key: <subscription-key>`
- **Managed Identity**: APIM → OpenAI authentication

## Backend Pool Configuration

### Load Balancing Strategy
```json
{
  "services": [
    {
      "id": "/backends/openai1",
      "priority": 1,
      "weight": 50
    },
    {
      "id": "/backends/openai2", 
      "priority": 1,
      "weight": 50
    },
    {
      "id": "/backends/openai3",
      "priority": 2,
      "weight": 30
    },
    {
      "id": "/backends/openai4",
      "priority": 2,
      "weight": 30
    }
  ]
}
```

### Circuit Breaker Configuration
```json
{
  "circuitBreaker": {
    "rules": [
      {
        "name": "openAIBreakerRule",
        "failureCondition": {
          "count": 1,
          "interval": "PT5M",
          "statusCodeRanges": [{"min": 429, "max": 429}],
          "errorReasons": ["Server errors"]
        },
        "tripDuration": "PT1M",
        "acceptRetryAfter": true
      }
    ]
  }
}
```

## Deployment Instructions

### Prerequisites
- Two Azure subscriptions with appropriate permissions
- Terraform installed
- Azure CLI authenticated

### 1. Configure Variables
```bash
# Update terraform.tfvars
primary_subscription_id   = "your-primary-subscription-id"
secondary_subscription_id = "your-secondary-subscription-id"
app_suffix               = "your-unique-suffix"
```

### 2. Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

### 3. Test Endpoints
```bash
# Get subscription key
APIM_KEY=$(terraform output -raw apim_subscription_key)

# Test embeddings (available on all services)
curl -X POST "https://apim-<suffix>.azure-api.net/openai/deployments/embedding/embeddings?api-version=2024-02-01" \
  -H "api-key: $APIM_KEY" \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello world"}'

# Test GPT-4o (only available on openai3/openai4)
curl -X POST "https://apim-<suffix>.azure-api.net/openai/deployments/gpt-4o/chat/completions?api-version=2024-02-01" \
  -H "api-key: $APIM_KEY" \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Hello!"}], "max_tokens": 10}'
```

## Traffic Routing Logic

### 1. Primary Traffic (Priority 1)
- **50%** → OpenAI1 (Subscription 1, EastUS2)
- **50%** → OpenAI2 (Subscription 1, EastUS)

### 2. Failover Traffic (Priority 2)
- **30%** → OpenAI3 (Subscription 2, EastUS)
- **30%** → OpenAI4 (Subscription 2, WestUS)

### 3. Circuit Breaker Behavior
- Monitors for **429 (Rate Limit)** and **5xx errors**
- Trips after **1 failure** in **5-minute window**
- **1-minute trip duration** with retry-after header respect
- Automatically routes to healthy backends

## Monitoring & Observability

### Application Insights Integration
- **Request/response logging** for all API calls
- **Performance metrics** and latency tracking
- **Error tracking** and failure analysis
- **Custom dashboards** for operational insights

### Key Metrics to Monitor
- **Request Rate**: Total API calls per minute
- **Response Time**: P50, P95, P99 latencies
- **Error Rate**: 4xx and 5xx error percentages
- **Backend Health**: Circuit breaker status
- **Token Usage**: OpenAI token consumption

## Security Considerations

### Network Security
- **Private endpoints** for OpenAI services
- **VNet integration** for APIM
- **Network ACLs** restricting access to APIM subnet only
- **NSG rules** for fine-grained traffic control

### Identity Security  
- **Managed identities** instead of API keys
- **Role-based access control** (RBAC)
- **Least privilege principle** for service permissions

### API Security
- **Subscription keys** for client authentication
- **Rate limiting** via APIM policies
- **Request/response filtering** and validation

## Troubleshooting

### Common Issues
1. **404 Errors**: Check backend URLs don't have double `/openai` paths
2. **401 Errors**: Verify managed identity role assignments
3. **429 Errors**: Check circuit breaker configuration and quotas
4. **Network Issues**: Validate VNet peering and NSG rules

### Useful Commands
```bash
# Check backend health
az rest --method GET --url "https://management.azure.com/.../backends"

# View APIM logs
az monitor activity-log list --resource-group <rg-name>

# Test direct OpenAI access
curl -H "Authorization: Bearer $(az account get-access-token --query accessToken -o tsv)" \
  "https://openai1-<suffix>.cognitiveservices.azure.com/openai/deployments?api-version=2024-02-01"
```

## Cost Optimization

### APIM Scaling
- **Auto-scaling** configured based on capacity metrics
- **Scale out** at 70% capacity, **scale in** at 30%
- **Minimum**: 1 unit, **Maximum**: 10 units

### Regional Distribution
- **Primary region**: EastUS2/EastUS (lower latency)
- **Secondary region**: WestUS (disaster recovery)
- **Cross-region failover** via priority-based routing

## Next Steps

1. **Production Hardening**: Restore network ACLs to "Deny" mode
2. **Custom Domains**: Configure custom domain with SSL certificates  
3. **Advanced Policies**: Implement caching, transformation, and validation
4. **Monitoring Alerts**: Set up automated alerting for key metrics
5. **Blue-Green Deployments**: Implement deployment strategies for updates
