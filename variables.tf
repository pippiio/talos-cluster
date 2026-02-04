locals {
  hostname_pattern = "^[a-z0-9][a-z0-9-]*(\\.[a-z0-9][a-z0-9-]*)*$"
  ipv4_pattern     = "^(25[0-5]|2[0-4]\\d|1?\\d?\\d)(\\.(25[0-5]|2[0-4]\\d|1?\\d?\\d)){3}$"
  cidr_pattern     = "^(25[0-5]|2[0-4]\\d|1?\\d?\\d)(\\.(25[0-5]|2[0-4]\\d|1?\\d?\\d)){3}\\/(3[0-2]|[12]?\\d)$"
  device_pattern   = "^/dev/(disk/by-id/[^/]+|(?:sd|hd|vd)[a-z][0-9]*|nvme[0-9]+n[0-9]+p?[0-9]*)$"
}

variable "cluster" {
  description = <<EOF
    Talos cluster configurastion:
      hostname: The hostname of the talos kubernetes cluster
      name: The name of the talos kubernetes cluster
      disk_selector: CEL expression to filter disks in output
      nodes: A map
        key: The nodes hostname
        value:
          type: Type of the node. Valid values includes [controlplane,worker]
          install_disk: The Talos install disk.
          disks: Node disk configuration:
            key: device
            value: mountpoint
          image: Custom image for installation (overrides cluster image)
          hostname: Optional hostname (defualts to node key)
          labels: List of node labels
          taints: List of node taints
            key: Taint key
            value: Taint value
            effect Taint effect
          interfaces:
            key: interface id
            value:
              ipv4: ipv4 address, must be a valid cidr ipv4 pattern (e.x. 10.0.0.10/24)
              routes: A map of routes structured <network-cidr>=<gateway-ip>
              mtu: Mtu of network
              trusted: Shall the interface subnet be trusted and added to the certificates SAN
              bond: Bond settings for bonding NICs
                mode: Mode of the bond (defaults to active-backup)
                miimon: Miimon of the bond (defaults to 100)
                lacp_rate: Optional lacp rate of the bond
                xmit_hash_policy: Optional xmit hash policy for the bond
                interfaces: List of interfaces to bond together
          temporary_ip: A temporary ip for installation
      encryption: Encryption options for Talos install disks
        node_id: Use node_id as the encryption key
        passphrase: use passphrase as the encryption key
      virtual_ip: Virtual IP for controlplanes
      image: Custom image for all nodes
      name_servers: A list of the nameservers to use in the cluster
      time_servers: A set of NTP time server hostnames used for nodes
      default_routes: A map of default routes structured <network-cidr>=<gateway-ip>
      schedule_on_controlplanes: Enalbes scheduling on the control plane nodes
      kubeadm_cert_lifetime: Lifetime of the cubeconfig kubeadm certs (defaults to 12 hours)
  EOF

  type = object({
    hostname      = string
    name          = string
    disk_selector = optional(string, "disk.size > 50u * GB && disk.readonly == false")
    nodes = map(object({
      type         = string
      install_disk = string
      disks        = optional(map(string), {})
      image        = optional(string)
      hostname     = optional(string) # defaults to key
      labels       = optional(map(string), {})
      taints = optional(map(object({
        value  = optional(string)
        effect = string
      })), {})
      interfaces = map(object({
        ipv4    = string
        routes  = optional(map(string))
        mtu     = optional(number)
        trusted = optional(bool, true)
        bond = optional(object({
          mode             = optional(string, "active-backup")
          miimon           = optional(number, 100)
          lacp_rate        = optional(string)
          xmit_hash_policy = optional(string)
          interfaces       = list(string)
        }))
      }))
      temporary_ip = optional(string)
    }))

    encryption = optional(object({
      node_id    = optional(bool, false)
      passphrase = optional(string)
      }), {
      node_id = true
    })
    virtual_ip                = optional(string)
    image                     = optional(string)
    name_servers              = optional(list(string), [])
    time_servers              = optional(set(string), [])
    default_routes            = optional(map(string), {})
    schedule_on_controlplanes = optional(bool, false)
    kubeadm_cert_lifetime     = optional(string, "12h0m0s")
  })

  nullable = false

  validation {
    error_message = "Invalid cluster.hostname."
    condition     = can(regex(local.hostname_pattern, var.cluster.hostname))
  }

  validation {
    error_message = "Invalid cluster.name."
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.cluster.name))
  }

  validation {
    error_message = "At least one node w. type controlplane is required."
    condition     = length([for node in var.cluster.nodes : node if node.type == "controlplane"]) > 0
  }

  validation {
    error_message = "One or more invalid cluster.nodes key (hostname)."
    condition = alltrue([
      for _ in keys(var.cluster.nodes) :
      can(regex(local.hostname_pattern, _))
    ])
  }

  validation {
    error_message = "One or more invalid cluster.nodes[].type. Valid values includes [controlplane,worker]."
    condition = alltrue([
      for _ in values(var.cluster.nodes) : contains(["controlplane", "worker"], _.type)
    ])
  }

  validation {
    error_message = "One or more invalid cluster.nodes[].install_disk. Use valid device path, eg. /dev/sda or /dev/disk/by-id/nvme-eui.1234"
    condition = alltrue([
      for _ in values(var.cluster.nodes) :
      can(regex(local.device_pattern, _.install_disk))
    ])
  }

  validation {
    error_message = "One or more invalid cluster.nodes[].disks key. Use valid device path, eg. /dev/sda or /dev/disk/by-id/nvme-eui.1234"
    condition = alltrue(flatten([
      for node in values(var.cluster.nodes) : [
        for device in keys(node.disks) : can(regex(local.device_pattern, device))
    ]]))
  }

  validation {
    error_message = "One or more invalid cluster.nodes[].interface[].ipv4"
    condition = alltrue(flatten([
      for node in values(var.cluster.nodes) : [
        for interface in coalesce(node.interfaces, {}) :
        can(regex(local.cidr_pattern, interface.ipv4))
    ]]))
  }

  validation {
    error_message = "One or more invalid cluster.nodes[].interface[].routes[] key (network cidr)"
    condition = alltrue(flatten([
      for node in values(var.cluster.nodes) : [
        for interface in node.interfaces : [
          for network in keys(coalesce(interface.routes, {})) : can(regex(local.cidr_pattern, network))
    ]]]))
  }

  validation {
    error_message = "One or more invalid cluster.nodes[].interface[].routes[] value (gateway)"
    condition = alltrue(flatten([
      for node in values(var.cluster.nodes) : [
        for interface in node.interfaces : [
          for gateway in values(coalesce(interface.routes, {})) : can(regex(local.ipv4_pattern, gateway))
    ]]]))
  }

  validation {
    error_message = "One or more invalid cluster.default_routes[] key (network cidr)"
    condition = alltrue(flatten([
      for network in keys(var.cluster.default_routes) : can(regex(local.cidr_pattern, network))
    ]))
  }

  validation {
    error_message = "One or more invalid cluster.default_routes[] value (gateway)"
    condition = alltrue(flatten([
      for gateway in values(var.cluster.default_routes) : can(regex(local.ipv4_pattern, gateway))
    ]))
  }

  validation {
    error_message = "When encryption is enabled, exactly one of `node_id = true` or `passphrase` must be set (but not both)."
    condition = (
      ( # exactly one of these must be set
        (var.cluster.encryption.node_id ? 1 : 0) +
        (coalesce(var.cluster.encryption.passphrase != null && var.cluster.encryption.passphrase != "", false) ? 1 : 0)
      ) == 1
    )
  }
}

variable "configfile" {
  description = <<EOF
    Local config file configuration. NB! files contains sensitive certificates:
      talosconfig: Talos config file:
        save_to_disk: True if talosconfig is saved to local file.
        path: File path. Defaults to ~/.talos/config
        owerwrite: True if existing file is owerwritten. False will merge with existing file.
      kubeconfig: Kube config file:
        save_to_disk: True if kubeconfig is saved to local file.
        path: File path. Defaults to ~/.kube/config
        owerwrite: True if existing file is owerwritten. False will merge with existing file.
  EOF
  type = object({
    talosconfig = optional(object({
      save_to_disk = optional(bool, false)
      path         = optional(string, "~/.talos/config")
      owerwrite    = optional(bool, false)
    }), {})
    kubeconfig = optional(object({
      save_to_disk = optional(bool, false)
      path         = optional(string, "~/.kube/config")
      owerwrite    = optional(bool, false)
    }), {})
  })
  nullable = false
  default  = {}
}
