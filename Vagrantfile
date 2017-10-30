# You can set this to a region that's geographically closer to you
ENV["AWS_DEFAULT_REGION"] = "us-west-2"

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.hostname = "ec2-metadata-example"

  # Put this provisioner above other provisioners that need to use the credentials
  config.vm.provision "ec2-metadata", profile: "default", run: "always"

  # This tests that it works
  config.vm.provision "shell", inline: <<SCRIPT
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3-pip
pip3 install -U awscli
SCRIPT
  config.vm.provision "shell", inline: "aws sts get-caller-identity || exit 0", run: "always"
end
