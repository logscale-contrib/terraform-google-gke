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

# module "service_accounts" {
#   source        = "terraform-google-modules/service-accounts/google"
#   version       = "~> 4.0"
#   project_id    = var.project_id
#   prefix        = var.cluster_name
#   names         = ["k8s"]
#   project_roles = ["${var.project_id}=>roles/viewer"]
#   display_name  = var.cluster_name
#   description   = var.cluster_name
# }

module "gke" {
  source = "terraform-google-modules/kubernetes-engine/google"

  # version = "25.0.0"
  release_channel = "RAPID"

  project_id             = var.project_id
  name                   = var.cluster_name
  regional               = true
  region                 = var.region
  network                = var.network
  subnetwork             = var.subnetwork
  ip_range_pods          = var.ip_range_pods
  ip_range_services      = var.ip_range_services
  create_service_account = true
  # service_account             = module.service_accounts.email
  enable_cost_allocation      = true
  enable_binary_authorization = var.enable_binary_authorization
  skip_provisioners           = var.skip_provisioners
  cluster_autoscaling = {
    "auto_repair" : true,
    "auto_upgrade" : true,
    "autoscaling_profile" : "BALANCED",
    "enabled" : true,
    "gpu_resources" : [],
    "max_cpu_cores" : 48,
    "max_memory_gb" : 400,
    "min_cpu_cores" : 12,
    "min_memory_gb" : 12
  }

  node_pools = [
    {
      name         = "general"
      machine_type = "e2-medium"
      min_count    = 0
      max_count    = 10
      # service_account = format("%s@%s.iam.gserviceaccount.com", local.cluster_sa_name, var.project_id)
      auto_upgrade = true
      auto_repair  = true
    },
    {
      name         = "compute"
      machine_type = "e2-standard-8"
      min_count    = 0
      max_count    = 5
      # local_ssd_count    = 0
      # disk_size_gb       = 30
      # disk_type          = "pd-standard"
      # accelerator_count  = 1
      # accelerator_type   = "nvidia-tesla-a100"
      # gpu_partition_size = "1g.5gb"
      auto_upgrade = true
      auto_repair  = true
      # service_account = module.service_accounts.email
    }
    # {
    #   name               = "pool-03"
    #   machine_type       = "n1-standard-2"
    #   node_locations     = "${var.region}-b,${var.region}-c"
    #   autoscaling        = false
    #   node_count         = 2
    #   disk_type          = "pd-standard"
    #   auto_upgrade       = true
    #   service_account    = var.compute_engine_service_account
    #   pod_range          = "test"
    #   sandbox_enabled    = true
    #   cpu_manager_policy = "static"
    #   cpu_cfs_quota      = true
    # },
  ]

  # node_pools_metadata = {
  #   pool-01 = {
  #     shutdown-script = "kubectl --kubeconfig=/var/lib/kubelet/kubeconfig drain --force=true --ignore-daemonsets=true --delete-local-data \"$HOSTNAME\""
  #   }
  # }

  node_pools_labels = {
    all = {
      all-pools-example = true
    }
    general = {
      workloadClass = "general"
    }
    compute = {
      workloadClass = "compute"
    }
  }

  # node_pools_taints = {
  #   all = [
  #     {
  #       key    = "all-pools-example"
  #       value  = true
  #       effect = "PREFER_NO_SCHEDULE"
  #     },
  #   ]
  #   pool-01 = [
  #     {
  #       key    = "pool-01-example"
  #       value  = true
  #       effect = "PREFER_NO_SCHEDULE"
  #     },
  #   ]
  # }

  # node_pools_tags = {
  #   all = [
  #     "all-node-example",
  #   ]
  #   pool-01 = [
  #     "pool-01-example",
  #   ]
  # }

  # node_pools_linux_node_configs_sysctls = {
  #   all = {
  #     "net.core.netdev_max_backlog" = "10000"
  #   }
  #   pool-01 = {
  #     "net.core.rmem_max" = "10000"
  #   }
  #   pool-03 = {
  #     "net.core.netdev_max_backlog" = "20000"
  #   }
  # }
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
