#!/bin/sh
set -e

terraform state mv module.cluster.cloudscale_floating_ip.api_vip module.cluster.module.lb.cloudscale_floating_ip.api_vip
terraform state mv module.cluster.cloudscale_floating_ip.router_vip module.cluster.module.lb.cloudscale_floating_ip.router_vip
terraform state mv module.cluster.cloudscale_floating_ip.nat_vip module.cluster.module.lb.cloudscale_floating_ip.nat_vip

terraform state mv module.cluster.cloudscale_server.lb module.cluster.module.lb.cloudscale_server.lb
terraform state mv module.cluster.cloudscale_server_group.lb module.cluster.module.lb.cloudscale_server_group.lb
terraform state mv module.cluster.random_id.lb module.cluster.module.lb.random_id.lb
terraform state mv module.cluster.null_resource.register_lb module.cluster.module.lb.null_resource.register_lb

terraform state mv module.cluster.data.local_file.hieradata_mr_url 'module.cluster.module.lb.module.hiera.data.local_file.hieradata_mr_url[0]'
terraform state mv 'module.cluster.gitfile_checkout.appuio_hieradata[0]' module.cluster.module.lb.module.hiera.gitfile_checkout.appuio_hieradata
terraform state mv 'module.cluster.local_file.lb_hieradata[0]' module.cluster.module.lb.module.hiera.local_file.lb_hieradata

terraform state mv module.cluster.cloudscale_network.privnet 'module.cluster.cloudscale_network.privnet[0]'
terraform state mv module.cluster.cloudscale_subnet.privnet_subnet 'module.cluster.cloudscale_subnet.privnet_subnet[0]'
