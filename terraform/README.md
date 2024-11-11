# Terraform 

This folder contains all scripts and a single Terraform configuration file (`provision.tf`) to create resources on AWS.

By default, all EC2 instances will be created on `us-east-2` using ami-id `ami-00eb69d236edcfaf8` (Ubuntu 22.04 for AMD64).
It is possible to automate the code not to rely on a hardcoded ami-id, please send a patch - this will definitely ease switching to different AWS regions as needed.

Either way, if you decide to provision under a different region, remember to update the ami-id by checking under https://cloud-images.ubuntu.com/locator/ec2/

# Instructions

1. `terraform init`
2. `terraform apply`
3. If all went well (AWS did not screamed on your face complaining it is out of resources), then:
  - SSH private key will be named `tablets_demo.pem` in your cwd. 
  - To list all states:

```shell
% terraform state list
aws_instance.loader_node[0]
aws_instance.loader_node[1]
aws_instance.loader_node[2]
aws_instance.scylladb_node[0]
aws_instance.scylladb_node[1]
aws_instance.scylladb_node[2]
aws_instance.scylladb_node[3]
aws_instance.scylladb_node[4]
aws_instance.scylladb_node[5]
```

  - To retrieve the public IP address of the Monitoring/Web app:

```shell
% terraform state show 'aws_instance.loader_node[0]' | grep public_ip
    associate_public_ip_address          = true
    public_ip                            = "<IP WILL BE HERE>"
```

  - To SSH:

```shell
ssh -i tablets_demo.pem ubuntu@<PUBLIC_IP>
```

  - Monitoring IP: `http://${aws_instance.loader_node[0].public_ip}:3000`
  - Web App IP: `http://${aws_instance.loader_node[0].public_ip}:5000`

  - To restart/troubleshoot/whatever the Web App (on `loader_node[0]`):

```shell
$ sudo systemctl restart webapp
$ sudo journalctl -u webapp -f
$ ls /app
```

# Structure

- **ScyllaDB Private IPs**: 172.31.0.10[1-6]
- **Loader Private IPs**: 172.31.0.20[1-3] 
- **Monitoring and Web App PRIVATE IP**: 172.31.0.201

# Known Issues

1. Everytime the webapp is restarted it re-ingests data. Patches are welcome to run ingestion only once.
2. A race-condition exists when cloud-init finishes before Terraform gets a chance to copy the private key over. This should rarely (if ever) happen. Patches welcome.
3. Probably more, but I got tired of thinking much.
