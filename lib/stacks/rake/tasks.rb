require 'rake'
require 'pp'
require 'yaml'
require 'rubygems'
require 'stacks/environment'
require 'support/mcollective'
require 'ci/reporter/rspec'
require 'set'
require 'rspec'
require 'compute/controller'

include Rake::DSL

include Support::MCollective

extend Stacks::DSL
begin
  require 'stack.rb'
rescue Exception
  puts "Cannot find stack.rb in the local directory, giving up"
  exit 1
end

environment_name = ENV.fetch('env', 'dev')
bind_to(environment_name)

RSpec::Core::Runner.disable_autorun!
config = RSpec.configuration
config.color_enabled = true
ENV['CI_REPORTS'] = 'build/spec/reports/'

####
# TODO:
# general:
#         use logging
#         push stuff back out of here
#         does it complain well when keys aren't to be found anywhere?
#         puppet out seed key to ci and infra
#           probably want to have a different key in each dc?
#
# possibly:
#         implement visitor pattern to traverse tree
#
# allocate: tidy up output
#
# launch: tidy up output
#         clearly indicate success or failure to launnch
#         launch in parallel
#
# clean machines:
#         clean needs to show what it actually cleaned, currently dumps results
#         need to account for which host each machine was cleaned from
#
# mping:
#         tidy, test and
#
# puppetclean:
#       warn if cert clean did not occur
#       show positive clean action clearly in log
#
# puppetsign:
#       warn if signing did not occur
#       use output more wisely
#       show positive sign action clearly in log
#
# need workflow tasks to tie builds together.
#   ie provision dependson [launch, mping, puppet, test]
#      clean     dependson [destroy_vms, clean_certs]
#

def sbtask(name, &block)
  task name do
    puts "running #{name}@@@@\n"
    block.call()
    puts "complete #{name}$%%\n"
  end
end

namespace :sbx do
  accept do |machine_def|
    namespace machine_def.name.to_sym do
      RSpec::Core::Runner.disable_autorun!

      desc "outputs the specs for these machines, in the format to feed to the provisioning tools"
      task :to_specs do
        puts machine_def.to_specs.to_yaml
      end

      task :provision=> [:launch, :puppet_clean, :mping, :puppet_sign, :puppet, :test]

      desc "allocate these machines to hosts (but don't actually launch them - this is a dry run)"
      task :allocate do
        computecontroller = Compute::Controller.new
        pp computecontroller.allocate(machine_def.to_specs)
      end

      desc "resolve the IP numbers of these machines"
      task :resolve do
        computecontroller = Compute::Controller.new
        pp computecontroller.resolve(machine_def.to_specs)
      end

      desc "launch these machines"
      sbtask :launch do
        computecontroller = Compute::Controller.new
        computecontroller.launch(machine_def.to_specs) do
          on :success do |vm|
            puts "#{vm} success \n"
          end
          on :failure do |vm|
            puts "#{vm} failure \n"
          end
          on :unaccounted do |vm|
            puts "#{vm} unaccounted \n"
          end
        end
      end

      desc "perform an MCollective ping against these machines"
      sbtask :mping do
        hosts = []
        machine_def.accept do |child_machine_def|
          if child_machine_def.respond_to?(:mgmt_fqdn)
            hosts << child_machine_def.mgmt_fqdn
          end
        end
        found = false
        50.times do
          found = mco_client("rpcutil", :key => "seed") do |mco|
            hosts.to_set.subset?(mco.discover.to_set)
          end

          sleep 1
          break if found
        end

        fail("nodes #{hosts} not checked in to mcollective") unless found
        pp "all nodes found in mcollective #{found}"
      end

      desc "clean Puppet certificates for these machines"
      sbtask :puppet_clean do
        machine_def.accept do |child_machine_def|
          if child_machine_def.respond_to?(:mgmt_fqdn)
            mco_client("puppetca") do |mco|
              pp mco.clean(:certname => child_machine_def.mgmt_fqdn)
            end
          end
        end
      end

      desc "sign outstanding Puppet certificate signing requests for these machines"
      sbtask :puppet_sign do
        machine_def.accept do |child_machine_def|
          if child_machine_def.respond_to?(:mgmt_fqdn)

            mco_client("puppetca") do |mco|
              pp mco.sign(:certname => child_machine_def.mgmt_fqdn)
            end
          end
        end
      end

      desc "run Puppet on these machines"
      sbtask :puppet do
        hosts = []
        machine_def.accept do |child_machine_def|
          if child_machine_def.respond_to?(:mgmt_fqdn)
            hosts << child_machine_def.mgmt_fqdn
          end
        end
        pp hosts
        mco_client("puppetd", :key => "seed") do |mco|
          engine = PuppetRoll::Engine.new({:concurrency => 5}, [], hosts, PuppetRoll::Client.new(hosts, mco))
          engine.execute()
          pp engine.get_report()
        end
      end

      desc ""
      task :puppet_clean do
        include Support::MCollective
        machine_def.accept do |child_machine_def|
          if child_machine_def.respond_to?(:mgmt_fqdn)
            mco_client("puppetca") do |mco|
              pp mco.clean(:certname => child_machine_def.mgmt_fqdn)
            end
          end
        end
      end

      desc "clean away all traces of these machines"
      task :clean do
        computecontroller = Compute::Controller.new
        pp computecontroller.clean(machine_def.to_specs)
      end

      desc "carry out all appropriate tests on these machines"
      task :test do
        machine_def.accept do |child_machine_def|
          if child_machine_def.respond_to?(:mgmt_fqdn)
            specpath = File.dirname(__FILE__) + "/../stacktests/#{child_machine_def.clazz}/*.rb"
            describe "#{child_machine_def.clazz}.#{child_machine_def.name}" do
              Dir[specpath].each do |file|
                require file
                test = File.basename(file, '.rb')
                it_behaves_like test, machine_def
              end
            end
          end
        end
        RSpec::Core::Runner.run(['--format', 'CI::Reporter::RSpec'], $stderr, $stdout)
      end
    end
  end
end
