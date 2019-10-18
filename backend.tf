terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "thoughtquery"

    workspaces {
      name = "vault_cluster"
    }
  }
}
