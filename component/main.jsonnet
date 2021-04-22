// main template for openshift4-terraform
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_terraform;

local terraform_configs = {
  cloudscale: {
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
          value: '${module.cluster.dns_entries}',
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
  },
  exoscale: {
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
          value: '${module.cluster.ns_records}',
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
  },
};

if params.provider != 'cloudscale' && params.provider != 'exoscale' then
  error 'openshift4_terraform.provider "' + params.provider + '" is unsupported. Choose one of ["cloudscale", "exoscale"]'
else
  // output
  terraform_configs[params.provider]
