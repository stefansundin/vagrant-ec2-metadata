require "vagrant"
require "socket"

module VagrantEc2Metadata
  class Config < Vagrant.plugin("2", :config)
    attr_accessor :profile
    attr_accessor :role_arn
  end

  class Provisioner < Vagrant.plugin("2", :provisioner)
    def provision
      host_ip = Socket.ip_address_list.detect(&:ipv4_private?).ip_address
      port = 5000

      @machine.env.ui.info("Setting up an iptables rule for the EC2 metadata server.")
      @machine.action(:ssh_run,
                      ssh_run_command: "sudo iptables -t nat -A OUTPUT -p tcp -d 169.254.169.254 -j DNAT --to-destination #{host_ip}:#{port} || echo 'Error setting up iptables rule.'",
                      ssh_opts: {extra_args: []})
    end
  end

  class Plugin < Vagrant.plugin("2")
    name "ec2-metadata"
    description "Easily provide vagrant machines with AWS credentials by faking an EC2 metadata server."

    config("ec2-metadata", :provisioner) do
      Config
    end

    provisioner("ec2-metadata") do
      Provisioner
    end
  end
end
