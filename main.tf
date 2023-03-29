/**
 * Copyright 2018 Google LLC
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

locals {
  cluster_type = "simple-regional"
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

module "service_accounts" {
  source        = "terraform-google-modules/service-accounts/google"
  version       = "~> 4.0"
  project_id    = var.project_id
  prefix        = var.cluster_name
  names         = ["k8s"]
  project_roles = ["${var.project_id}=>roles/viewer"]
  display_name  = var.cluster_name
  description   = var.cluster_name
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "25.0.0"

  project_id                  = var.project_id
  name                        = var.cluster_name
  regional                    = true
  region                      = var.region
  network                     = var.network
  subnetwork                  = var.subnetwork
  ip_range_pods               = var.ip_range_pods
  ip_range_services           = var.ip_range_services
  create_service_account      = false
  service_account             = module.service_accounts.email
  enable_cost_allocation      = true
  enable_binary_authorization = var.enable_binary_authorization
  skip_provisioners           = var.skip_provisioners
  cluster_autoscaling = {
    "auto_repair" : true,
    "auto_upgrade" : true,
    "enabled" : true,
    "gpu_resources" : [],
    "max_cpu_cores" : 24,
    "max_memory_gb" : 200,
    "min_cpu_cores" : 12,
    "min_memory_gb" : 12
  }
}

module "gke_auth" {
  depends_on = [
    module.gke
  ]
  source       = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  version      = "24.1.0"
  project_id   = var.project_id
  location     = var.region
  cluster_name = var.cluster_name
}
