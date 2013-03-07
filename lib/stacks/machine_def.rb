require 'stacks/namespace'

class Stacks::MachineDef
  attr_reader :hostname, :domain
  attr_reader :environment

  def initialize(base_hostname, networks = [:mgmt,:prod], location = :primary)
    @base_hostname = base_hostname
    @networks = [:mgmt, :prod]
    @location = location
  end

  def children
    return []
  end

  def bind_to(environment)
    @environment = environment
    @hostname = environment.name + "-" + @base_hostname
    @fabric = environment.options[@location]
    @domain = "#{@fabric}.net.local"
    raise "domain must not contain mgmt" if @domain =~ /mgmt\./
  end

  def accept(&block)
    block.call(self)
  end

  def to_specs
    return []
  end

  def qualified_hostname(network)
    raise "no such network '#{network}'" unless @networks.include?(network)
    if network.eql?(:prod)
      return "#{@hostname}.#{@domain}"
    else
      return "#{@hostname}.#{network}.#{@domain}"
    end
  end

  def prod_fqdn
    return qualified_hostname(:prod)
  end

  def mgmt_fqdn
    return qualified_hostname(:mgmt)
  end

  def clazz
    return "machine"
  end
end
