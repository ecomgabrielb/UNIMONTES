# Bastion Module

## Purpose

Provides a public bastion host for SSH access to private APP_Layer instances. The module creates:

- A TLS key pair (RSA 4096-bit)
- An AWS key pair registered from the generated public key
- The private key stored securely in SSM Parameter Store (SecureString)
- A bastion EC2 instance in the public ALB_Layer subnet with a public IP

## How to Connect

1. Retrieve the private key from SSM Parameter Store:
   ```bash
   aws ssm get-parameter --name "/<project_name>/bastion-private-key" --with-decryption --query "Parameter.Value" --output text > bastion-key.pem
   chmod 400 bastion-key.pem
   ```

2. SSH to the bastion:
   ```bash
   ssh -i bastion-key.pem ec2-user@<BASTION_PUBLIC_IP>
   ```

3. From the bastion, SSH to an APP instance (the same key pair is used):
   ```bash
   ssh -i /tmp/key.pem ec2-user@<APP_INSTANCE_PRIVATE_IP>
   ```
   
   Or copy the key to the bastion first, then connect to app instances.

## Input Variables

| Name | Type | Description |
|------|------|-------------|
| `alb_subnet_ids` | `list(string)` | Public subnet IDs for bastion placement |
| `bastion_sg_id` | `string` | Security group ID for the bastion host |
| `instance_type` | `string` | EC2 instance type (default: t3.micro) |
| `project_name` | `string` | Project name prefix |

## Output Values

| Name | Description |
|------|-------------|
| `bastion_public_ip` | Public IP of the bastion host |
| `bastion_instance_id` | Instance ID of the bastion host |
| `key_pair_name` | Name of the SSH key pair |
| `ssm_parameter_name` | SSM Parameter Store path for the private key |
