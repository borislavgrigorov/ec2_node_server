# Setup
## Setup environment variables
Create env.bat/.sh file and fill in all the variables
```
@set AWS_ACCESS_KEY_ID=
@set AWS_SECRET_ACCESS_KEY=
@set AWS_DEFAULT_REGION=us-west-2
@set TF_VAR_aws_private_key_file_path=.\\aws_key.pem
@set TF_VAR_ec2_user="ec2-user"
```

Create aws_key.pem file in the top level directory of the project and add your private key that you will be using to connect to the ec2 instance with.
Make sure your key is added to your key pairs in the ec2 instances page of your AWS account.

## Running terraform
Install terraform

Run:
```
env.bat
terraform init
terraform plan
terraform apply
```

## Running the node server
Install docker
Start docker vm
```
docker-machine start
docker-machine env
```

### Build and run the docker container
```
docker build -t ec2server .
docker run -d -p 8080:8080 --name=ec2server ec2server
```
The docker machine runs on 192.168.99.100
so you can hit the server like this
```
curl 192.168.99.100:8080
```
