/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 ###

locals {
  private_network_name = "${local.prefix}-vpc"
  private_ip_name      = "${local.prefix}-private-ip"
  prefix       = var.globals.prefix
  is_mysql     = can(regex("^MYSQL", var.database_version))
  has_replicas = try(length(var.replicas) > 0, false)
  is_regional  = var.availability_type == "REGIONAL" ? true : false

  // Enable backup if the user asks for it or if the user is deploying
  // MySQL in HA configuration (regional or with specified replicas)
  enable_backup = var.backup_configuration.enabled || (local.is_mysql && local.has_replicas) || (local.is_mysql && local.is_regional)

  users = {
    for user, password in coalesce(var.users, {}) :
    (user) => (
      local.is_mysql
      ? {
        name     = split("@", user)[0]
        host     = try(split("@", user)[1], null)
        password = try(random_password.passwords[user].result, password)
      }
      : {
        name     = user
        host     = null
        password = try(random_password.passwords[user].result, password)
      }
    )
  }
 project_services = [
    "cloudresourcemanager.googleapis.com",
    "iap.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "dns.googleapis.com"
  ]
}
##Impersonation
#Service Account for Cloud SQL
module "cloudsql_sa" {
  source      = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account"
  project_id  = var.globals.project_id
  name        = "cloudsql-sa"
  description = "Cloud SQL Service Account"
  prefix      = var.globals.prefix
  # allow SA used by CI/CD workflow to impersonate this SA
  iam               = {"roles/iam.serviceAccountUser" = ["serviceAccount:rgrgke-dev-github-impersonate@sandbox-rgr.iam.gserviceaccount.com"]}
  #iam_storage_roles = {"roles/iam.serviceAccountUser" =  ["serviceAccount:rgrgke-dev-github-impersonate@sandbox-rgr.iam.gserviceaccount.com"]}
  iam_project_roles = {
    (var.globals.project_id) = [
      "roles/cloudsql.admin",
      "roles/cloudsql.client",
      "roles/compute.networkAdmin",
      "roles/compute.instanceAdmin.v1",
      "roles/container.admin",
      "roles/storage.admin",
      "roles/logging.admin",
      "roles/iam.serviceAccountUser",
      "roles/iam.serviceAccountKeyAdmin",
      "roles/iam.serviceAccountTokenCreator",
      "roles/compute.networkUser",
      "roles/iap.tunnelResourceAccessor",
      "roles/cloudbuild.builds.editor",
      "roles/cloudsql.instanceUser"
    ]
  }
  }
## Enable services
resource "google_project_service" "project" {
  for_each                   = toset(local.project_services)
  project                    = var.project_id
  service                    = each.key
  disable_dependent_services = true
}


# Reserve global internal address range for the peering
resource "google_compute_global_address" "private_ip_address" {
  provider      = google-beta
  name          = local.private_ip_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = local.private_network_name
}

# Establish VPC network peering connection using the reserved address range
resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google-beta
  network                 = local.private_network_name
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database_instance" "primary" {
  provider            = google-beta
  project             = var.project_id
  name                = var.name
  region              = var.region
  database_version    = var.database_version
  encryption_key_name = var.encryption_key_name
  root_password       = var.root_password

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = var.tier
    disk_autoresize   = var.disk_size == null
    disk_size         = var.disk_size
    disk_type         = var.disk_type
    availability_type = var.availability_type
    user_labels       = var.labels

    ip_configuration {
      ipv4_enabled    = var.ipv4_enabled
      private_network = "projects/${var.project_id}/global/networks/${local.private_network_name}"
      dynamic "authorized_networks" {
        for_each = var.authorized_networks != null ? var.authorized_networks : {}
        iterator = network
        content {
          name  = network.key
          value = network.value
        }
      }
    }

    dynamic "backup_configuration" {
      for_each = local.enable_backup ? { 1 = 1 } : {}
      content {
        enabled = true

        // enable binary log if the user asks for it or we have replicas (default in regional),
        // but only for MySQL
        binary_log_enabled = (
          local.is_mysql
          ? var.backup_configuration.binary_log_enabled || local.has_replicas || local.is_regional
          : null
        )
        start_time                     = var.backup_configuration.start_time
        location                       = var.backup_configuration.location
        transaction_log_retention_days = var.backup_configuration.log_retention_days
        backup_retention_settings {
          retained_backups = var.backup_configuration.retention_count
          retention_unit   = "COUNT"
        }
      }
    }

    dynamic "database_flags" {
      for_each = var.flags != null ? var.flags : {}
      iterator = flag
      content {
        name  = flag.key
        value = flag.value
      }
    }
  }
  deletion_protection = var.deletion_protection
}

resource "google_sql_database_instance" "replicas" {
  provider             = google-beta
  for_each             = local.has_replicas ? var.replicas : {}
  project              = var.project_id
  name                 = var.name
  region               = each.value.region
  database_version     = var.database_version
  encryption_key_name  = each.value.encryption_key_name
  master_instance_name = google_sql_database_instance.primary.name

  settings {
    tier            = var.tier
    disk_autoresize = var.disk_size == null
    disk_size       = var.disk_size
    disk_type       = var.disk_type
    availability_type = var.availability_type
    user_labels = var.labels

    ip_configuration {
      ipv4_enabled    = var.ipv4_enabled
      private_network = "projects/${var.project_id}/global/networks/${local.private_network_name}"
      dynamic "authorized_networks" {
        for_each = var.authorized_networks != null ? var.authorized_networks : {}
        iterator = network
        content {
          name  = network.key
          value = network.value
        }
      }
    }

    dynamic "database_flags" {
      for_each = var.flags != null ? var.flags : {}
      iterator = flag
      content {
        name  = flag.key
        value = flag.value
      }
    }
  }
  deletion_protection = var.deletion_protection
}

resource "google_sql_database" "databases" {
  for_each = var.databases != null ? toset(var.databases) : toset([])
  project  = var.project_id
  instance = google_sql_database_instance.primary.name
  name     = each.key
}

resource "random_password" "passwords" {
  for_each = toset([
    for user, password in coalesce(var.users, {}) :
    user
    if password == null
  ])
  length  = 16
  special = true
}

resource "google_sql_user" "users" {
  for_each = local.users
  project  = var.project_id
  instance = google_sql_database_instance.primary.name
  name     = each.value.name
  host     = each.value.host
  password = each.value.password
}
