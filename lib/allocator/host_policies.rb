require 'allocator/namespace'
require 'allocator/policy_helpers'

module StackBuilder::Allocator::HostPolicies

  def self.ha_group()
    Proc.new do |host, machine_spec|
      result = { :passed => true }
      if machine_spec[:availability_group]
        host.machines.each do |allocated_machine|
          if allocated_machine[:availability_group] and machine_spec[:availability_group] == allocated_machine[:availability_group]
            result = { :passed => false, :reason => "already running #{allocated_machine[:hostname]}, which is in same availability group" }
          end
        end
      end
      result
    end
  end

  def self.do_not_overallocated_ram_policy
    helper = StackBuilder::Allocator::PolicyHelpers
    Proc.new do |host, machine|
      result = { :passed => true }
      host_ram_stats = helper.ram_stats_of(host)
      if host_ram_stats[:available_ram] < Integer(machine[:ram])
        result = {
          :passed => false,
          :reason => "unable to fulfil ram requirement of #{machine[:ram]} because only #{host_ram_stats[:available_ram]} is available. Memory stats: #{host_ram_stats[:allocated_ram]+host_ram_stats[:host_reserve_ram]}/#{host_ram_stats[:host_ram]}"
        }
      end
      result
    end
  end

  def self.do_not_overallocated_disk_policy
    Proc.new do |host, machine|
      { :passed => true }
    end
  end

end
