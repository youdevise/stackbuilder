require 'stackbuilder/support/namespace'
require 'stackbuilder/support/mcollective'

class Support::MCollectiveHpilo
  include Support::MCollective

  def update_ilo_firmware(host_fqdn, fabric)
    do_hpilo_call(fabric, "update_rib_firmware", :host_fqdn => host_fqdn, :version => "latest")
  end

  def set_one_time_network_boot(host_fqdn, fabric)
    do_hpilo_call(fabric, "set_one_time_boot", :host_fqdn => host_fqdn, :device => "network")
  end

  def power_off_host(host_fqdn, fabric)
    do_hpilo_call(fabric, "power_off", :host_fqdn => host_fqdn)
    while get_host_power_status(host_fqdn, fabric) == 'ON'
      sleep 2
    end
  end

  def power_on_host(host_fqdn, fabric)
    do_hpilo_call(fabric, "power_on", :host_fqdn => host_fqdn)
    while get_host_power_status(host_fqdn, fabric) == 'OFF'
      sleep 2
    end
  end

  def get_host_power_status(host_fqdn, fabric)
    result = do_hpilo_call(fabric, "power_status", :host_fqdn => host_fqdn)
    result[:power]
  end

  def get_mac_address(host_fqdn, fabric)
    result = do_hpilo_call(fabric, "get_host_data", :host_fqdn => host_fqdn)
    result[:mac_address]
  end

  private

  def do_hpilo_call(fabric, action, args_hash)
    rsps = mco_client("hpilo", :timeout => 10, :fabric => fabric) { |mco| mco.send(action, args_hash) }

    fail "no respose to mco hpilo call for fabric #{fabric}" unless rsps.size == 1
    fail "failed during mco hpilo call for fabric #{fabric}: #{rsps[0][:statusmsg]}" unless rsps[0][:statuscode] == 0
    fail "mco hpilo #{action} call failed for fabric #{fabric}: #{rsps[0][:data][:status]}" unless rsps[0][:data][:status] == 0

    logger(Logger::INFO) { "Successfully carried out mco hpilo #{action} operation on #{rsps[0][:sender]}" }
    rsps[0][:data]
  end
end
