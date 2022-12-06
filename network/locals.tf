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

locals {
  prefix = var.globals.prefix
  tfvars_network = {
    network = {
      vpc = {
         name = module.vpc.name,
         self_link = module.vpc.self_link
         subnet_ips = module.vpc.subnet_ips
         subnet_regions= module.vpc.subnet_regions
         subnet_secondary_ranges = module.vpc.subnet_secondary_ranges
         subnet_self_links = module.vpc.subnet_self_links
      }
      region = var.region
      admin_ranges = var.admin_ranges
    }
  }
}