local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_terraform;

// Cutoff major versions for Terraform older than 1.3.0
// With Terraform < 1.3.0, we only support major module versions < the values
// here, while with Terraform >= 1.3.0 we only support major module versions
// >= the values here.
local module_cutoff_major_versions = {
  cloudscale: 4,
  exoscale: 3,
};

// This evaluates to a boolean indicating whether the configured Terraform
// version is >= 1.3.0.
local tf_1_3 =
  local terraformVersion = std.split(params.images.terraform.tag, '.');
  if std.length(terraformVersion) < 3 then
    error 'Unable to parse Terraform image tag'
  else
    local parsedTfVersion = std.map(std.parseInt, terraformVersion);
    if parsedTfVersion[0] > 1 then
      error "Component doesn't support Terraform 2.x"
    else
      if parsedTfVersion[0] == 1 && parsedTfVersion[1] >= 3 then
        true
      else
        false;

// This evaluates to a boolean indicating whether the configured combination
// of Terraform version, module version, and cloud provider is supported.
local tfModuleMajorVersion =
  local verParts = std.split(params.version, '.');
  if std.length(verParts) < 3 then
    // probably not a tagged version, just return the minimum supported
    // version for Terraform 1.3
    module_cutoff_major_versions[params.provider]
  else
    std.parseInt(std.lstripChars(verParts[0], 'v'));

local supported_module_version =
  local paramsMajor = tfModuleMajorVersion;
  if tf_1_3 then
    // for Terraform >= 1.3.0 we need at least the cutoff module major
    // version
    paramsMajor >= module_cutoff_major_versions[params.provider]
  else
    // for Terraform < 1.3.0 we need a module major version < the cutoff
    // version
    paramsMajor < module_cutoff_major_versions[params.provider];

local versionCheck(terraform_config) =
  if !supported_module_version then
    // Generate a compilation error if the combination of Terraform version,
    // module version and cloud provider is not supported.
    local verLimit =
      if tf_1_3 then
        module_cutoff_major_versions[params.provider]
      else
        module_cutoff_major_versions[params.provider] - 1;
    error 'The %s supported Terraform module version for provider "%s" is `v%d.0.0` for Terraform version `%s`' % [
      if tf_1_3 then 'minimum' else 'maximum',
      params.provider,
      verLimit,
      params.images.terraform.tag,
    ]
  else
    // output
    terraform_config;

{
  tfModuleMajorVersion: tfModuleMajorVersion,
  check: versionCheck,
}
