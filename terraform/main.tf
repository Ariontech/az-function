resource "azurerm_resource_group" "resource_group" {
  name     = var.azurerm_resource_group
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-airflow"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "airflow-subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/23"]
}

resource "azurerm_log_analytics_workspace" "analytics_workspace" {
  name                = var.azurerm_log_analytics_workspace_name
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "app_environment" {
  name                       = var.azurerm_container_app_environment_name
  location                   = azurerm_resource_group.resource_group.location
  resource_group_name        = azurerm_resource_group.resource_group.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.analytics_workspace.id
  infrastructure_subnet_id   = azurerm_subnet.subnet.id
}


resource "azurerm_redis_cache" "redis" {
  name                = "airflow-redis"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  sku_name            = "Basic"
  capacity            = 1
  family = "C"
  timeouts {
    create = "40m"
    delete = "30m"
  }
}

resource "azurerm_container_app" "postgres_app" {

  name                = "postgres-container-app"
  container_app_environment_id = azurerm_container_app_environment.app_environment.id
  resource_group_name = azurerm_resource_group.resource_group.name
  revision_mode = "Single"

template {
  container {
    name   = "postgres-container"
    image  = "postgres:13.1"
    cpu    = 1
    memory = "2Gi"
      env {
        name = "POSTGRES_USER" 
        value = "airflow"
      }
      env {
        name = "POSTGRES_DB"
        value = "postgres_db"
      }
      env {
        name = "POSTGRES_PASSWORD"
        value = "Passlocal1234"
      }
  }
}
  ingress {
     transport = "tcp"
     allow_insecure_connections = false
     target_port = 5432  
     traffic_weight {
      latest_revision = true
      percentage = 100
     }
     external_enabled = true
   }
}


resource "azurerm_container_app" "webserver" {
  name                         = "airflow-webserver"
  container_app_environment_id = azurerm_container_app_environment.app_environment.id
  resource_group_name          = azurerm_resource_group.resource_group.name
  revision_mode                = "Single"
  template {
    container {
      name   = "webserver-app"
      image  = "apache/airflow:2.5.0-python3.8"
      cpu    = 1
      memory = "2Gi"
      command = ["webserver"]
      
      env {
        name = "AIRFLOW__CORE__EXECUTOR" 
        value = "CeleryExecutor"
      }
      env {
        name = "AIRFLOW__WEBSERVER__RBAC"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__STORE_SERIALIZED_DAGS" 
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__CHECK_SLAS"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__PARALLELISM"
        value = "50"
      }
      env {
        name = "AIRFLOW__CORE__LOAD_EXAMPLES"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__LOAD_DEFAULT_CONNECTIONS"
        value = "False"
      }
      env {
        name = "AIRFLOW__SCHEDULER__SCHEDULER_HEARTBEAT_SEC"
        value = "10"
      }
      env {
        name = "AIRFLOW__CELERY__BROKER_URL"
        value = "redis://:@airflow-redis.redis.cache.windows.net:6379/0"
      }
       env {
        name = "AIRFLOW__CELERY__RESULT_BACKEND"
        value = "db+postgresql://airflow@postgres-container:Passlocal1234@postgres-container:5432/postgres_db"
      }
      env {
        name = "AIRFLOW__CORE__SQL_ALCHEMY_CONN"
        value = "postgresql+psycopg2://airflow@postgres-container:Passlocal1234@postgres-container:5432/postgres_db"
      }
      env {
        name = "AIRFLOW__CORE__FERNET_KEY"
        value = "P_gYHVxUHul5GNhev_Pde-Kr8qvCeurfSCF9OT7cJQM="
      }
    }
  }
  ingress {
     transport = "http"
     allow_insecure_connections = true
     target_port = 8080  
     traffic_weight {
      latest_revision = true
      percentage = 100
     }
     external_enabled = true
   }
   depends_on = [azurerm_container_app.initdb,azurerm_redis_cache.redis,azurerm_container_app.postgres_app]
}


resource "azurerm_container_app" "scheduler" {
  name                         = "airflow-scheduler"
  container_app_environment_id = azurerm_container_app_environment.app_environment.id
  resource_group_name          = azurerm_resource_group.resource_group.name
  revision_mode                = "Single"
  template {
    container {
      name   = "scheduler-app"
      image  = "apache/airflow:2.5.0-python3.8"
      cpu    = 1
      memory = "2Gi"
      command = ["scheduler"]
         env {
        name = "AIRFLOW__CORE__EXECUTOR" 
        value = "CeleryExecutor"
      }
      env {
        name = "AIRFLOW__WEBSERVER__RBAC"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__STORE_SERIALIZED_DAGS" 
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__CHECK_SLAS"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__PARALLELISM"
        value = "50"
      }
      env {
        name = "AIRFLOW__CORE__LOAD_EXAMPLES"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__LOAD_DEFAULT_CONNECTIONS"
        value = "False"
      }
      env {
        name = "AIRFLOW__SCHEDULER__SCHEDULER_HEARTBEAT_SEC"
        value = "10"
      }
      env {
        name = "AIRFLOW__CELERY__BROKER_URL"
        value = "redis://:@airflow-redis.redis.cache.windows.net:6379/0"
      }
       env {
        name = "AIRFLOW__CELERY__RESULT_BACKEND"
        value = "db+postgresql://airflow@postgres-container:Passlocal1234@postgres-container:5432/postgres_db"
      }
      env {
        name = "AIRFLOW__CORE__SQL_ALCHEMY_CONN"
        value = "postgresql+psycopg2://airflow@postgres-container:Passlocal1234@postgres-container:5432/postgres_db"
      }
      env {
        name = "AIRFLOW__CORE__FERNET_KEY"
        value = "P_gYHVxUHul5GNhev_Pde-Kr8qvCeurfSCF9OT7cJQM="
      }
    }
  }
  depends_on = [azurerm_container_app.initdb]
}

resource "azurerm_container_app" "worker_1" {
  name                         = "airflow-worker-1"
  container_app_environment_id = azurerm_container_app_environment.app_environment.id
  resource_group_name          = azurerm_resource_group.resource_group.name
  revision_mode                = "Single"
  template {
    container {
      name   = "worker-1-app"
      image  = "apache/airflow:2.5.0-python3.8"
      cpu    = 1
      memory = "2Gi"
      command = ["celery", "worker", "-H", "worker_1_name"]
         env {
        name = "AIRFLOW__CORE__EXECUTOR" 
        value = "CeleryExecutor"
      }
      env {
        name = "AIRFLOW__WEBSERVER__RBAC"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__STORE_SERIALIZED_DAGS" 
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__CHECK_SLAS"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__PARALLELISM"
        value = "50"
      }
      env {
        name = "AIRFLOW__CORE__LOAD_EXAMPLES"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__LOAD_DEFAULT_CONNECTIONS"
        value = "False"
      }
      env {
        name = "AIRFLOW__SCHEDULER__SCHEDULER_HEARTBEAT_SEC"
        value = "10"
      }
      env {
        name = "AIRFLOW__CELERY__BROKER_URL"
        value = "redis://:@airflow-redis.redis.cache.windows.net:6379/0"
      }
      env {
        name = "AIRFLOW__CELERY__RESULT_BACKEND"
        value = "db+postgresql://airflow@postgres-container:Passlocal1234@postgres-container:5432/postgres_db"
      }
      env {
        name = "AIRFLOW__CORE__SQL_ALCHEMY_CONN"
        value = "postgresql+psycopg2://airflow@postgres-container:Passlocal1234@postgres-container:5432/postgres_db"
      }
      env {
        name = "AIRFLOW__CORE__FERNET_KEY"
        value = "P_gYHVxUHul5GNhev_Pde-Kr8qvCeurfSCF9OT7cJQM="
      }
    }
  }
  depends_on = [azurerm_container_app.scheduler]
}


resource "azurerm_container_app" "initdb" {
  name                         = "airflow-initdb"
  container_app_environment_id = azurerm_container_app_environment.app_environment.id
  resource_group_name          = azurerm_resource_group.resource_group.name
  revision_mode                = "Single"
  template {
    container {
      name   = "initdb-app"
      image  = "apache/airflow:2.5.0-python3.8"
      cpu    = 1
      memory = "2Gi"
      command = ["/bin/bash", "-c", "airflow db init && airflow users create --firstname admin --lastname admin --email admin --password admin --username admin --role Admin"]
         env {
        name = "AIRFLOW__CORE__EXECUTOR" 
        value = "CeleryExecutor"
      }
      env {
        name = "AIRFLOW__WEBSERVER__RBAC"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__STORE_SERIALIZED_DAGS" 
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__CHECK_SLAS"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__PARALLELISM"
        value = "50"
      }
      env {
        name = "AIRFLOW__CORE__LOAD_EXAMPLES"
        value = "False"
      }
      env {
        name = "AIRFLOW__CORE__LOAD_DEFAULT_CONNECTIONS"
        value = "False"
      }
      env {
        name = "AIRFLOW__SCHEDULER__SCHEDULER_HEARTBEAT_SEC"
        value = "10"
      }
      env {
        name = "AIRFLOW__CELERY__BROKER_URL"
        value = "redis://:@airflow-redis.redis.cache.windows.net:6379/0"
      }
      env {
        name = "AIRFLOW__CELERY__RESULT_BACKEND"
        value = "db+postgresql://airflow@postgres-container:Passlocal1234@postgres-container:5432/postgres_db"
      }
      env {
        name = "AIRFLOW__CORE__SQL_ALCHEMY_CONN"
        value = "postgresql+psycopg2://airflow@postgres-container:Passlocal1234@postgres-container:5432/postgres_db"
      }
      env {
        name = "AIRFLOW__CORE__FERNET_KEY"
        value = "P_gYHVxUHul5GNhev_Pde-Kr8qvCeurfSCF9OT7cJQM="
      }
    }
  }
  depends_on = [azurerm_redis_cache.redis,azurerm_container_app.postgres_app]
}

