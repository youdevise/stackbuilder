require 'stacks/namespace'
require 'stacks/machine_def_container'
require 'stacks/virtual_service'
require 'stacks/loadbalancer'
require 'stacks/natserver'

class Stacks::Stack < Stacks::MachineDefContainer
  attr_reader :name

  def initialize(name)
    @name = name
    @definitions = {}
  end

  def virtualservice(name, &block)
    @definitions[name] = virtualservice = Stacks::VirtualService.new(name, self)
    virtualservice.instance_eval(&block) unless block.nil?
  end

  def loadbalancer
    @definitions["lb-001"] = Stacks::LoadBalancer.new("lb-001")
  end

  def natserver
    @definitions["nat-001"] = Stacks::NatServer.new("nat-001")
  end

  def [](key)
    return @definitions[key]
  end

end
