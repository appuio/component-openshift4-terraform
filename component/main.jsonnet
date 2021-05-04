// main template for openshift4-terraform
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_terraform;

local cluster_dns = {
  cloudscale: '${module.cluster.dns_entries}',
  exoscale: '${module.cluster.ns_records}',
};

local input_vars = {
  cloudscale: {
    ignition_bootstrap: {
      default: '',
    },
  },
  exoscale: {
    lb_exoscale_api_key: {
      default: '',
    },
    lb_exoscale_api_secret: {
      default: '',
    },
  },
};

// We want to pass through any provider-specific input variables (see above)
// to the cluster module.
// This bit of code requires that the input variables are named identically
// to the cluster module input variables.
local provider_module_vars = {
  [var]: '${var.%s}' % var
  for var in std.objectFields(input_vars[params.provider])
};

local terraform_config =
  {
    'main.tf': {
      module: {
        cluster: (
          params.terraform_variables +
          provider_module_vars
        ),
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
  } +
  {
    ['variable_%s.tf' % var]: {
      variable: {
        [var]: input_vars[params.provider][var],
      },
    }
    for var in std.objectFields(input_vars[params.provider])
  };

if std.member(std.objectFields(cluster_dns), params.provider) == false then
  error 'openshift4_terraform.provider "' + params.provider + '" is not supported by this component. Currently supported are ' + std.objectFields(cluster_dns) + '. If you think this is a bug in the component, file an issue on https://github.com/appuio/component-openshift4-terraform.'
else
  // output
  terraform_config
