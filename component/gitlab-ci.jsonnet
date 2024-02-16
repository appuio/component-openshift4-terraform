local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_terraform;
local git = params.gitlab_ci.git;
local version = import 'version.libsonnet';

local cloud_specific_variables = {
  cloudscale: {
    default: {
      CLOUDSCALE_API_TOKEN: '${CLOUDSCALE_TOKEN_RO}',
      TF_VAR_lb_cloudscale_api_secret: '${CLOUDSCALE_FLOATY_SECRET}',
      TF_VAR_control_vshn_net_token: '${CONTROL_VSHN_NET_TOKEN}',
      [if std.objectHas(git, 'username') then 'GIT_AUTHOR_NAME']: git.username,
      [if std.objectHas(git, 'email') then 'GIT_AUTHOR_EMAIL']: git.email,
    },
    apply: {
      CLOUDSCALE_API_TOKEN: '${CLOUDSCALE_TOKEN_RW}',
    },
  },
  exoscale: {
    default: {
      EXOSCALE_API_KEY: '${EXOSCALE_API_KEY_RO}',
      EXOSCALE_API_SECRET: '${EXOSCALE_API_SECRET_RO}',
      TF_VAR_control_vshn_net_token: '${CONTROL_VSHN_NET_TOKEN}',
      [if std.objectHas(git, 'username') then 'GIT_AUTHOR_NAME']: git.username,
      [if std.objectHas(git, 'email') then 'GIT_AUTHOR_EMAIL']: git.email,
    } + if version.tfModuleMajorVersion > 3 && version.tfModuleMajorVersion < 5 then {
      TF_VAR_lb_exoscale_api_key: '${EXOSCALE_FLOATY_KEY}',
      TF_VAR_lb_exoscale_api_secret: '${EXOSCALE_FLOATY_SECRET}',
    } else {},
    apply: {
      EXOSCALE_API_KEY: '${EXOSCALE_API_KEY_RW}',
      EXOSCALE_API_SECRET: '${EXOSCALE_API_SECRET_RW}',
    },
  },
};

local GitLabCI() = {
  stages: [
    'validate',
    'plan',
    'deploy',
  ],
  default: {
    image: params.images.terraform.image + ':' + params.images.terraform.tag,
    tags: params.gitlab_ci.tags,
    before_script: [
      'cd ${TF_ROOT}',
      'gitlab-terraform init',
    ],
    cache: {
      key: '${CI_PIPELINE_ID}',
      paths: [
        '${TF_ROOT}/.terraform/modules',
        '${TF_ROOT}/.terraform/plugins',
      ],
    },
  },
  variables: {
    TF_ROOT: '${CI_PROJECT_DIR}/manifests/openshift4-terraform',
    TF_ADDRESS: '${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/cluster',
  } + cloud_specific_variables[params.provider].default,
  validate: {
    stage: 'validate',
    script: [
      'gitlab-terraform validate',
    ],
  },
  format: {
    stage: 'validate',
    before_script: [],
    cache: {},
    script: [
      'terraform fmt -recursive -diff -check ${TF_ROOT}',
    ],
  },
  plan: {
    stage: 'plan',
    script: [
      'gitlab-terraform plan',
      'gitlab-terraform plan-json',
    ],
    artifacts: {
      name: 'plan',
      paths: [
        '${TF_ROOT}/plan.cache',
      ],
      expire_in: '1 week',
      reports: {
        terraform: '${TF_ROOT}/plan.json',
      },
    },
  },
  apply: {
    stage: 'deploy',
    environment: {
      name: 'production',
    },
    variables: cloud_specific_variables[params.provider].apply,
    script: [
      'apk add --no-cache curl',
      'export GIT_ASKPASS=${TF_ROOT}/git-askpass.sh',
      'gitlab-terraform apply',
    ],
    dependencies: [
      'plan',
    ],
    when: 'manual',
    only: [
      'master',
    ],
  },
};

{
  'gitlab-ci': GitLabCI(),
}
