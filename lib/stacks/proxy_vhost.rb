require 'stacks/namespace'
require 'uri'

class Stacks::ProxyVHost
  attr_accessor :add_default_aliases
  attr_accessor :aliases
  attr_accessor :cert
  attr_reader :properties
  attr_reader :proxy_pass_rules
  attr_reader :redirects
  attr_reader :service
  attr_reader :type
  attr_reader :vhost_fqdn

  def initialize(vhost_fqdn, service, type = 'default', &block)
    @add_default_aliases = true
    @aliases = []
    @cert = 'wildcard_timgroup_com'
    @properties = {}
    @proxy_pass_rules = {}
    @redirects = []
    @service = service
    @type = type
    @vhost_fqdn = vhost_fqdn

    instance_eval(&block) if block
  end

  # XXX looks like this method is never used
  def with_redirect(redirect_fqdn)
    @redirects << redirect_fqdn
  end

  def add_pass_rule(path, config_hash)
    @proxy_pass_rules[path] = config_hash
  end

  def add_properties(properties)
    @properties.merge!(properties)
  end
end
