#!/bin/sh
set -e

#
# Migrate Exoscale Terraform state
#

# Floating IPs
terraform state mv module.cluster.exoscale_ipaddress.api module.cluster.module.lb.exoscale_ipaddress.api
terraform state mv module.cluster.exoscale_ipaddress.ingress module.cluster.module.lb.exoscale_ipaddress.ingress
# DNS records
terraform state mv module.cluster.exoscale_domain_record.api module.cluster.module.lb.exoscale_domain_record.api
terraform state mv module.cluster.exoscale_domain_record.ingress module.cluster.module.lb.exoscale_domain_record.ingress
terraform state mv module.cluster.exoscale_domain_record.lb module.cluster.module.lb.exoscale_domain_record.lb
# Security group
terraform state mv module.cluster.exoscale_security_group.load_balancers module.cluster.module.lb.exoscale_security_group.load_balancers
terraform state mv module.cluster.exoscale_security_group_rules.load_balancers module.cluster.module.lb.exoscale_security_group_rules.load_balancers
# LBs
terraform state mv module.cluster.exoscale_affinity.lb module.cluster.module.lb.exoscale_affinity.lb
terraform state mv module.cluster.random_id.lb module.cluster.module.lb.random_id.lb
terraform state mv module.cluster.exoscale_compute.lb module.cluster.module.lb.exoscale_compute.lb
terraform state mv module.cluster.null_resource.register_lb module.cluster.module.lb.null_resource.register_lb
terraform state mv module.cluster.exoscale_nic.lb module.cluster.module.lb.exoscale_nic.lb
# Hieradata config
terraform state mv module.cluster.data.local_file.hieradata_mr_url 'module.cluster.module.lb.module.hiera[0].data.local_file.hieradata_mr_url[0]'
terraform state mv 'module.cluster.gitfile_checkout.appuio_hieradata[0]' 'module.cluster.module.lb.module.hiera[0].gitfile_checkout.appuio_hieradata'
terraform state mv 'module.cluster.local_file.lb_hieradata[0]' 'module.cluster.module.lb.module.hiera[0].local_file.lb_hieradata'
# private network
terraform state mv module.cluster.exoscale_network.clusternet 'module.cluster.module.lb.exoscale_network.lbnet[0]'
