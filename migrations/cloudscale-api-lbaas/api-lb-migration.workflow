Given I have all prerequisites installed
And a lieutenant cluster ID
And a personal VSHN GitLab access token
Then I compile the cluster catalog
And I login to the target cluster
And I fetch the cluster cloudscale token from Vault
And I retrieve the LB FQDNs from the Terraform state
Then I set a downtime for the LBs in Icinga2
And I set a silence on the cluster
And I disable Puppet on the LBs
And I enable the API LB creation in Terraform
And I compile the cluster catalog
Then I move the API VIP in the Terraform state
And I remove the API VIP from the Floaty and Keepalived config on the LBs
Then I run Terraform to provision the API and API-INT LB instances
Then I attach the API floating IP to the API LB instance
And I enable Puppet on the LBs
And I expire the Alertmanager silence
And finally I remove the downtime in Icinga2
