terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "rg" {
    name = "${var.prefix}-${var.environment}"
    location = "${var.location}"
}

# WEBAPP


resource "azurerm_storage_account" "sa-function" {
  name                     = "${var.prefix}functionsapp"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "plan" {
  name                    = "${var.prefix}-premiumPlan"
  resource_group_name     = "${azurerm_resource_group.rg.name}"
  location                = "${var.location}"
  kind                    = "Linux"
  reserved                = true

  sku {
    tier = "Premium"
    size = "P1V2"
  }
}

resource "azurerm_function_app" "funcApp" {
    name                       = "userapi-fa-${var.prefix}"
    location                   = "${azurerm_resource_group.rg.location}"
    resource_group_name        = "${azurerm_resource_group.rg.name}"
    app_service_plan_id        = "${azurerm_app_service_plan.plan.id}"
    storage_connection_string  = "${azurerm_storage_account.sa-function.primary_connection_string}"
    version                    = "~2"

    site_config {
      always_on         = true
      linux_fx_version  = "DOCKER|julioback/cosmos_functions:latest"
    }
}

# COSMOS

resource "azurerm_cosmosdb_account" "db_acc" {
  name                = "tfex-cosmos-db-${random_integer.ri.result}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  enable_automatic_failover = false
  enable_free_tier = true

  capabilities {
    name = "EnableAggregationPipeline"
  }

  capabilities {
    name = "mongoEnableDocLevelTTL"
  }

  capabilities {
    name = "MongoDBv3.4"
  }

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }

  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "db_database" {
  name                = "tfex-cosmos-mongo-db"
  resource_group_name = azurerm_cosmosdb_account.db_acc.resource_group_name
  account_name        = azurerm_cosmosdb_account.db_acc.name
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "db_container" {
  name                  = "ToDoList"
  resource_group_name   = azurerm_cosmosdb_account.db_acc.resource_group_name
  account_name          = azurerm_cosmosdb_account.db_acc.name
  database_name         = azurerm_cosmosdb_sql_database.db_database.name
  partition_key_path    = "/category"
  partition_key_version = 1
  throughput            = 400

}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.db_acc.endpoint
}