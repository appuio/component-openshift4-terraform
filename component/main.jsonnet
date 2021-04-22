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
};

// output
terraform_configs[params.provider]
