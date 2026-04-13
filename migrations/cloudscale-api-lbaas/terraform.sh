export COMMODORE_API_URL="${INPUT_commodore_api_url}"

export CLOUDSCALE_API_TOKEN="${INPUT_cloudscale_token}"
export TF_VAR_lb_cloudscale_api_secret="${INPUT_cloudscale_token_floaty}"
export GIT_AUTHOR_NAME="$(git config --global user.name)"
export GIT_AUTHOR_EMAIL="$(git config --global user.email)"
export HIERADATA_REPO_TOKEN="${INPUT_gitlab_api_token}"

cat <<EOF > ./terraform.env
CLOUDSCALE_API_TOKEN
TF_VAR_lb_cloudscale_api_secret
GIT_AUTHOR_NAME
GIT_AUTHOR_EMAIL
HIERADATA_REPO_TOKEN
EOF

tf_image=$(\
yq eval ".parameters.openshift4_terraform.images.terraform.image" \
dependencies/openshift4-terraform/class/defaults.yml)
tf_tag=$(\
yq eval ".parameters.openshift4_terraform.images.terraform.tag" \
dependencies/openshift4-terraform/class/defaults.yml)

echo "Using Terraform image: ${tf_image}:${tf_tag}"

base_dir=$(pwd)
terraform() {
  touch .terraformrc
  docker run --rm -e REAL_UID="$(id -u)" -e TF_CLI_CONFIG_FILE=/tf/.terraformrc --env-file "${base_dir}/terraform.env" -w /tf -v "$(pwd):/tf" --ulimit memlock=-1 "${tf_image}:${tf_tag}" /tf/terraform.sh "${@}"
}

gitlab_repository_url=$(curl -sH "Authorization: Bearer $(commodore fetch-token)" ${INPUT_commodore_api_url}/clusters/${INPUT_commodore_cluster_id} | jq -r '.gitRepo.url' | sed 's|ssh://||; s|/|:|')
gitlab_repository_name=${gitlab_repository_url##*/}
gitlab_catalog_project_id=$(curl -sH "Authorization: Bearer ${INPUT_gitlab_api_token}" "https://git.vshn.net/api/v4/projects?simple=true&search=${gitlab_repository_name/.git}" | jq -r ".[] | select(.ssh_url_to_repo == \"${gitlab_repository_url}\") | .id")
gitlab_state_url="https://git.vshn.net/api/v4/projects/${gitlab_catalog_project_id}/terraform/state/cluster"
