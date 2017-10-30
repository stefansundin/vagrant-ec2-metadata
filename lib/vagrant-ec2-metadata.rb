require "vagrant"
require "socket"

module VagrantEc2Metadata
  class Config < Vagrant.plugin("2", :config)
    attr_accessor :profile
    attr_accessor :role_arn
    attr_accessor :port

    def initialize
      @profile = UNSET_VALUE
    end

    def finalize!
      @profile = "default" if @profile == UNSET_VALUE
    end

    def self.port(machine)
      return machine.config.ec2_metadata.port if machine.config.ec2_metadata.port
      ec2_metadata_file = machine.data_dir.join("ec2-metadata-port")
      if ec2_metadata_file.file?
        port = ec2_metadata_file.read.chomp.to_i
      else
        # Generate a random port number that hopefully won't interfere with anything
        port = 12000+Random.rand(1000)
        ec2_metadata_file.open("w+") do |f|
          f.write(port.to_s)
        end
      end
      return port
    end
  end

  class Provisioner < Vagrant.plugin("2", :provisioner)
    def provision
      host_ip = Socket.ip_address_list.detect(&:ipv4_private?).ip_address
      port = Config.port(@machine)

      # If you are having troubles with the iptables rule, you can flush it with:
      # sudo iptables -t nat -F

      @machine.ui.info("Setting up an iptables rule for the EC2 metadata server (port #{port}).")
      @machine.action(:ssh_run,
                      ssh_run_command: "sudo iptables -t nat -A OUTPUT -p tcp -d 169.254.169.254 -j DNAT --to-destination #{host_ip}:#{port} || echo 'Error setting up iptables rule.'",
                      ssh_opts: {extra_args: []})
    end
  end

  class Command < Vagrant.plugin("2", :command)
    def self.synopsis
      "starts the EC2 metadata server"
    end

    def execute
      @argv = @env.active_machines.map(&:first).map(&:to_s) if @argv.empty?
      require_relative "vagrant-ec2-metadata/server"
      threads = []
      with_target_vms(@argv) do |machine|
        port = Config.port(machine)
        config = machine.config.ec2_metadata
        machine.ui.info("Using profile #{machine.config.ec2_metadata.profile}#{config.role_arn ? " with role #{config.role_arn}":""} (port #{port})")
        thread = Thread.new do
          server = VagrantEc2Metadata::Server.new(config, port, @env)
          server.start
        end
        threads.push(thread)
      end
      threads.map(&:join)
    end
  end

  class Plugin < Vagrant.plugin("2")
    name "ec2-metadata"
    description "Easily provide vagrant machines with AWS credentials by faking an EC2 metadata server."

    config("ec2_metadata") do
      Config
    end

    provisioner("ec2-metadata") do
      Provisioner
    end

    command("ec2-metadata") do
      Command
    end
  end
end
