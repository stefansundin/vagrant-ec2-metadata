require "webrick"
require "aws-sdk-core"
require "socket"

ENV["AWS_DEFAULT_REGION"] ||= "us-west-2"

module VagrantEc2Metadata
  class Server
    def initialize(config, port, options, env)
      @config = config
      @port = port
      @options = options
      @env = env
    end

    def start
      WEBrick::Daemon.start if @options[:daemonize]
      server = WEBrick::HTTPServer.new(Port: @port)

      trap "INT" do
        server.shutdown
      end

      server.mount_proc "/" do |req, res|
        # Only allow requests from IP addresses that we own, which the VM will normally share
        addr = Addrinfo.new(req.peeraddr)
        addr = addr.ipv6_to_ipv4 if addr.ipv6_v4mapped?
        remote_ip = addr.ip_address
        if !Socket.ip_address_list.select { |a| a.ipv4_private? || a.ipv4_loopback? }.map(&:ip_address).include?(remote_ip)
          res.status = 403 # Forbidden
          next
        end

        # This endpoint is all we handle right now
        if !req.path.start_with?("/latest/meta-data/iam/security-credentials")
          res.status = 404
          next
        end

        if req.path == "/latest/meta-data/iam/security-credentials"
          # The Go SDK sends the request here first, then gets redirected to the correct path.. https://github.com/aws/aws-sdk-go/pull/2002
          res.status = 301
          res["Location"] = "/latest/meta-data/iam/security-credentials/"
        elsif req.path == "/latest/meta-data/iam/security-credentials/"
          res.body = "role"
        else
          sts = ::Aws::STS::Client.new(profile: @config.profile)
          if @config.role_arn
            resp = sts.assume_role({
              duration_seconds: 3600,
              role_arn: @config.role_arn,
              role_session_name: "vagrant",
            })
            creds = resp.credentials
          else
            resp = sts.get_session_token({
              duration_seconds: 3600,
            })
            creds = resp.credentials
          end

          res.body = <<EOF
{
  "Code" : "Success",
  "LastUpdated" : "#{Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")}",
  "Type" : "AWS-HMAC",
  "AccessKeyId" : "#{creds.access_key_id}",
  "SecretAccessKey" : "#{creds.secret_access_key}",
  "Token" : "#{creds.session_token}",
  "Expiration" : "#{creds.expiration.strftime("%Y-%m-%dT%H:%M:%SZ")}"
}
EOF
        end
      end

      server.start
    end
  end
end
