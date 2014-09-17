# Fluentd Docker Metrics Input Plugin

This is a [Fluentd](http://www.fluentd.org) plugin to collect Docker metrics periodically.

## How it works

It's assumed to run on the host server. It periodically runs `docker ps --no-trunc -q` to get a list of running Docker container IDs, and it looks at `/sys/fs/cgroups/<metric_type>/docker/<container_id>/` for relevant stats, `/var/lib/docker/execdriver/native` to get docker interface name and `/sys/class/net` to read network statistics. You can say this is an implementation of the metric collection strategy outlined in [this blog post](http://blog.docker.com/2013/10/gathering-lxc-docker-containers-metrics/).

## How to build (with Docker)

To build the gem with Docker:
```
docker build .
docker run -v **/host_directory**:/gem **<image id>**
```
You can find the gem in your **/host_directory**

## Example config

```
<source>
  type docker_metrics
  stats_interval 1m
</source>
```

## Parameters

* **stats_interval**: how often to poll Docker containers for stats. The default is every minute.
* **cgroup_path**: The path to cgroups pseudofiles. The default is `/sys/fs/cgroup`.
* **tag_prefix**: The tag prefix. The default value is "docker"
* **docker_socket**: docker socker path. Default: `unix:///var/run/docker.sock`
* **docker_network_path**: path to network informations. Default: `/sys/class/net`
* **docker_infos_path**: path to json files `container.json` and `state.json`. Default: `/var/lib/docker/execdriver/native`


## Example output

```
20140909T123247+0000    docker.memory.stat      {"key":"total_unevictable","value":0,"type":"gauge","td_agent_hostname":"3f8f46d50a24","source":"3f8f46d50a24be540f0b7d8c725a037a0f56d9e89b89ad54f70a1cd400142cb0"}
20140909T123247+0000    docker.cpuacct.stat     {"key":"user","value":1094,"type":"gauge","td_agent_hostname":"3f8f46d50a24","source":"3f8f46d50a24be540f0b7d8c725a037a0f56d9e89b89ad54f70a1cd400142cb0"}
20140909T123247+0000    docker.cpuacct.stat     {"key":"system","value":302,"type":"gauge","td_agent_hostname":"3f8f46d50a24","source":"3f8f46d50a24be540f0b7d8c725a037a0f56d9e89b89ad54f70a1cd400142cb0"}
20140909T123247+0000    docker.network.stat     {"key":"rx_bytes","value":648,"type":"counter","if_name":"veth8590","td_agent_hostname":"3f8f46d50a24","source":"3f8f46d50a24be540f0b7d8c725a037a0f56d9e89b89ad54f70a1cd400142cb0"}
20140909T123247+0000    docker.network.stat     {"key":"tx_bytes","value":0,"type":"counter","if_name":"veth8590","td_agent_hostname":"3f8f46d50a24","source":"3f8f46d50a24be540f0b7d8c725a037a0f56d9e89b89ad54f70a1cd400142cb0"}
20140909T123247+0000    docker.network.stat     {"key":"tx_packets","value":0,"type":"counter","if_name":"veth8590","td_agent_hostname":"3f8f46d50a24","source":"3f8f46d50a24be540f0b7d8c725a037a0f56d9e89b89ad54f70a1cd400142cb0"}
20140909T123247+0000    docker.network.stat     {"key":"rx_packets","value":8,"type":"counter","if_name":"veth8590","td_agent_hostname":"3f8f46d50a24","source":"3f8f46d50a24be540f0b7d8c725a037a0f56d9e89b89ad54f70a1cd400142cb0"}
20140909T123247+0000    docker.network.stat     {"key":"tx_errors","value":0,"type":"counter","if_name":"veth8590","td_agent_hostname":"3f8f46d50a24","source":"3f8f46d50a24be540f0b7d8c725a037a0f56d9e89b89ad54f70a1cd400142cb0"}
20140909T123247+0000    docker.network.stat     {"key":"rx_errors","value":0,"type":"counter","if_name":"veth8590","td_agent_hostname":"3f8f46d50a24","source":"3f8f46d50a24be540f0b7d8c725a037a0f56d9e89b89ad54f70a1cd400142cb0"}
```

In particular, each event is a key-value pair of individual metrics.
