require 'stackbuilder/allocator/namespace'
require 'stackbuilder/allocator/hosts'

class StackBuilder::Allocator::HostRepository
  attr_accessor :machine_repo
  attr_reader :preference_functions
  attr_reader :policies

  def initialize(args)
    @machine_repo = args[:machine_repo]
    @preference_functions = args[:preference_functions]
    @compute_node_client = args[:compute_node_client]
    @policies = args[:policies]
  end

  def find_compute_node(host_fqdn, audit_domains = false, audit_storage = true, audit_inventory = true)
    audit = @compute_node_client.audit_hosts([host_fqdn], audit_domains, audit_storage, audit_inventory)
    fabric = host_fqdn.partition('-').first
    hosts = to_stacks_hosts(audit, fabric)
    hosts[0]
  end

  def find_compute_nodes(fabric, audit_domains = false, audit_storage = true, audit_inventory = true)
    audit = @compute_node_client.audit_fabric(fabric, audit_domains, audit_storage, audit_inventory)
    to_stacks_hosts(audit, fabric)
  end

  def fabric_allocator(fabric)
    hosts = find_compute_nodes(fabric)
    StackBuilder::Allocator::Hosts.new(:hosts => hosts, :preference_functions => preference_functions)
  end

  def find_fabric_vms(fabric)
    result = []
    @compute_node_client.audit_fabric(fabric, true).each do |host_fqdn, host_data|
      host_data[:domains].each do |vm_fqdn, vm_data|
        vm_data[:fqdn] = vm_fqdn
        vm_data[:host_fqdn] = host_fqdn
        result.push(vm_data)
      end
    end
    result
  end

  def find_host_vms(host_fqdn)
    result = []
    @compute_node_client.audit_hosts([host_fqdn], true).each do |h_fqdn, host_data|
      host_data[:domains].each do |vm_fqdn, vm_data|
        vm_data[:fqdn] = vm_fqdn
        vm_data[:host_fqdn] = h_fqdn
        result.push(vm_data)
      end
    end
    result
  end

  private

  def to_stacks_hosts(audit, fabric)
    hosts = []
    audit.each do |fqdn, attr|
      vms = []
      all_domains = attr[:active_domains].concat(attr[:inactive_domains])
      all_domains.each do |vm_hostname|
        vm_object = machine_repo.find_by_hostname(fabric, vm_hostname)
        if vm_object.nil?
          vms << { :hostname => vm_hostname, :in_model => false }
        else
          vms << vm_object.to_spec
        end
      end

      host = StackBuilder::Allocator::Host.new(fqdn,
                                               :preference_functions => preference_functions,
                                               :policies => policies,
                                               :ram => attr[:memory],
                                               :storage => attr[:storage],
                                               :facts => attr[:facts])

      host.allocated_machines = vms
      host.domains = attr[:domains]
      hosts << host
    end
    hosts
  end
end
