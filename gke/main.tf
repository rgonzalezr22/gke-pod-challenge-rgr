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

module "gke_cluster" {
  source                    = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gke-cluster"
  project_id                = var.globals.project_id
  name                      = "${var.globals.prefix}-gke-cluster"
  location                  = var.cluster.location
  vpc_config                = {
    network                   = var.network.vpc.self_link
    subnetwork                = var.network.vpc.subnet_self_links["us-central1/gke-subnet1"]
    secondary_range_names   = {
      pods      = "pods"
      services  = "services"
    }
    master_authorized_ranges = {
    internal-vms = var.network.admin_ranges[0]
  }
  master_ipv4_cidr_block  = "172.16.0.0/28" # var.network.vpc.subnet_secondary_ranges["us-central1/gke-uc1"].services
  }
  max_pods_per_node = 32
  private_cluster_config = {
    enable_private_nodes    = true
    enable_private_endpoint = true    
    master_global_access    = false
  }
  #Enable cluster dns
  #dns_config = {
  #  cluster_dns        = "CLOUD_DNS"
  #  cluster_dns_scope  = "CLUSTER_SCOPE"
  #  cluster_dns_domain = null
  #}
  labels = {
    environment = var.globals.env
  }
  node_locations = var.cluster.nodepool_location
}

module "cluster_nodepool_1" {
  source               = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gke-nodepool"
  project_id           = var.globals.project_id
  cluster_name         = module.gke_cluster.name
  location             = var.cluster.location
  name                 = "${var.globals.prefix}-nodepool"
  service_account = {
    email = "gkergr-qa-github-impersonate@sandbox-rgr.iam.gserviceaccount.com"
  }
}

module "gke_nodepools_sa" {
  source      = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account"
  project_id  = var.globals.project_id
  name        = "gke-nodepools-sa"
  description = ""
  prefix      = var.globals.prefix
  # allow SA used by CI/CD workflow to impersonate this SA
  iam               = {"roles/iam.serviceAccountUser" = ["serviceAccount:gkergr-qa-github-impersonate@sandbox-rgr.iam.gserviceaccount.com"]}
  #iam_storage_roles = {}
  iam_project_roles = {
    (var.globals.project_id) = [
      "roles/artifactregistry.reader",
      "roles/logging.logWriter",
      "roles/compute.instanceAdmin.v1",
      "roles/container.admin",
      "roles/storage.admin",
      "roles/logging.admin",
      "roles/iam.serviceAccountUser",
      "roles/iam.serviceAccountKeyAdmin",
      "roles/iap.tunnelResourceAccessor"
    ]
  }
  }


module "bastion-vm" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/compute-vm"
  project_id = var.globals.project_id
  zone       = var.cluster.nodepool_location[0]
  name       = "gke-bastion"
  network_interfaces = [{
    network    = var.network.vpc.self_link
    subnetwork = var.network.vpc.subnet_self_links["us-central1/gke-subnet1"]
    nat        = false
    addresses  = null
  }]
  service_account        = "gkergr-qa-github-impersonate@sandbox-rgr.iam.gserviceaccount.com"
  instance_type          = var.bastion.instance_type
  service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  tags                   = ["ssh"]
}



# Service account for bastions
module "gke_bastion_sa" {
  source      = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account"
  project_id  = var.globals.project_id
  name        = "gke-bastion-sa"
  description = ""
  prefix      = var.globals.prefix
  # allow SA used by CI/CD workflow to impersonate this SA
  iam               = {"roles/iam.serviceAccountUser" = ["serviceAccount:gkergr-qa-github-impersonate@sandbox-rgr.iam.gserviceaccount.com"]}
  #iam_storage_roles = {}
  iam_project_roles = {
    (var.globals.project_id) = [
      "roles/compute.instanceAdmin.v1",
      "roles/container.admin",
      "roles/storage.admin",
      "roles/logging.admin",
      "roles/iam.serviceAccountUser",
      "roles/iam.serviceAccountKeyAdmin",
      "roles/iap.tunnelResourceAccessor"
    ]
  }
}

#Spinaker stuffs
module "gke_spinaker_sa" {
  source      = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account"
  project_id  = var.globals.project_id
  name        = "gke-spinaker-sa"
  description = ""
  prefix      = var.globals.prefix
  # allow SA used by CI/CD workflow to impersonate this SA
  iam               = {"roles/iam.serviceAccountUser" = ["serviceAccount:gkergr-qa-github-impersonate@sandbox-rgr.iam.gserviceaccount.com"]}
  #iam_storage_roles = {}
  iam_project_roles = {
    (var.globals.project_id) = [
      "roles/compute.instanceAdmin.v1",
      "roles/container.admin",
      "roles/storage.admin",
      "roles/logging.admin",
      "roles/iam.serviceAccountUser",
      "roles/iam.serviceAccountKeyAdmin",
      "roles/iap.tunnelResourceAccessor"
    ]
  }
}

module "docker_artifact_registry" {
  source     = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/artifact-registry"
  project_id = var.globals.project_id
  location   = "us-central1"
  format     = "DOCKER"
  id         = "docker"
  iam = {
    #"roles/artifactregistry.admin" = ["group:cicd@example.com"]
  }
}
# tftest modules=1 resources=2