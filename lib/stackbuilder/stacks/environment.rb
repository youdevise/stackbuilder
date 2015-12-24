require 'stackbuilder/stacks/namespace'
require 'stackbuilder/stacks/machine_def_container'

class Stacks::Environment
  attr_reader :domain_suffix
  attr_reader :environments # XXX this is silly and leads to an infinite data structure
  attr_reader :parent
  attr_reader :name
  attr_reader :options
  attr_reader :primary_site
  attr_reader :secondary_site
  attr_accessor :production

  include Stacks::MachineDefContainer

  def initialize(name, options, parent, environments, stack_procs, calculated_dependencies_cache)
    @name = name
    @options = options
    @environments = environments
    @stack_procs = stack_procs
    @definitions = {}
    @persistent_storage_supported =
      options[:persistent_storage_supported].nil? ? true : options[:persistent_storage_supported]
    @every_machine_destroyable =
      options[:every_machine_destroyable].nil? ? false : options[:every_machine_destroyable]
    @primary_site = options[:primary_site]
    @secondary_site = options[:secondary_site]
    @domain_suffix = options[:domain_suffix] || 'net.local'
    @parent = parent
    @children = []
    @production = options[:production].nil? ? false : options[:production]
    @calculated_dependencies_cache = calculated_dependencies_cache
  end

  def child?(environment)
    children.include?(environment)
  end

  def child_or_self?(environment)
    children.include?(environment) || environment == self
  end

  def sub_environments
    children.select { |node| node.is_a?(Stacks::Environment) }
  end

  def sub_environment_names
    names = []
    sub_environments.each do |sub_environment|
      names << sub_environment.name
    end
    names
  end

  def domain(fabric, network = nil)
    case fabric
    when 'local'
      case network
      when nil, :prod
        "#{@domain_suffix}"
      else
        "#{network}.#{@domain_suffix}"
      end
    else
      case network
      when nil, :prod
        "#{fabric}.#{@domain_suffix}"
      else
        "#{network}.#{fabric}.#{@domain_suffix}"
      end
    end
  end

  def environment
    self
  end

  def all_environments
    @environments.inject([]) do |acc, (_, env)|
      add_sub_environments(acc, top_level_env_of(env))
      acc
    end.inject({}) do |map, env|
      map[env.name] = env
      map
    end
  end

  def add_sub_environments(accumulator, env)
    accumulator << env
    env.sub_environments.inject(accumulator) do |acc, sub|
      add_sub_environments(acc, sub)
      acc
    end
  end

  def top_level_env_of(e)
    if e.parent.nil?
      e
    else
      highest_environment(e.parent)
    end
  end

  def parent?
    !@parent.nil?
  end

  def cross_site_routing_required?
    return false if @primary_site.nil? || @secondary_site.nil?
    @primary_site != @secondary_site
  end

  def cross_site_routing(fabric, network = 'prod')
    fail "Un-supported cross site routing network #{network}" if network != 'prod'
    site = (fabric == @primary_site) ? @secondary_site : @primary_site
    {
      'networking::routing::to_site' => {
        'network' => network,
        'site'    => site
      }
    }
  end

  def persistent_storage_supported?
    @persistent_storage_supported
  end

  def every_machine_destroyable?
    @every_machine_destroyable
  end

  def env(name, options = {}, &block)
    @definitions[name] = Stacks::Environment.new(
      name,
      self.options.merge(options),
      self,
      @environments,
      @stack_procs,
      @calculated_dependencies_cache)
    @children << @definitions[name]
    @definitions[name].instance_eval(&block) unless block.nil?
  end

  def find_environment(environment_name)
    env = environment.find_all_environments.select do |environment|
      environment.name == environment_name
    end
    if env.size == 1
      return env.first
    else
      fail "Cannot find environment '#{environment_name}'"
    end
  end

  def find_all_environments
    environment_set = Set.new
    environment.environments.values.each do |env|
      unless environment_set.include? env
        environment_set.merge(env.children)
        environment_set.add(env)
      end
    end
    environment_set
  end

  def virtual_services
    virtual_services = []
    find_all_environments.each do |env|
      env.accept do |virtual_service|
        virtual_services.push virtual_service
      end
    end
    virtual_services
  end

  def instantiate_stack(stack_name)
    factory = @stack_procs[stack_name]
    fail "no stack found '#{stack_name}'" if factory.nil?
    instantiated_stack = factory.call(self)
    @definitions[instantiated_stack.name] = instantiated_stack
  end

  def contains_node_of_type?(clazz)
    found = false
    accept do |node|
      found = true if node.is_a?(clazz)
    end
    found
  end

  def find_stack(name)
    node = nil
    accept do |machine_def|
      if (machine_def.respond_to?(:mgmt_fqdn) && machine_def.mgmt_fqdn == name) ||
         machine_def.name == name
        node = machine_def
        break
      end
    end
    node
  end

  def calculated_dependencies
    @calculated_dependencies_cache.get
  end
end
