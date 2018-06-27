require 'stackbuilder/support/namespace'
require 'stackbuilder/support/mcollective'

class Support::MCollectivePxe
  include Support::MCollective

  def prepare_for_reimage(host_mac_address, fabric)
    do_pxe_call(host_mac_address, fabric, "reprovision")
  end

  def cleanup_after_reimage(host_mac_address, fabric)
    do_pxe_call(host_mac_address, fabric, "clean")
  end

  private

  def do_pxe_call(host_mac_address, fabric, action)
    rsps = mco_client("pxe", :timeout => 10, :fabric => fabric) { |mco| mco.send(action, :mac_address => host_mac_address) }

    fail "no response to mco pxe call for fabric #{fabric}" unless rsps.size == 1
    fail "failed during mco pxe call for fabric #{fabric}: #{rsps[0][:statusmsg]}" unless rsps[0][:statuscode] == 0
    fail "mco pxe #{action} call failed for fabric #{fabric}: #{rsps[0][:data][:status]}" unless rsps[0][:data][:status] == 0

    logger(Logger::INFO) { "Successfully carried out mco pxe #{action} operation on #{rsps[0][:sender]}" }
    rsps[0][:data]
  end
end
