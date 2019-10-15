resource "docker_container" "worker" {
  count    = 1
  name     = "worker"
  hostname = "worker"

  image      = "${docker_image.node_image.latest}"
  privileged = true

  mounts {
    type      = "bind"
    source    = "/lib/modules"
    target    = "/lib/modules"
    read_only = true
  }

  mounts {
    type      = "bind"
    source    = "/etc/resolv.conf"
    target    = "/etc/resolv.conf"
    read_only = true
  }
  
  mounts {
    type      = "tmpfs"
    target    = "/run"
    read_only = false
  }

  volumes {
    volume_name    = "worker_containerd_volume"
    container_path = "/var/lib/containerd"
    read_only      = false
  }
}

resource "docker_container" "control_plane" {
  count    = 1
  name     = "control-plane"
  hostname = "control-plane"

  image      = "${docker_image.node_image.latest}"
  privileged = true

  mounts {
    type      = "bind"
    source    = "/lib/modules"
    target    = "/lib/modules"
    read_only = true
  }

  mounts {
    type      = "bind"
    source    = "/etc/resolv.conf"
    target    = "/etc/resolv.conf"
    read_only = true
  }
  
  mounts {
    type      = "tmpfs"
    target    = "/run"
    read_only = false
  }

  volumes {
    volume_name    = "control_plane_containerd_volume"
    container_path = "/var/lib/containerd"
    read_only      = false
  }
}

resource "docker_container" "teleport" {
  count    = 1
  name     = "teleport"
  hostname = "teleport"

  image      = "${docker_image.teleport_image.latest}"

  ports {
    internal = 3023
    external = 3023
  }

  ports {
    internal = 3024
    external = 3024
  }

  ports {
    internal = 3025
    external = 3025
  }

  ports {
    internal = 3080
    external = 3080
  }
}

resource "docker_image" "node_image" {
  name         = "node:latest"
  keep_locally = true
}

resource "docker_image" "teleport_image" {
  name         = "teleport:latest"
  keep_locally = true
}

resource "docker_volume" "worker_containerd_volume" {
  count  = 1
  name   = "worker-containerd-volume"
  driver = "local"
}

resource "docker_volume" "control_plane_containerd_volume" {
  count  = 1
  name   = "control-plane-containerd-volume"
  driver = "local"
}

resource "local_file" "ansible_inventory" {
  filename = "inventory.yaml"

  provisioner "local-exec" {
    command = "chmod 644 inventory.yaml"
  }

  content = <<EOF
all:
  vars:
    version: "v1beta1"
    order: sorted
    control_plane_endpoint: "${docker_container.control_plane.0.ip_address}:6443"
    ansible_user: root
    wait_for_connection: ssh
    ssh_common_args: "-o StrictHostKeyChecking=no -o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -p 3023 %r@localhost -s proxy:%h:%p\""
    ansible_ssh_transfer_method: scp

control-plane:
  hosts:
    ${docker_container.control_plane.0.ip_address}:
      ansible_host: control-plane

node:
  hosts:
    ${docker_container.worker.0.ip_address}:
      ansible_host: worker
      node_pool: worker

bastion:
EOF
}
