#!/bin/sh
# Intended to run as root, this script ensures that the non-privileged user
# that we want to run as in the end can use git-https and curl.
# TODO: build custom Terraform CI image based on GitLab's image.
adduser -D -s /bin/sh -u "${REAL_UID}" -h /tf terraform
apk add --no-cache curl
export GIT_ASKPASS=/tf/git-askpass.sh
# Note: busybox `su` can't directly execute a binary, so we use the secondary
# script which only does `exec terraform`.
su -p terraform /tf/tf.sh -- "$@"
