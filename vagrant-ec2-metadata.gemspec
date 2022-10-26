require_relative "lib/vagrant-ec2-metadata/version"
require "date"

Gem::Specification.new do |gem|
  gem.name         = "vagrant-ec2-metadata"
  gem.version      = VagrantEc2Metadata::VERSION
  gem.platform     = Gem::Platform::RUBY
  gem.date         = Date.today.to_s
  gem.files        = %x{git ls-files lib}.split("\n")
  gem.require_path = "lib"

  gem.summary      = "Easily provide vagrant machines with AWS credentials."
  gem.description  = "Easily provide vagrant machines with AWS credentials by faking an EC2 metadata server."
  gem.homepage     = "https://github.com/stefansundin/vagrant-ec2-metadata"
  gem.license      = "GPL-3.0"
  gem.authors      = ["Stefan Sundin"]
  gem.email        = ["rubygems@stefansundin.com"]

  gem.cert_chain   = ["certs/stefansundin.pem"]
  gem.signing_key  = File.expand_path("~/.ssh/gem-private_key.pem") if $0 =~ /gem\z/

  gem.add_dependency "aws-sdk-core", "~> 3.164"
  gem.add_dependency "webrick", "~> 1.6.1"
  # webrick 1.7 has this problem: https://github.com/ruby/webrick/issues/67
end
