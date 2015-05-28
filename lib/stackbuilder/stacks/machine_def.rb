require 'stackbuilder/support/owner_fact'
require 'stackbuilder/stacks/namespace'

class Stacks::MachineDef
  attr_reader :domain
  attr_reader :environment
  attr_reader :fabric
  attr_reader :hostname
  attr_reader :virtual_service
  attr_reader :location
  attr_accessor :availability_group
  attr_accessor :fabric
  attr_accessor :networks
  attr_accessor :ram
  attr_accessor :storage
  attr_accessor :vcpus

  def initialize(base_hostname, networks = [:mgmt, :prod], location = :primary_site)
    @base_hostname = base_hostname
    @networks = networks
    @location = location
    @availability_group = nil
    @ram = "2097152"
    @storage = {
      '/'.to_sym =>  {
        :type        => 'os',
        :size        => '3G',
        :prepare     => {
          :method => 'image',
          :options => {
            :path => '/var/local/images/gold-precise/generic.img'
          }
        }
      }
    }
    @destroyable = true
    @dont_start = false
    @routes = []
    @included_classes = {}

    fail "illegal hostname: \"#{@base_hostname}\". hostnames can only contain letters, digits and hyphens" \
      unless /^[-a-zA-Z0-9]+$/.match(@base_hostname)
  end

  def include_class(class_name, class_hash = {})
    @included_classes[class_name] = class_hash
  end

  def use_trusty
    trusty_gold_image = {
      '/'.to_sym =>  {
        :prepare     => {
          :options => {
            :path => '/var/local/images/gold-trusty/generic.img'
          }
        }
      }
    }
    modify_storage(trusty_gold_image)
  end

  def needs_signing?
    true
  end

  # rubocop:disable Style/TrivialAccessors
  def destroyable?
    @destroyable
  end
  # rubocop:enable Style/TrivialAccessors

  def needs_poll_signing?
    true
  end

  # rubocop:disable Style/TrivialAccessors
  def allow_destroy(destroyable = true)
    @destroyable = destroyable
  end
  # rubocop:enable Style/TrivialAccessors

  def bind_to(environment)
    @environment = environment
    @fabric = environment.options[@location]
    case @fabric
    when 'local'
      @hostname  = "#{@environment.name}-#{@base_hostname}-#{OwnerFact.owner_fact}"
    else
      @hostname = "#{@environment.name}-#{@base_hostname}"
    end
    @domain = environment.domain(@fabric)
  end

  def disable_persistent_storage
    @storage.each do |mount_point, _values|
      modify_storage(mount_point.to_sym => { :persistent => false })
    end
  end

  def accept(&block)
    block.call(self)
  end

  def flatten
    [self]
  end

  def name
    hostname
  end

  def modify_storage(storage_modifications)
    storage_modifications.each do |mount_point, values|
      if @storage[mount_point.to_sym].nil?
        @storage[mount_point.to_sym] = values
      else
        @storage[mount_point.to_sym] = recurse_merge(@storage[mount_point.to_sym], values)
      end
    end
  end

  def remove_network(net)
    @networks.delete net
  end

  def recurse_merge(a, b)
    a.merge(b) do |_, x, y|
      (x.is_a?(Hash) && y.is_a?(Hash)) ? recurse_merge(x, y) : y
    end
  end

  def add_route(route_name)
    @routes << route_name unless @routes.include? route_name
  end

  def dont_start
    @dont_start = true
  end

  def to_spec
    disable_persistent_storage unless environment.persistent_storage_supported?
    @destroyable = true if environment.every_machine_destroyable?

    spec = {
      :hostname => @hostname,
      :domain => @domain,
      :fabric => @fabric,
      :availability_group => availability_group,
      :networks => @networks,
      :qualified_hostnames => Hash[@networks.map { |network| [network, qualified_hostname(network)] }]
    }

    spec[:disallow_destroy] = true unless @destroyable
    spec[:ram] = ram unless ram.nil?
    spec[:vcpus] = vcpus unless vcpus.nil?
    spec[:storage] = storage
    spec[:dont_start] = true if @dont_start
    spec
  end

  # XXX DEPRECATED for flatten / accept interface, remove me!
  def to_specs
    [to_spec]
  end

  def to_enc
    enc = {}
    enc.merge! @included_classes
    enc.merge! @virtual_service.included_classes if @virtual_service && @virtual_service.respond_to?(:included_classes)
    unless @routes.empty?
      enc['routes'] = {
        'to' => @routes
      }
    end
    enc
  end

  def qualified_hostname(network)
    fail "no such network '#{network}'" unless @networks.include?(network)
    if network.eql?(:prod)
      return "#{@hostname}.#{@domain}"
    else
      return "#{@hostname}.#{network}.#{@domain}"
    end
  end

  def prod_fqdn
    qualified_hostname(:prod)
  end

  def mgmt_fqdn
    qualified_hostname(:mgmt)
  end

  def clazz
    "machine"
  end
end
