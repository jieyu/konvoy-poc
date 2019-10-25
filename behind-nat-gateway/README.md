# Konvoy Behind a NAT Gateway

This is a proof of concept (POC) to demonstrate that one can install Konvoy in a DMZ behind a NAT gateway.

## Summary

The main idea is to perform Konvoy install from a publicly accessible node (e.g., in AWS), namely the bootstrap node.
For the Konvoy installer on the bootstrap node to reach the nodes in the DMZ behind a NAT gateway, we can setup [reverse SSH tunnel][reverse-ssh-tunnel] from those nodes to the bootstrap node.
This can be achieved easily using an open source software called [Teleport][teleport].

Once SSH tunnels are setup, Konvoy installer should just work because under the hood, it uses Ansible to install Kubernetes.
And the only thing Ansible requires is to be able to SSH to the target nodes.

To demonstrate the feasibility of this approach, we setup a simulation environment to simulate the network topology.

### Simulation environment

Docker on MacOS naturally simulates the network topology mentioned above.
A Docker container launched on MacOS will be able to access the internet and the MacOS host network using a special DNS [host.docker.internal][docker-host-internal].
However, processes running on the MacOS host are not able to access those containers directly.

Therefore, in this POC, we will use Docker containers to simulate hosts in a DMZ behind a NAT gateway, and use the MacOS host to simulate the bootstrap node.

## Steps

### Prerequisite

This POC assume you have a MacOS running with latest Docker Desktop for Mac installed.

Please also install the following on your laptop:
* [Teleport][teleport-install].
* [Terraform][terraform-install] 0.12 (or newer).

### Build Docker containers

```bash
make docker-build
```

This would build all Docker images required by this POC.

### Start nodes

This is to simulate hosts behind a NAT gateway in a DMZ.
We would launch two Docker containers to simulate two nodes, one for control plane and one for worker.

```bash
make start-all
```

Each Docker container runs `systemd` inside the Docker container, and launches a [Teleport node][teleport-node] service.
The configuration of the Teleport node service can be found [here](teleport-node.yaml).
The systemd unit file for the Teleport node service can be found [here](teleport.service).

Note that the teleport configuration for each node is the same.
There is no need for node specific settings.
As a result, you can easily bake this into your ISO image for the hosts in the DMZ (or cloud-init like scripts).

### Start Teleport server

The above command will also start the Teleport server on the MacOS host.

This simulates the bootstrap node.
This would start the Teleport server which runs both the Teleport [auth][teleport-auth] and Teleport [proxy][teleport-proxy] services.
The configuration of the Teleport server can be found [here](teleport-server.yaml).

Once this server is started, the nodes above will connect to the server automatically.

### List registered nodes

```bash
make list-nodes
```

After around 10 seconds, you should be able to use [Teleport Admin CLI][teleport-tctl] to list the connected nodes.

The name of each node is configured to be the same as the container name.
In a production environment, it can be the hostnames (internal) of your nodes.

### Add a user

```bash
make add-user
```

The above command would add the current user to Teleport, and map that user to `root` account on each node.
The command will pop up a local URL, allowing you to set the initial password for the user.
Once the password is configured, you should be able to see the Teleport WebUI.

Through the WebUI, you should be able to connect to each node using a web shell.

### Login using CLI

You can also choose to login using CLI.
Simply run the following command and type your password configured above.

```bash
make login
```

### Using tsh to connect to the nodes

Now, you should be able to login to the node using the following command.
`tsh` is a secure shell program from Teleport.

```bash
tsh ssh root@worker
```

### Using OpenSSH client to connect to the nodes

You can also using regular `ssh` to login to the nodes.

```bash
eval `ssh-agent`
ssh-add -D
make login
ssh -o StrictHostKeyChecking=no -o ProxyCommand="ssh -o StrictHostKeyChecking=no -p 3023 %r@localhost -s proxy:%h:%p" root@worker
```

### Konvoy preflight check

At this point, Ansible should work already.
You can validate this by running the Konvoy preflight check.

Note that you need to use the master build of Konvoy which include some fix to make this work.
https://github.com/mesosphere/konvoy/pull/904

```bash
konvoy check preflight
```

### Setting up proxy for API server and ops portal access

Teleport supports SOCKS5 proxy through the websocket tunnel.
You just need to run the following command.

```bash
tsh ssh -N --proxy=localhost -D 0.0.0.0:1080 root@control-plane
```

Note: there is an upstream bug fix patch for Teleport that is needed.
We'll work with upstream to get that patch merged as soon as possible.
https://github.com/gravitational/teleport/pull/3110

After than, you can configure the `HTTPS_PROXY` for your command line
and for your browser.

```bash
export HTTPS_PROXY=socks5://127.0.0.1:1080
```

### Deploy Kubernetes and core Addons

Run the following commands to deploy Kubernetes and core Addons:

```bash
konvoy up
```

Once the above commands finish, Kubernetes is installed.

```bash
kubectl get nodes
```

### Clean up

```bash
make clean
```

This would stop all Docker containers and the associated artifacts used by this POC.

[reverse-ssh-tunnel]: https://unix.stackexchange.com/questions/46235/how-does-reverse-ssh-tunneling-work
[teleport]: https://github.com/gravitational/teleport
[docker-host-internal]: https://docs.docker.com/docker-for-mac/networking/
[teleport-node]: https://gravitational.com/teleport/docs/architecture/
[teleport-auth]: https://gravitational.com/teleport/docs/architecture/
[teleport-proxy]: https://gravitational.com/teleport/docs/architecture/
[teleport-install]: https://gravitational.com/teleport/docs/quickstart/#installing-and-starting
[teleport-tctl]: https://gravitational.com/teleport/docs/admin-guide/
[terraform-install]: https://learn.hashicorp.com/terraform/getting-started/install.html
