resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  address_space       = ["10.8.0.0/16"]
  location            = azurerm_resource_group.main.location
  name                = "vn-mkt-prefix-main"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "snet-mkt-prefix-main"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.8.0.0/18"]
}

data "azurerm_subnet" "main" {
  name                 = azurerm_subnet.main.name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
}

module "aks" {
  source                          = "../.."
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  prefix                          = "prefix"
  cluster_name                    = "basic-cluster"
  network_plugin                  = "azure"
  vnet_subnet_id                  = data.azurerm_subnet.main.id
  azure_policy_enabled            = true
  default_node_pool_name          = "primary"
  default_node_pool_min_count     = 1
  default_node_pool_max_count     = 1
  default_node_pool_max_pods      = 100
  net_profile_docker_bridge_cidr  = "170.10.0.1/16"
  net_profile_service_cidr        = "192.168.64.0/18"
  net_profile_dns_service_ip      = "192.168.64.10"
  depends_on                      = [azurerm_subnet.main]
  log_analytics_workspace_enabled = true

  default_node_pool_labels = {
    "nodepool" : "defaultnodepool"
  }

  agents_tags = {
    "Agent" : "defaultnodepoolagent"
  }
}
