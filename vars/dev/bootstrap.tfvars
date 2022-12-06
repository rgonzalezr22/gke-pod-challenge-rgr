prefix = "rgrsite"
project_id = "sandbox-rgr"
env = "dev"
cicd_repository = "rgonzalezr22/gkechallenge-rgr"

federated_identity_providers = {
  github-fip = {
    attribute_condition = "attribute.repository_owner==\"rgonzalezr22\""
    issuer              = "github"
    custom_settings     = null
  }
}