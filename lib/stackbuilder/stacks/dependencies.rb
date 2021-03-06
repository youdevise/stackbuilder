require 'stackbuilder/stacks/namespace'

module Stacks::Dependencies
  ##
  # A dependency on all of the selected targets
  MultiServiceDependency = Struct.new(:from, :to_selector, :requirement) do
    def [](_)
      fail("Don't use this")
    end

    def resolve_targets(environment)
      targets = environment.all_things.select do |thing|
        to_selector.matches(from, thing)
      end.uniq

      fail("Cannot find #{describe}.") if targets.empty?
      targets
    end

    def describe
      "all services #{to_selector.describe} depended on by #{from.name} in #{from.environment.name}"
    end
  end

  ##
  # Subclass to tag that this dependency is on only one of the targets.
  class SingleServiceDependency < MultiServiceDependency
    def describe
      "single service #{to_selector.describe} depended on by #{from.name} in #{from.environment.name}"
    end
  end

  EnvironmentDependency = Struct.new(:from, :to_selector, :requirement) do
    def [](_)
      fail("Don't use this")
    end

    def resolve_targets(environment)
      environment.all_things.select do |thing|
        to_selector.matches(from, thing)
      end.uniq
    end

    def describe
      "single service #{to_selector.describe} depended on by #{from.name} in #{from.environment.name} "\
      "(dependency specified by the environment)"
    end
  end

  ServiceSelector = Struct.new(:service_name, :env_name) do
    def matches(_from, to)
      to.is_a?(Stacks::MachineSet) && service_name.eql?(to.name) && env_name.eql?(to.environment.name)
    end

    def describe
      "#{service_name} in #{env_name}"
    end
  end

  MultiSelector = Struct.new(:selectors) do
    def matches(from, to)
      selectors.any? { |s| s.matches(from, to) }
    end

    def describe
      "any of [#{selectors.map(&:describe).join(', ')}]"
    end
  end

  class AllKubernetesSelector
    def initialize(requirement)
      @requirement = requirement
    end

    def matches(from, to)
      return false unless to.is_a?(Stacks::MachineSet)
      if @requirement == :same_site
        to.kubernetes && from.sites.any? { |site| to.exists_in_site?(to.environment, site) }
      else
        to.kubernetes
      end
    end

    def describe
      "all kubernetes services"
    end
  end

  class LabelsKubernetesSelector
    attr_reader :labels
    attr_reader :ports

    def initialize(labels, env_name, requirement, ports)
      fail('Specific environment support for LabelsKubernetesSelector is not yet implemented') if env_name != :all
      @labels = labels
      @env_name = env_name
      @requirement = requirement
      @ports = ports
    end

    def matches(from, to)
      return false unless to.is_a?(Stacks::MachineSet)
      return false unless to.kubernetes
      return false if @requirement == :same_site && ! (from.sites.any? { |site| to.exists_in_site?(to.environment, site) })

      @labels.each do |label, value|
        return false unless (to.service_adjusted_labels.key? label) && (to.service_adjusted_labels[label] == value)
      end
      true
    end

    def describe
      case @env_name
      when :all
        "matching labels '#{@labels}' in all environments on ports '#{ports.join(',')}'"
      else
        "matching labels '#{@labels}' in environment '#{env_name}' on ports '#{ports.join(',')}'"
      end
    end
  end

  public

  # FIXME: rpearce: This does not belong here but is needed to provide a mechanism for late binding through composition.
  def self.extended(object)
    object.configure
  end

  def config_params(_dependant, _fabric, _dependent_instance)
    {} # parameters for config.properties of apps depending on this service
  end

  def dependant_load_balancer_fqdns(location, networks = [:prod])
    instances = dependant_instances_of_type(Stacks::Services::LoadBalancer, location)
    fqdn_list(instances, networks)
  end

  def dependant_app_server_fqdns(location, networks = [:prod])
    instances = dependant_instances_of_type(Stacks::Services::AppServer, location)
    fqdn_list(instances, networks)
  end

  def dependant_instance_fqdns(location, networks = [:prod], reject_nodes_in_different_location = true, reject_k8s_nodes = false)
    fqdn_list(dependant_instances(location, reject_nodes_in_different_location, reject_k8s_nodes), networks).sort
  end

  def virtual_services_that_depend_on_me
    dependants.map(&:from)
  end

  def dependencies
    dynamic_deps = (self.respond_to?(:establish_dependencies) ? establish_dependencies : []).map do |dep|
      SingleServiceDependency.new(self, ServiceSelector.new(dep[0], dep[1]))
    end

    @depends_on + dynamic_deps + environment.depends_on
  end

  # These are the dependencies from others onto this service
  def dependants
    @environment.calculated_dependencies.map(&:last).flatten.select do |dep|
      dep.to_selector.matches(dep.from, self)
    end
  end

  def get_children_for_virtual_services(virtual_services,
                                        location = :primary_site,
                                        reject_nodes_in_different_location = true,
                                        reject_k8s_nodes = false)

    children = []
    virtual_services.map do |service|
      next if reject_k8s_nodes && service.kubernetes
      children.concat(service.children)
    end

    nodes = children.flatten

    if reject_nodes_in_different_location
      nodes.reject! { |node| node.location != location }

      if location == :secondary_site
        nodes.reject! { |node| node.virtual_service.secondary_site? == false }
      end
    end
    nodes.uniq
  end

  def virtual_services_that_i_depend_on(include_env_dependencies = true)
    dependencies.reject do |dep|
      dep.is_a?(Stacks::Dependencies::EnvironmentDependency) && !include_env_dependencies
    end.flat_map do |dep|
      dep.resolve_targets(@environment)
    end
  end

  private

  def fqdn_list(instances, networks = [:prod])
    fqdns = []
    networks.each do |network|
      instances.map do |instance|
        fqdns << instance.qualified_hostname(network)
      end
    end
    fqdns.sort
  end

  def dependant_instances_of_type(type, location)
    dependant_instances(location).reject { |machine_def| machine_def.class != type }
  end

  def dependant_instances(location, reject_nodes_in_different_location = true, reject_k8s_nodes = false)
    get_children_for_virtual_services(
      virtual_services_that_depend_on_me,
      location,
      reject_nodes_in_different_location,
      reject_k8s_nodes)
  end

  def non_k8s_dependencies_exist?
    dependants.count { |dep| !dep.from.kubernetes } > 0
  end
end
