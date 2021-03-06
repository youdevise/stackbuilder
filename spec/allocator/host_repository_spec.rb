require 'stackbuilder/allocator/host_repository'
require 'stackbuilder/stacks/factory'

describe StackBuilder::Allocator::HostRepository do
  before do
    extend Stacks::DSL
  end

  def test_env_with_refstack
    stack "ref" do
      app_service "refapp"
    end

    env "test", :primary_site => "t" do
      instantiate_stack "ref"
    end

    find_environment("test")
  end

  it 'creates a Hosts object with corresponding Host objects' do
    env = test_env_with_refstack
    machines = env.flatten.map(&:hostname)

    compute_node_client = double
    n = 5
    result = {}
    n.times do |i|
      result["h#{i}"] = {
        :active_domains => machines,
        :inactive_domains => []
      }
    end

    preference_functions = []
    allow(compute_node_client).to receive(:audit_fabric).and_return(result)

    host_repo = StackBuilder::Allocator::HostRepository.new(
      :machine_repo => self,
      :preference_functions => preference_functions,
      :compute_node_client => compute_node_client)

    hosts = host_repo.find_compute_nodes("t")
    expect(hosts.size).to eql(n)
    hosts.each do |host|
      expect(host.preference_functions).to eql(preference_functions)
      expect(host.machines).to eql(env.flatten.map(&:to_specs).flatten)
    end
  end

  it 'includes missing machine specs for machines that do not exist in the model' do
    env = test_env_with_refstack
    machines = env.flatten.map(&:hostname)
    machine_specs = env.flatten.map(&:to_specs).flatten
    machines << "roguemachine"
    machine_specs << { :hostname => "roguemachine", :in_model => false }
    compute_node_client = double
    n = 5
    result = {}
    n.times do |i|
      result["h#{i}"] = {
        :active_domains => machines,
        :inactive_domains => []
      }
    end

    preference_functions = []
    allow(compute_node_client).to receive(:audit_fabric).and_return(result)

    host_repo = StackBuilder::Allocator::HostRepository.new(
      :machine_repo => self,
      :preference_functions => preference_functions,
      :compute_node_client => compute_node_client)

    hosts = host_repo.find_compute_nodes("t")
    expect(hosts.size).to eql(n)
    hosts.each do |host|
      expect(host.preference_functions).to eql(preference_functions)
      expect(host.machines).to eql(machine_specs)
    end
  end
end
