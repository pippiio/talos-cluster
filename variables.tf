locals {
  hostname_pattern = "^[a-z0-9][a-z0-9-]*(\\.[a-z0-9][a-z0-9-]*)*$"
}

variable "cluster" {
  description = <<EOF
    Talos cluster configurastion:
      hostname: The hostname of the talos kubernetes cluster
      name: The name of the talos kubernetes cluster
      talos_version:
      nodes: A map
        key: The nodes hostname
        value:
          type: Type of the node. Valid values includes [controlplane,worker]
          disk: The Talos install disk.
          interfaces:
            key: interface id
            value:
              dhcp: true to enable dhcp
              ipv4: ipv4 address
      default_routes: A map of network routes
        key: network CIDR
        value: Gateway IP
  EOF

  type = object({
    hostname      = string
    name          = string
    talos_version = string

    nodes = map(object({
      type = string
      disk = string

      interfaces = map(object({
        dhcp   = bool
        ipv4   = optional(string)
        routes = optional(map(string))
      }))
    }))

    default_routes = optional(map(string), {})
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
    error_message = "Invalid cluster.talos_version."
    condition     = can(regex("^v\\d+\\.\\d+\\.\\d+$", var.cluster.talos_version))
  }

  # validation {
  #   error_message = "One or more invalid node ipv4."
  #   condition = alltrue([
  #     for _ in values(var.cluster.nodes) :
  #     can(regex("^(25[0-5]|2[0-4]\\d|1\\d{2}|[1-9]?\\d)(\\.(25[0-5]|2[0-4]\\d|1\\d{2}|[1-9]?\\d)){3}$", _.disk))
  #   ])
  # }

  validation {
    error_message = "One or more invalid node hostname."
    condition = alltrue([
      for _ in keys(var.cluster.nodes) :
      can(regex(local.hostname_pattern, _))
    ])
  }

  validation {
    error_message = "One or more invalid node type. Valid values includes [controlplane,worker]."
    condition = alltrue([
      for _ in values(var.cluster.nodes) : contains(["controlplane", "worker"], _.type)
    ])
  }

  validation {
    error_message = "One or more invalid node disk. Use valid device path, eg. /dev/sda"
    condition = alltrue([
      for _ in values(var.cluster.nodes) :
      can(regex("^\\/dev\\/((?:sd|hd|vd)[a-z][0-9]*|nvme[0-9]+n[0-9]+p?[0-9]*)$", _.disk))
    ])
  }
}
