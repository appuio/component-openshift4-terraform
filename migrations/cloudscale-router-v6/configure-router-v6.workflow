Given I have all prerequisites installed
And a lieutenant cluster ID
And a personal VSHN GitLab access token
Then I compile the cluster catalog
And I login to the target cluster
And I fetch the cluster cloudscale token from Vault
Then I run Terraform to provision the ingress router IPv6 floating IP
And I configure the ingress router IPv6 floating IP in the tenant repo
And finally I wait for the ingress router IPv6 floating IP to be attached to the cloudscale LB
