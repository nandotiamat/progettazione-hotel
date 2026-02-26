# Basic Claude Opus 4.6 output overview

## Before terraform apply

1. Octavia doesn't explicitly define the used provider (with the `loadbalancer_provider` field), so it defaults to `amphora`. However, we described in the initial prompt that it should use `ovn` as provider. It has several consequences, like:
   * Useless HAProxy images built
   * LB listener and health monitors relies on HTTP, but it should be TCP (OVN L4, AMPHORA L7)
2. It uses as standard flavor for the compute VMs `m1.small`, which uses 20GB disk per VM, however in the initial prompt it's stated that the target environment has 75GB disk. The model proposed an infrastructure that has 4 VMs with the `m1.small` flavor, of course at least 1 VM will not boot up (`NoValidHostFound` raised).
3. The dotenv file path creation must be fixed by adding as prefix ${path.module} (it tried to write in /config, it gave an absolute path).
4. It is clear that it did NOT create any SSH keypairs, how am i supposed to log in the VMs? Especially for debugging purposed, since we are in a constrained development environment.

## After terraform apply

1. The VMs uses the default `cirros` image. However, this is a basic, small image (15 MB), which is capable of almost nothing compared to a ubuntu cloud image, for example. Opus 4.6 defined an `user_data` field for each compute instance that lists some bash scripts that should setup the machine for its purpose. However, there are two major problems:
   * The model never really noticed the fact that he was using the `cirros` image, that is not capable to run a lot of the scripts (it doesn't even have apt-get, for instance)
   * Furthermore, the VMs have a fixed IP in a **PRIVATE SUBNET**, which is **NOT** connected to the **PUBLIC NETWORK** through the router created by the script. This means that the VMs in that private network are, of course, incapable to reach the internet, so **incapable of downloading the dependencies**.

After downloading ubuntu jammy cloud img, loading that to glance, and change the image from cirros to that, it appears in the logs of the VM (postgres-db VM) that the `user_data` was executed but the VMs couldn't reach the Internet (Ign: warnings).

It is pretty much an **undebuggable** environment, due to the fact that i can't get inside the VMs if not through Horizon dashboard (with the cirros, with the ubuntu cloudimg you have to do a trick in order to access them, because by default only by SSH you can log into them).