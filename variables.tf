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
            value: mounitpoint
          interfaces:
            key: interface id
            value:
              dhcp: true to enable dhcp
              ipv4: ipv4 address
              routes: A map of routes structured <network-cidr>=<gateway-ip>
      time_servers: A set of NTP time server hostnames used for nodes
      default_routes: A map of default routes structured <network-cidr>=<gateway-ip>
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
      interfaces = map(object({
        dhcp        = bool
        ipv4        = optional(string)
        cidr_prefix = optional(string, "24")
        routes      = optional(map(string))
        mtu         = optional(number)
        bond = optional(object({
          mode             = optional(string, "active+backup")
          miimon           = optional(number, 100)
          lacp_rate        = optional(string)
          xmit_hash_policy = optional(string)
          interfaces       = list(string)
        }))
      }))
      temporary_ip = optional(string)
    }))

    encryption = optional(object({
      enabled    = bool
      node_id    = optional(bool, false)
      passphrase = optional(string)
      }), {
      enabled = true
      node_id = true
    })
    image                 = optional(string)
    nameservers           = optional(list(string), [])
    time_servers          = optional(set(string), [])
    default_routes        = optional(map(string), {})
    kubeadm_cert_lifetime = optional(string, "12h0m0s")
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
        interface.ipv4 == null || can(regex(local.ipv4_pattern, interface.ipv4))
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
      var.cluster.encryption.enabled == false
      ||
      (
        # exactly one of these must be set
        (
          (var.cluster.encryption.node_id ? 1 : 0) +
          (coalesce(var.cluster.encryption.passphrase != null && var.cluster.encryption.passphrase != "", false) ? 1 : 0)
        ) == 1
      )
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
