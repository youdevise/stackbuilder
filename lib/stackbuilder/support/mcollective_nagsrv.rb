require 'stackbuilder/support/namespace'
require 'stackbuilder/support/mcollective'

class Support::MCollectiveNagsrv
  include Support::MCollective

  def schedule_downtime(fqdn, fabric, duration)
    logger(Logger::DEBUG) { "Scheduling downtime for #{fqdn}" }
    mco_client("nagsrv", :fabric => fabric) do |mco|
      mco.class_filter('nagios')
      mco.schedule_host_downtime(:host => fqdn, :duration => duration).map do |response|
        "#{response[:sender]} = #{response[:statuscode] == 0 ? 'OK' : 'Failed'}: #{response[:statusmsg]}"
      end
    end.join(',')
  end

  def cancel_downtime(fqdn, fabric)
    logger(Logger::DEBUG) { "Cancelling downtime for #{fqdn}" }
    mco_client("nagsrv", :fabric => fabric) do |mco|
      mco.class_filter('nagios')
      mco.del_host_downtime(:host => fqdn).map do |response|
        "#{response[:sender]} = #{response[:statuscode] == 0 ? 'OK' : 'Failed'}: #{response[:statusmsg]}"
      end.join(',')
    end
  end

  def force_checks(fqdn, fabric)
    logger(Logger::DEBUG) { "Forcing all nagios checks for #{fqdn}" }
    mco_client("nagsrv", :fabric => fabric) do |mco|
      mco.class_filter('nagios')
      resps = mco.schedule_forced_host_check(:host => fqdn) + mco.schedule_forced_host_svc_checks(:host => fqdn)
      resps.map do |response|
        "#{response[:sender]} = #{response[:statuscode] == 0 ? 'OK' : 'Failed'}: #{response[:statusmsg]}"
      end.uniq.join(',')
    end
  end
end
