require "webrick"
require "aws-sdk-core"
require "socket"

ENV["AWS_DEFAULT_REGION"] ||= "us-west-2"

module VagrantEc2Metadata
  class Server
    def initialize(config, port, env)
      @config = config
      @port = port
      @env = env
    end

    def start
      host_ip = Socket.ip_address_list.detect(&:ipv4_private?).ip_address
      server = WEBrick::HTTPServer.new(BindAddress: host_ip, Port: @port)

      trap "INT" do
        server.shutdown
      end

      # This endpoint is all we handle right now
      # curl http://169.254.169.254/latest/meta-data/iam/security-credentials/role
      server.mount_proc "/latest/meta-data/iam/security-credentials/" do |req, res|
        if req.path == "/latest/meta-data/iam/security-credentials/"
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
