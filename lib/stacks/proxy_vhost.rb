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
    @vhost_fqdn = vhost_fqdn
    @service = service
    @aliases = []
    @redirects = []
    @proxy_pass_rules = {}
    @type = type
    @properties = {}
    @add_default_aliases = true
    @cert = 'wildcard_timgroup_com'
    instance_eval(&block) if block
  end

  # XXX remove once all vhost entries in stackbuilder-config have switched to 'aliases <<'
  def with_alias(alias_fqdn)
    @aliases << alias_fqdn
  end

  # XXX looks like this method is never used
  def with_redirect(redirect_fqdn)
    @redirects << redirect_fqdn
  end

  def pass(proxy_pass_rule)
    @proxy_pass_rules.merge!(proxy_pass_rule)
  end

  # XXX remove once all vhost entries in stackbuilder-config have switched to 'cert ='
  def with_cert(cert_name)
    @cert = cert_name
  end

  def add_properties(properties)
    @properties.merge!(properties)
  end

  # XXX remove once all vhost entries in stackbuilder-config have switched to 'add_properties()'
  def vhost_properties(properties)
    @properties.merge!(properties)
  end
end
