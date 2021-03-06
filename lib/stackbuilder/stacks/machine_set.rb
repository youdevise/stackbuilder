require 'securerandom'
require 'stackbuilder/stacks/machine_def_container'
require 'stackbuilder/stacks/dependencies'
require 'stackbuilder/stacks/namespace'
require 'stackbuilder/support/digest_generator'
require 'uri'

class Stacks::MachineSet
  attr_accessor :enable_secondary_site
  attr_accessor :groups
  attr_accessor :instances
  attr_accessor :name
  attr_reader :short_name
  attr_accessor :ports
  attr_accessor :type
  attr_accessor :custom_service_name
  attr_accessor :server_offset
  attr_accessor :monitoring
  attr_accessor :monitoring_options
  attr_accessor :monitoring_in_enc
  attr_accessor :use_docker
  attr_accessor :kubernetes
  attr_reader :allowed_hosts
  attr_reader :allowed_outbound_connections
  attr_reader :default_networks
  attr_reader :depends_on
  attr_reader :stack

  include Stacks::MachineDefContainer

  def initialize(name, stack, &config_block)
    @bind_steps = []
    @config_block = config_block
    @definitions = {}
    @groups = ['blue']
    @instances = 2
    @name = name
    self.short_name = @name.slice(0, 12)
    @stack = stack

    @allowed_hosts = []
    @allowed_outbound_connections = {}
    @default_networks = [:mgmt, :prod]
    @depends_on = []
    @enable_secondary_site = false
    @server_offset = 0
    @add_role_to_name = []
    @monitoring = true
    @monitoring_options = {
      'nagios_host_template'    => 'non-prod-host',
      'nagios_service_template' => 'non-prod-service'
    }
    @monitoring_in_enc = false # temporary feature flag
    @use_docker = false
  end

  def secondary_site?
    @enable_secondary_site
  end

  def standard_labels
    {}
  end

  def type_of?
    :machine_set
  end

  def identity
    "#{environment.name}-#{@stack.name}-#{name}"
  end

  def instances_usage
    "Below is an example of correct usage:\n \
 @instances = {\n\
   'oy' => 1,\n\
   'st' => 1\n\
 }\n\
 This is what you specified:\n @instances = #{@instances.inspect}\n"
  end

  def validate_instances(environment)
    if @instances.is_a?(Integer)
      return
    elsif @instances.is_a?(Hash)
      environment.validate_instance_sites(@instances.keys)
      @instances.each do |_site, count|
        if !count.is_a?(Fixnum)
          fail "You must specify Integers when using @instances in a hash format\n #{instances_usage}"
        end
      end
    else
      fail "You must specify Integer or Hash for @instances. You provided a #{instances.class}"
    end
  end

  def instantiate_machines(environment)
    validate_instances(environment)
    if @instances.is_a?(Integer)
      1.upto(@instances) do |i|
        server_index = i + @server_offset
        instantiate_machine(server_index, environment, environment.sites.first)
        if @enable_secondary_site
          instantiate_machine(server_index, environment, environment.sites.last)
        end
      end
    elsif @instances.is_a?(Hash)
      @instances.each do |site, count|
        if count.is_a?(Integer)
          1.upto(count) do |c|
            server_index = @server_offset + c
            instantiate_machine(server_index, environment, site)
          end
        elsif count.is_a?(Hash)
          count.each do |role, num|
            1.upto(num) do |c|
              server_index = @server_offset + c
              instantiate_machine(server_index, environment, site, role)
            end
          end
        else
          fail "Instances hash contains invalid item #{count} which is a #{count.class} expected Integer / Symbol"
        end
      end
    end
  end

  ##
  # Depend on another service. This affects both the depender and the dependee.
  # The depender recieves entries in its config file to contact the dependee
  # service (the exact elements will depend on the kind of service depended
  # upon). The dependee will allow connections from the depender.
  #
  # @param dependant Symbol|String|Array[String]
  #   If a Symbol, then only the symbol :all is supported, which means to depend on all other services (k8s only)
  #   If a String, then the name of the other service
  #   If an Array[String], then a list of the other services to depend on. Each instance will depend on a single other service (vm only)
  # @param environment String|Symbol (Optional)
  #   The name of the environment to find the depended upon services in. By default the same as the depending service.
  # @param requirement String|Symbol (Optional)
  #   Dependency specific
  def depend_on(dependant, env = environment.name, requirement = nil)
    fail('Dependant cannot be nil') if dependant.nil? || dependant.eql?('')
    fail('Environment cannot be nil') if env.nil? || env.eql?('')
    dep = if dependant == :all
            if env == :all
              Stacks::Dependencies::MultiServiceDependency.new(self,
                                                               Stacks::Dependencies::AllKubernetesSelector.new(requirement),
                                                               requirement)
            else
              fail('Selection by a specific environment not yet support for :all dependency')
            end
          elsif dependant.is_a?(Array)
            selectors = dependant.map { |d| Stacks::Dependencies::ServiceSelector.new(d, env) }
            Stacks::Dependencies::SingleServiceDependency.new(self,
                                                              Stacks::Dependencies::MultiSelector.new(selectors),
                                                              requirement)
          else
            Stacks::Dependencies::SingleServiceDependency.new(self,
                                                              Stacks::Dependencies::ServiceSelector.new(dependant, env),
                                                              requirement)
          end

    @depends_on << dep unless @depends_on.include? dep
  end

  def depend_on_labels(labels, env = environment.name, requirement = nil, ports = ['app'])
    fail('Dependant cannot be nil') if (!labels.is_a? Hash) || labels.empty?
    fail('Environment cannot be nil') if env.nil? || env.eql?('')
    fail('Selection by a specific environment not yet support for depend_on_labels dependency') if env != :all
    dep = Stacks::Dependencies::MultiServiceDependency.new(self,
                                                           Stacks::Dependencies::LabelsKubernetesSelector.new(labels, env, requirement, ports),
                                                           requirement)
    @depends_on << dep unless @depends_on.include? dep
  end

  def dependency_config(fabric, dependent_instance)
    config = {}
    targets = dependencies.flat_map do |dependency|
      d = dependency.resolve_targets(@environment)
      if dependency.is_a?(Stacks::Dependencies::SingleServiceDependency)
        [d[dependent_instance.index % d.length]]
      else
        d
      end
    end.uniq

    targets.each do |target|
      config.merge! target.config_params(self, fabric, dependent_instance)
    end
    config
  end

  def allow_host(source_host_or_network)
    @allowed_hosts << source_host_or_network
    @allowed_hosts.uniq!
  end

  def allow_outbound_to(identifier, destination_ips_in_cidr_form, ports, protocol = 'TCP')
    fail('Allowing outbound connections is only supported if kubernetes is enabled for this machine_set') unless @kubernetes
    @allowed_outbound_connections[identifier] = {
      :ips => destination_ips_in_cidr_form.is_a?(Array) ? destination_ips_in_cidr_form : [destination_ips_in_cidr_form],
      :ports => ports.is_a?(Array) ? ports : [ports],
      :protocol => protocol
    }
  end

  def on_bind(&block)
    @bind_steps << block
  end

  def bind_to(environment)
    @bind_steps.each do |step|
      step.call(self, environment)
    end
  end

  def each_machine(&block)
    on_bind do
      accept do |machine|
        block.call(machine) if machine.is_a? Stacks::MachineDef
      end
    end
  end

  public

  def configure
    on_bind do |_machineset, environment|
      @environment = environment
      instance_eval(&@config_block) unless @config_block.nil?
      instantiate_machines(environment) unless kubernetes
      bind_children(environment)
    end
  end

  def bind_children(environment)
    children.each do |child|
      child.bind_to(environment)
    end
  end

  def availability_group(environment)
    environment.name + "-" + name
  end

  # FIXME: This should generate a unique name
  def random_name
    SecureRandom.hex(20)
  end

  def to_k8s(_app_deployer, _dns_resolver, _hiera_provider, standard_labels)
    policies = []
    @allowed_outbound_connections.each do |connection_name, connection_details|
      filters = []
      connection_details[:ips].each do |ip|
        filters << { 'ipBlock' => { 'cidr' => ip } }
      end
      ports = []
      connection_details[:ports].each do |port|
        ports << {
          'protocol' => connection_details[:protocol].nil? ? 'TCP' : connection_details[:protocol],
          'port' => port
        }
      end

      spec = {
        'podSelector' => {
          'matchLabels' => {
            'machineset' => @name,
            'group' => @groups.first,
            'app.kubernetes.io/component' => @custom_service_name
          }
        },
        'policyTypes' => [
          'Egress'
        ],
        'egress' => [{
          'to' => filters,
          'ports' => ports
        }]
      }

      hash = Support::DigestGenerator.from_hash(spec)

      policies << {
        'apiVersion' => 'networking.k8s.io/v1',
        'kind' => 'NetworkPolicy',
        'metadata' => {
          'name' => "allow-out-to-#{connection_name}-#{hash}",
          'namespace' => @environment.name,
          'labels' => {
            'stack' => @stack.name,
            'machineset' => @name
          }.merge(standard_labels)
        },
        'spec' => spec
      }
    end
    policies
  end

  def fabric
    @environment.primary_site
  end

  def short_name=(short_name)
    fail('The short name of a machine_set must be less than twelve characters.' \
         " You tried to set the short_name of machine_set '#{@name}' in environment '#{@environment.name}' to '#{short_name}'") if short_name.length > 12
    @short_name = short_name
  end

  def sites
    if instances.is_a?(Integer)
      [@environment.sites.first]
    elsif instances.is_a?(Hash)
      instances.keys
    end
  end

  def exists_in_site?(_environment, site)
    sites.include?(site)
  end

  private

  def instantiate_machine(index, environment, site, role = nil, custom_name = '')
    vm_name = "#{name}#{custom_name}-" + sprintf("%03d", index)
    vm_name = "#{name}" if @type == Stacks::Services::ExternalServer
    server = @type.new(self, vm_name, environment, site, role)
    server.group = groups[(index - 1) % groups.size] if server.respond_to?(:group)
    if server.respond_to?(:availability_group)
      server.availability_group = availability_group(environment) + (@enable_secondary_site ? "-#{site}" : '')
    end
    server.index = index
    @definitions[random_name] = server
    server
  end

  def location
    @environment.translate_site_symbol(fabric)
  end
end
