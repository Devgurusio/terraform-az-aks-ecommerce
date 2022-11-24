resource "tls_private_key" "ssh" {
  count = var.admin_username == null ? 0 : 1

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "azurerm_kubernetes_cluster" "main" {
  location                            = var.location
  name                                = var.cluster_name == null ? "${var.prefix}-aks" : var.cluster_name
  resource_group_name                 = var.resource_group_name
  api_server_authorized_ip_ranges     = var.api_server_authorized_ip_ranges
  azure_policy_enabled                = var.azure_policy_enabled
  disk_encryption_set_id              = var.disk_encryption_set_id
  dns_prefix                          = var.prefix
  http_application_routing_enabled    = var.http_application_routing_enabled
  kubernetes_version                  = var.kubernetes_version
  local_account_disabled              = var.local_account_disabled
  node_resource_group                 = var.node_resource_group
  oidc_issuer_enabled                 = var.oidc_issuer_enabled
  open_service_mesh_enabled           = var.open_service_mesh_enabled
  private_cluster_enabled             = var.private_cluster_enabled
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled
  private_dns_zone_id                 = var.private_dns_zone_id
  sku_tier                            = var.sku_tier
  tags                                = var.tags
  workload_identity_enabled           = var.workload_identity_enabled
  role_based_access_control_enabled   = var.rbac_enabled

  default_node_pool {
    name                   = var.default_node_pool_name
    vm_size                = var.default_node_pool_size
    enable_auto_scaling    = var.default_node_pool_enable_auto_scaling
    enable_host_encryption = var.default_node_pool_enable_host_encryption
    enable_node_public_ip  = var.default_node_pool_enable_node_public_ip
    max_count              = var.default_node_pool_max_count
    max_pods               = var.default_node_pool_max_pods
    min_count              = var.default_node_pool_min_count
    node_count             = var.default_node_pool_node_count
    node_labels            = var.default_node_pool_labels
    orchestrator_version   = var.orchestrator_version
    os_disk_size_gb        = var.default_node_pool_os_disk_size_gb
    os_disk_type           = var.default_node_pool_os_disk_type
    tags                   = merge(var.tags, var.agents_tags)
    type                   = var.agents_type
    ultra_ssd_enabled      = var.default_node_pool_ultra_ssd_enabled
    vnet_subnet_id         = var.vnet_subnet_id
    zones                  = var.default_node_pool_agents_availability_zones
  }

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = var.rbac_aad_admin_group_object_ids
    azure_rbac_enabled     = var.rbac_enabled
    managed                = var.rbac_managed
    tenant_id              = var.rbac_aad_tenant_id
  }

  dynamic "aci_connector_linux" {
    for_each = var.aci_connector_linux_enabled ? ["aci_connector_linux"] : []

    content {
      subnet_name = var.aci_connector_linux_subnet_name
    }
  }

  dynamic "identity" {
    for_each = var.client_id == "" || var.client_secret == "" ? ["identity"] : []

    content {
      type         = var.identity_type
      identity_ids = var.identity_ids
    }
  }
  dynamic "ingress_application_gateway" {
    for_each = var.ingress_application_gateway_enabled ? ["ingress_application_gateway"] : []

    content {
      gateway_id   = var.ingress_application_gateway_id
      gateway_name = var.ingress_application_gateway_name
      subnet_cidr  = var.ingress_application_gateway_subnet_cidr
      subnet_id    = var.ingress_application_gateway_subnet_id
    }
  }
  dynamic "key_vault_secrets_provider" {
    for_each = var.key_vault_secrets_provider_enabled ? ["key_vault_secrets_provider"] : []

    content {
      secret_rotation_enabled  = var.secret_rotation_enabled
      secret_rotation_interval = var.secret_rotation_interval
    }
  }
  dynamic "linux_profile" {
    for_each = var.admin_username == null ? [] : ["linux_profile"]

    content {
      admin_username = var.admin_username

      ssh_key {
        key_data = replace(coalesce(var.public_ssh_key, tls_private_key.ssh[0].public_key_openssh), "\n", "")
      }
    }
  }
  dynamic "maintenance_window" {
    for_each = var.maintenance_window != null ? ["maintenance_window"] : []

    content {
      dynamic "allowed" {
        for_each = var.maintenance_window.allowed

        content {
          day   = allowed.value.day
          hours = allowed.value.hours
        }
      }
      dynamic "not_allowed" {
        for_each = var.maintenance_window.not_allowed

        content {
          end   = not_allowed.value.end
          start = not_allowed.value.start
        }
      }
    }
  }
  dynamic "microsoft_defender" {
    for_each = var.microsoft_defender_enabled ? ["microsoft_defender"] : []

    content {
      log_analytics_workspace_id = local.log_analytics_workspace.id
    }
  }
  network_profile {
    network_plugin     = var.network_plugin
    dns_service_ip     = var.net_profile_dns_service_ip
    docker_bridge_cidr = var.net_profile_docker_bridge_cidr
    network_policy     = var.network_policy
    outbound_type      = var.net_profile_outbound_type
    pod_cidr           = var.net_profile_pod_cidr
    service_cidr       = var.net_profile_service_cidr
  }
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_enabled ? ["oms_agent"] : []

    content {
      log_analytics_workspace_id = local.log_analytics_workspace.id
    }
  }
  dynamic "service_principal" {
    for_each = var.client_id != "" && var.client_secret != "" ? ["service_principal"] : []

    content {
      client_id     = var.client_id
      client_secret = var.client_secret
    }
  }

  lifecycle {
    precondition {
      condition     = local.condition_identity_type
      error_message = "Either `client_id` and `client_secret` or `identity_type` must be set."
    }
    precondition {
      # Why don't use var.identity_ids != null && length(var.identity_ids)>0 ? Because bool expression in Terraform is not short circuit so even var.identity_ids is null Terraform will still invoke length function with null and cause error. https://github.com/hashicorp/terraform/issues/24128
      condition     = local.condition_identity_type_SystemAssigned
      error_message = "If use identity and `UserAssigned` or `SystemAssigned, UserAssigned` is set, an `identity_ids` must be set as well."
    }
    precondition {
      condition     = local.condition_microsoft_defender_enabled
      error_message = "Enabling Microsoft Defender requires that `log_analytics_workspace_enabled` be set to true."
    }
  }
}

# resources for AKS secondary node_pool regular
resource "azurerm_kubernetes_cluster_node_pool" "regular" {
  count                  = var.secondary_node_pool_name == "regular" ? 1 : 0
  orchestrator_version   = var.orchestrator_version
  name                   = var.secondary_node_pool_name
  kubernetes_cluster_id  = azurerm_kubernetes_cluster.main.id
  vm_size                = var.secondary_node_pool_size
  os_disk_size_gb        = var.secondary_node_pool_os_disk_size_gb
  os_disk_type           = var.secondary_node_pool_os_disk_type
  enable_auto_scaling    = var.secondary_node_pool_enable_auto_scaling
  max_count              = var.secondary_node_pool_max_count
  min_count              = var.secondary_node_pool_min_count
  node_count             = var.secondary_node_pool_node_count
  tags                   = merge(var.tags, var.agents_tags)
  vnet_subnet_id         = var.vnet_subnet_id
  enable_node_public_ip  = var.secondary_node_pool_enable_node_public_ip
  max_pods               = var.secondary_node_pool_max_pods
  enable_host_encryption = var.secondary_node_pool_enable_host_encryption
}


# resources for AKS secondary node_pool spot
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  count                  = var.secondary_node_pool_name == "spot" ? 1 : 0
  orchestrator_version   = var.orchestrator_version
  name                   = var.secondary_node_pool_name
  kubernetes_cluster_id  = azurerm_kubernetes_cluster.main.id
  vm_size                = var.secondary_node_pool_size
  os_disk_size_gb        = var.secondary_node_pool_os_disk_size_gb
  os_disk_type           = var.secondary_node_pool_os_disk_type
  enable_auto_scaling    = var.secondary_node_pool_enable_auto_scaling
  max_count              = var.secondary_node_pool_max_count
  min_count              = var.secondary_node_pool_min_count
  node_count             = var.secondary_node_pool_node_count
  priority               = var.secondary_node_pool_priority
  eviction_policy        = var.secondary_node_pool_eviction_policy
  spot_max_price         = var.secondary_node_pool_spot_max_price
  tags                   = merge(var.tags, var.agents_tags)
  vnet_subnet_id         = var.vnet_subnet_id
  enable_node_public_ip  = var.secondary_node_pool_enable_node_public_ip
  max_pods               = var.secondary_node_pool_max_pods
  enable_host_encryption = var.secondary_node_pool_enable_host_encryption
  ultra_ssd_enabled      = var.secondary_node_pool_ultra_ssd_enabled
  node_labels = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }
  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]
}

resource "azurerm_container_registry" "main" {
  count                     = var.acr_name == "" ? 0 : 1
  name                      = var.acr_name
  resource_group_name       = var.resource_group_name
  location                  = var.location
  sku                       = var.acr_sku
  admin_enabled             = var.acr_admin_enabled
  zone_redundancy_enabled   = var.acr_zone_redundancy_enabled
  anonymous_pull_enabled    = var.acr_anonymous_pull_enabled
  quarantine_policy_enabled = var.acr_quarantine_policy_enabled
  trust_policy {
    enabled = var.acr_trust_policy_enabled
  }

  retention_policy {
    days    = var.acr_retention_days
    enabled = var.acr_retention_enabled
  }
}

resource "azurerm_role_assignment" "main" {
  count                            = var.acr_name == "" ? 0 : 1
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main[0].id
  skip_service_principal_aad_check = true
}

resource "azurerm_log_analytics_workspace" "main" {
  count = local.create_analytics_workspace ? 1 : 0

  location            = var.location
  name                = var.cluster_log_analytics_workspace_name == null ? "${var.prefix}-workspace" : var.cluster_log_analytics_workspace_name
  resource_group_name = coalesce(var.log_analytics_workspace_resource_group_name, var.resource_group_name)
  retention_in_days   = var.log_retention_in_days
  sku                 = var.log_analytics_workspace_sku
  tags                = var.tags
}

locals {
  azurerm_log_analytics_workspace_id   = try(azurerm_log_analytics_workspace.main[0].id, null)
  azurerm_log_analytics_workspace_name = try(azurerm_log_analytics_workspace.main[0].name, null)
}

resource "azurerm_log_analytics_solution" "main" {
  count = local.create_analytics_solution ? 1 : 0

  location              = var.location
  resource_group_name   = var.resource_group_name
  solution_name         = "ContainerInsights"
  workspace_name        = local.log_analytics_workspace.name
  workspace_resource_id = local.log_analytics_workspace.id
  tags                  = var.tags

  plan {
    product   = "OMSGallery/ContainerInsights"
    publisher = "Microsoft"
  }
}
