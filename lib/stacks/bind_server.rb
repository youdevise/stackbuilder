require 'stacks/namespace'
require 'stacks/machine_def'

class Stacks::BindServer < Stacks::MachineDef

  attr_reader :environment, :virtual_service

  def initialize(base_hostname, virtual_service, role, index, &block)
    @role = role
    super(base_hostname, [:mgmt,:prod], :primary_site)
    @virtual_service = virtual_service
  end

  def role
    @role
  end

  def master?
    @role == :master
  end

  def slave?
    @role == :slave
  end

  def bind_to(environment)
    super(environment)
  end

  def vip_fqdn(net)
    return @virtual_service.vip_fqdn(net)
  end

  def slave_from(env)
    @virtual_service.depend_on('ns', env)
  end

  public
  def to_enc()
    dependant_zones = @virtual_service.bind_master_servers_and_zones_that_i_depend_on

    enc = super()
    enc.merge!({
      'role::bind_server' => {
        'vip_fqdns'                         => [ vip_fqdn(:prod), vip_fqdn(:mgmt)],
        'participation_dependant_instances' => @virtual_service.dependant_load_balancer_machine_def_fqdns([:mgmt,:prod]),
        'dependant_instances'               => @virtual_service.all_dependencies(self),
        'forwarder_zones'                   => @virtual_service.forwarder_zones,
        'slave_zones'                       => @virtual_service.slave_zones_fqdn(self)
      },
      'server::default_new_mgmt_net_local'  => nil,
    })
    enc['role::bind_server']['master_zones'] = @virtual_service.zones_fqdn if master?

    if enc['role::bind_server']['slave_zones'].nil?
      enc['role::bind_server']['slave_zones'] = dependant_zones
    else
      enc['role::bind_server']['slave_zones'].merge! dependant_zones unless dependant_zones.nil?
    end

    enc
  end
end
