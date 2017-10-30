# vagrant-ec2-metadata

The best way to pass AWS credentials to your Vagrant machines.

## Install

For now, the plugin only supports Linux guests that have iptables installed.

```
$ vagrant plugin install vagrant-ec2-metadata
```

Then add this to your Vagrantfile:

```
Vagrant.configure("2") do |config|
  [...]

  # Put these lines above other provisioners that need to use the credentials
  config.ec2_metadata.profile = "default"
  config.ec2_metadata.role_arn = "arn:aws:iam::123456789012:role/ReadOnlyRole"
  config.vm.provision "ec2-metadata", run: "always"

  [...]
end
```

See [the examples](examples) for more information.

## What

By using this plugin, you can pass through credentials to your VMs without
having to copy or hardcode credentials inside of your VM.

It works by faking an [EC2 metadata server](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html),
which is the same way an EC2 server with an assigned role retrieves its credentials.

You must run the webserver that serves these requests when you want the VMs to
be able to access their credentials. Start it by running:

```
$ vagrant ec2-metadata
```

## Why?

Other ways of configuring AWS credentials for your VMs are:

- Hardcoding AWS key
  - **Why it's bad:**
    - you run a high risk of accidentally committing the key to a public source code repository.
    - everyone on your team are using the same key, making auditing harder.
    - it's hard to rotate the key.

- Using a synced folder like the following:
  ```
  config.vm.synced_folder "#{ENV["HOME"]}/.aws", "/home/ubuntu/.aws/"
  ```
  - While much better than the above alternative, this is still not perfect.
  - **Why it's bad:**
    - you have to link the folder to every user inside of the VM.
    - the VM gets access to all of your credentials, when it probably only needs a subset.
    - the VM can modify your `.aws` files.

This plugin provides the following benefits:
- the VM never gets access to a permanent key, the credentials expire after one hour.
- you can use a role, allowing you to easily give the VM the same permissions that your production servers are running, without any changes to the application code.
