require 'rake'
require 'pp'
require 'yaml'
require 'rubygems'
require 'stackbuilder/stacks/environment'
require 'stackbuilder/stacks/inventory'
require 'stackbuilder/support/mcollective'
require 'stackbuilder/support/mcollective_puppet'
require 'stackbuilder/compute/controller'
require 'stackbuilder/allocator/host_repository'
require 'stackbuilder/allocator/host_preference'
require 'stackbuilder/allocator/host_policies'
require 'stackbuilder/allocator/ephemeral_allocator'
require 'stackbuilder/dns/basic_dns_service'
require 'stackbuilder/stacks/core/services'
require 'stackbuilder/stacks/namespace'

class Stacks::Factory
  def logger
    return @log unless @log.nil?
    @interactive = $stdout.tty? || ENV.key?("BUILD_NUMBER")

    @log = Logger.new STDOUT
    @log.instance_eval do
      def start(task)
        @start_time = Time.now
        if @interactive
          puts "\e[1m\e[34m:#{task}\e[0m"
        else
          puts ":#{task}"
        end
      end

      def failed(task)
        @elapsed = Time.now - @start_time
        e = sprintf("%.2f", @elapsed)
        if @interactive
          puts "\n\e[1m\e[31m:#{task} failed in #{e}\e[0m\n"
        else
          puts "\n:#{task} failed in #{e}\n"
        end
      end

      def passed(task)
        @elapsed = Time.now - @start_time
        e = sprintf("%.2f", @elapsed)
        if @interactive
          puts "\n\e[1m\e[32m:#{task} passed in #{e}s\e[0m\n"
        else
          puts "\n:#{task} passed in #{e}s\n"
        end
      end
    end
    @log
  end

  def inventory
    @inventory ||= Stacks::Inventory.new('.')
  end

  def policies
    @policies ||= [
      StackBuilder::Allocator::HostPolicies.ensure_defined_storage_types_policy,
      StackBuilder::Allocator::HostPolicies.do_not_overallocate_disk_policy,
      StackBuilder::Allocator::HostPolicies.ha_group,
      StackBuilder::Allocator::HostPolicies.do_not_overallocated_ram_policy,
      StackBuilder::Allocator::HostPolicies.allocation_temporarily_disabled_policy,
      StackBuilder::Allocator::HostPolicies.require_persistent_storage_to_exist_policy
    ]
  end

  def preference_functions
    @preference_functions ||= [
      StackBuilder::Allocator::HostPreference.fewest_machines,
      StackBuilder::Allocator::HostPreference.alphabetical_fqdn
    ]
  end

  def compute_controller
    @compute_controller ||= Compute::Controller.new
  end

  def compute_node_client
    @compute_node_client ||= Compute::Client.new
  end

  def dns_service
    @dns_service ||= StackBuilder::DNS::BasicDNSService.new(:logger => logger)
  end

  def host_repository
    @host_repository ||= StackBuilder::Allocator::HostRepository.new(
      :machine_repo => inventory,
      :preference_functions => preference_functions,
      :policies => policies,
      :compute_node_client => compute_node_client,
      :logger => logger
    )
  end

  def allocator
    StackBuilder::Allocator::EphemeralAllocator.new(:host_repository => host_repository)
  end

  def services
    @services ||= Stacks::Core::Services.new(
      :compute_controller => compute_controller,
      :allocator => allocator,
      :dns_service => dns_service,
      :logger => logger
    )
  end
end