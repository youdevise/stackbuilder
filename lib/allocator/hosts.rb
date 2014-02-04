require 'allocator/namespace'
require 'allocator/host'

class StackBuilder::Allocator::Hosts
  attr_accessor :hosts
  def initialize(args)
    @hosts = args[:hosts]
    @logger = args[:logger]
    hosts.each do |host|
      host.set_preference_functions(args[:preference_functions])
    end
  end

  private
  def find_suitable_host_for(machine)
    allocation_denials = []

    candidate_hosts = hosts.reject do |host|
      allocation_check_result = host.can_allocate(machine)
      if !allocation_check_result[:allocatable]
        reason_message = allocation_check_result[:reasons].join("; ")
        if @logger != nil
          @logger.debug("Unable to allocate #{machine[:hostname]} to #{host.fqdn} because it is [#{reason_message}]")
        end
        allocation_denials << "unable to allocate to #{host.fqdn} because it is [#{reason_message}]"
      end
      !allocation_check_result[:allocatable]
    end

    raise "unable to allocate #{machine[:hostname]} due to policy violation:\n  #{allocation_denials.join("\n  ")}" if candidate_hosts.size==0
    candidate_hosts.sort_by do |host|
      host.preference(machine)
    end[0]
  end

  def unallocated_machines(machines)
    allocated_machines = []
    hosts.each do |host|
      host.allocated_machines.each do |machine|
        allocated_machines << machine
      end
    end

    return machines - allocated_machines
  end

  public

  def new_machine_allocation()
    hash = []
    hosts.map do |host|
      host.provisionally_allocated_machines.each do |machine|
        hash << [machine, host]
      end
    end

    Hash[hash]
  end

  def allocated_machines(machines)
    hash = []
    hosts.map do |host|
      intersection =  host.allocated_machines.to_set & machines.to_set
      intersection.map do |machine|
        hash << [machine, host]
      end
    end

    Hash[hash]
  end


  def do_allocation(specs)
    allocated_machines = Hash[hosts.map do |host|
      host.allocated_machines.map do |machine|
        [machine, host.fqdn]
      end
    end.flatten(1)]

    already_allocated = allocated_machines.reject do |machine, host|
      !specs.include?(machine)
    end

    return {
      :already_allocated => already_allocated,
      :newly_allocated => allocate(specs)
    }
  end

  ### TODO: make private
  def allocate(machines)
    unallocated_machines = unallocated_machines(machines)

    allocated_machines = Hash[unallocated_machines.map do |machine|
      host = find_suitable_host_for(machine)
      host.provisionally_allocate(machine)
      [machine, host.fqdn]
    end]

    return_map = {}
    allocated_machines.each do |machine, host|
      return_map[host] = [] unless (return_map[host])
      return_map[host] << machine
    end

    return_map
  end

  ##TEST.ME
  def to_unlaunched_specs
    Hash[@hosts.map do |host|
      specs = host.provisionally_allocated_machines()
      [host.fqdn, specs]
    end].reject {|host, specs| specs.size==0}
  end
end
