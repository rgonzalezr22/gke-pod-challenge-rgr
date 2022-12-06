region = "us-central1"

subnets = [
    {
      ip_cidr_range = "10.0.0.0/16"
      name          = "gke-subnet1"
      region        = "us-central1"
      secondary_ip_ranges = {
        pods     = "192.168.0.0/17"
        services = "192.168.128.0/17"
      }
    }
]

admin_ranges = ["10.0.0.0/8"]