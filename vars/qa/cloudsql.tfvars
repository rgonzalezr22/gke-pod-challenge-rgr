project_id = "sandbox-rgr"
region = "us-central1"
database_version =	"POSTGRES_14"	
name =	"db-rgr"	
tier = "db-f1-micro"
authorized_networks = {pods = "192.168.0.0/17"}
availability_type = "ZONAL"
disk_type = "PD_SSD"
ipv4_enabled = false
#labels = {app = "db-dev-gke"}
deletion_protection = false
