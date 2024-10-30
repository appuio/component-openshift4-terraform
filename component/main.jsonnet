// main template for openshift4-terraform
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_terraform;

local version = import 'version.libsonnet';

local cluster_dns = {
  cloudscale: '${module.cluster.dns_entries}',
  exoscale: '${module.cluster.ns_records}',
};

// Configure Terraform input variables which are provided at runtime
local input_vars = {
  cloudscale: {
    ignition_bootstrap: {
      default: '',
    },
    lb_cloudscale_api_secret: {
      default: '',
    },
    control_vshn_net_token: {
      default: '',
    },
  },
  exoscale: {
    control_vshn_net_token: {
      default: '',
    },
  } + if version.tfModuleMajorVersion > 3 && version.tfModuleMajorVersion < 5 then {
    lb_exoscale_api_key: {
      default: '',
    },
    lb_exoscale_api_secret: {
      default: '',
    },
  } else {},
};

// Configure Terraform outputs
local common_outputs = {
  cluster_dns: cluster_dns[params.provider],
  hieradata_mr: '${module.cluster.hieradata_mr}',
};
local outputs = {
  cloudscale: common_outputs {
    'master-machines_yml': '${module.cluster.master-machines_yml}',
    'master-machineset_yml': '${module.cluster.master-machineset_yml}',
    'infra-machines_yml': '${module.cluster.infra-machines_yml}',
    'infra-machineset_yml': '${module.cluster.infra-machineset_yml}',
    'worker-machines_yml': '${module.cluster.worker-machines_yml}',
    'worker-machineset_yml': '${module.cluster.worker-machineset_yml}',
    'additional-worker-machines_yml': '${module.cluster.additional-worker-machines_yml}',
    'additional-worker-machinesets_yml': '${module.cluster.additional-worker-machinesets_yml}',
  },
  exoscale: common_outputs,
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
        cluster: std.prune(
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
    local mergedOutputs = params.additional_outputs + outputs[params.provider],
    'outputs.tf': {
      output: {
        [out]: {
          value: mergedOutputs[out],
        }
        for out in std.objectFields(mergedOutputs)
      },
    },
    'variables.tf': {
      variable: {
        [var]: input_vars[params.provider][var]
        for var in std.objectFields(input_vars[params.provider])
      },
    },
  };

if std.member(std.objectFields(cluster_dns), params.provider) == false then
  error 'openshift4_terraform.provider "' + params.provider + '" is not supported by this component. Currently supported are ' + std.objectFields(cluster_dns) + '. If you think this is a bug in the component, file an issue on https://github.com/appuio/component-openshift4-terraform.'
else
  // Check whether combination of Terraform version and module version is
  // valid.
  version.check(terraform_config)
