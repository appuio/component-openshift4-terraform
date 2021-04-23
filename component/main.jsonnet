// main template for openshift4-terraform
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_terraform;

local cluster_dns = {
  cloudscale: '${module.cluster.dns_entries}',
  exoscale: '${module.cluster.ns_records}',
};

local terraform_config = {
  'main.tf': {
    module: {
      cluster: params.terraform_variables,
    },
  },
  'backend.tf': {
    terraform: {
      backend: {
        http: {},
      },
    },
  },
  'output.tf': {
    output: {
      cluster_dns: {
        value: cluster_dns[params.provider],
      },
    },
  },
  'variables.tf': {
    variable: {
      ignition_bootstrap: {
        default: '',
      },
    },
  },
};

if std.member(std.objectFields(cluster_dns), params.provider) == false then
  error 'openshift4_terraform.provider "' + params.provider + '" is not supported by this component. Currently supported are ' + std.objectFields(cluster_dns) + '. If you think this is a bug in the component, file an issue on https://github.com/appuio/component-openshift4-terraform.'
else
  // output
  terraform_config
