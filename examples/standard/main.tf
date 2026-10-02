provider "talos" {}

terraform {
  required_version = ">= 1.14"

  required_providers {

    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

    flux = {
      source  = "fluxcd/flux"
      version = "1.8.6"
    }
  }
}

module "cluster" {
  source = "../../"

  cluster = {
    # hostname = "192.168.88.11"
    hostname            = "192.168.88.200"
    virtual_ip          = "192.168.88.200"
    name                = "talos-cluster"
    perform_healthcheck = true

    default_routes = {
      "0.0.0.0/0" = "192.168.88.1"
    }

    nodes = {
      c1-cp1 = {
        type         = "controlplane"
        install_disk = "/dev/sda"
        interfaces = {
          end0 = {
            ipv4_address_cidr = "192.168.88.11/24" # ønsket fremtidig ip
          }
        }
        # temporary_ip = "192.168.88.251" # nuværende ip fra DHCP
      }

      c1-cp2 = {
        type         = "controlplane"
        install_disk = "/dev/sda"
        interfaces = {
          end0 = {
            ipv4_address_cidr = "192.168.88.12/24"
          }
        }
        # temporary_ip = "192.168.88.253"
      }

      c1-cp3 = {
        type         = "controlplane"
        install_disk = "/dev/sda"
        interfaces = {
          end0 = {
            ipv4_address_cidr = "192.168.88.13/24"
          }
        }
        # temporary_ip = "192.168.88.254"
      }

      c1-w1 = {
        type         = "worker"
        install_disk = "/dev/sda"
        interfaces = {
          end0 = {
            ipv4_address_cidr = "192.168.88.14/24"
          }
        }
        # temporary_ip = "192.168.88.250"
      }

      c1-w2 = {
        type         = "worker"
        install_disk = "/dev/sda"
        interfaces = {
          end0 = {
            ipv4_address_cidr = "192.168.88.15/24"
          }
        }
        # temporary_ip = "192.168.88.252"
      }
    }
  }

  configfile = {
    talosconfig = {
      save_to_disk = true
    }

    kubeconfig = {
      save_to_disk = true
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.cluster.kubeconfig.host
    cluster_ca_certificate = module.cluster.kubeconfig.cluster_ca_certificate
    client_certificate     = module.cluster.kubeconfig.client_certificate
    client_key             = module.cluster.kubeconfig.client_key
  }
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  namespace  = "kube-system"
  version    = "1.19.3"

  wait    = false
  timeout = 600

  set = [
    {
      name  = "ipam.mode"
      value = "kubernetes"
    },
    {
      name  = "kubeProxyReplacement"
      value = "true"
    },
    {
      name  = "k8sServiceHost"
      value = "localhost"
    },
    {
      name  = "k8sServicePort"
      value = "7445"
    },
    {
      name  = "cgroup.autoMount.enabled"
      value = "false"
    },
    {
      name  = "cgroup.hostRoot"
      value = "/sys/fs/cgroup"
    },
    {
      name  = "securityContext.capabilities.ciliumAgent"
      value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
    },
    {
      name  = "securityContext.capabilities.cleanCiliumState"
      value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
    }
  ]

  depends_on = [
    module.cluster
  ]
}

# provider "flux" {
#   kubernetes = {
#     host                   = kind_cluster.this.endpoint
#     client_certificate     = kind_cluster.this.client_certificate
#     client_key             = kind_cluster.this.client_key
#     cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
#   }
#   git = {
#     url = "ssh://git@github.com/${var.github_org}/${var.github_repository}.git"
#     ssh = {
#       username    = "git"
#       private_key = tls_private_key.flux.private_key_pem
#     }
#   }
# }

provider "flux" {
  kubernetes = {
    host                   = module.cluster.kubeconfig.host
    client_certificate     = module.cluster.kubeconfig.client_certificate
    client_key             = module.cluster.kubeconfig.client_key
    cluster_ca_certificate = module.cluster.kubeconfig.cluster_ca_certificate
  }

  git = {
    url = "../"
    # url = "git@github.com:GIT-USER/REPO-NAME.git"
    ssh = {
      username    = "git"
      private_key = file("~/.ssh/id_annemonster")
    }
  }
}

# senere 
# resource "kubernetes_secret" "githubapp-secret-flux" {
#   metadata {
#     name      = "githubapp-secret"
#     namespace = "flux-system"
#   }

# resource "flux_bootstrap_git" "this" {
#   depends_on = [github_repository_deploy_key.this]

#   embedded_manifests = true
#   path               = "clusters/my-cluster"
# }

resource "flux_bootstrap_git" "this" {
  path = "clusters/talos-cluster"

  depends_on = [module.cluster]
}



