module Stacks::TestFramework
  attr_reader :stacks

  def given(&block)
    stacks = Object.new
    stacks.extend Stacks::DSL
    stacks.instance_eval(&block)
    @subject = @stacks = stacks
  end

  def machineset(name, &block)
    subject = @subject
    it "#{name}" do
      services = nil
      subject.accept do |s|
        services = s if s.is_a?(Stacks::CustomServices)
      end
      set = services.k8s_machinesets[name]
      block.call(set)
    end
  end

  def host(host, &block)
    subject = @subject
    it "#{host}" do
      host = subject.find(host)
      block.call(host)
    end
  end

  def all_hosts(&block)
    subject = @subject
    it "all hosts" do
      subject.all_hosts.each do |host|
        block.call(host)
      end
    end
  end

  def xhost(host, &block)
    subject = @subject
    xit "#{host}" do
      host = subject.find(host)
      block.call(host)
    end
  end

  def environment(environment, desc = '', &block)
    subject = @subject
    it "#{environment} #{desc}" do
      env = subject.find_environment(environment)
      block.call(env)
    end
  end

  def it_stack(desc, &block)
    subject = @subject
    it "stack #{desc}" do
      block.call(subject)
    end
  end
end

module Stacks::Matchers
  RSpec::Matchers.define :have_host do |fqdn|
    match do |stacks|
      stacks.exist?(fqdn)
    end

    failure_message do
      "Expected to have host: #{fqdn}"
    end

    failure_message_when_negated do
      "Expected to not have host: #{fqdn}"
    end
  end

  RSpec::Matchers.define :have_hosts do |hosts|
    match do |stacks|
      stacks.fqdn_list.to_set == hosts.to_set
    end

    failure_message do
      expected_hosts = hosts.to_set
      actual_hosts = stacks.fqdn_list.to_set
      missing_nodes = expected_hosts - actual_hosts
      unexpected_nodes = actual_hosts - expected_hosts
      error_message = ''
      if missing_nodes.size > 0
        error_message += "Expected hosts were missing:\n #{missing_nodes.to_a.join("\n ")}\n"
        error_message += "Actual hosts:\n #{actual_hosts.to_a.join("\n ")}\n"
      end
      if unexpected_nodes.size > 0
        error_message += "Unexpected hosts found:\n #{unexpected_nodes.to_a.join("\n ")}\n"
        error_message += "Expected hosts:\n #{expected_hosts.to_a.join("\n ")}\n"
      end
      error_message
    end
  end
end

def describe_stack(name, &block)
  describe name do
    extend Stacks::TestFramework
    extend RSpec::Matchers
    extend Stacks::Matchers
    instance_eval(&block)
  end
end

def x_describe_stack(name, &_block)
  describe name do
    puts "describe_stack #{name} - disabled"
  end
end
