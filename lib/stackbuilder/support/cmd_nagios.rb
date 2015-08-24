require 'stackbuilder/support/cmd'

module CMDNagios
  def self.nagios(argv)
    cmd = argv.shift
    if cmd.nil? then
      logger(Logger::FATAL) { 'nagios needs a subcommand' }
      exit 1
    end

    machine_def = Opt.stack

    case cmd
    when 'disable'
      schedule_downtime(machine_def)
    when 'enable'
      cancel_downtime(machine_def)
    else
      logger(Logger::FATAL) { "invalid command \"#{cmd}\"" }
      exit 1
    end
  end

  private

  def self.schedule_downtime(machine_def)
    hosts = []
    machine_def.accept do |child_machine_def|
      hosts << child_machine_def if child_machine_def.respond_to?(:mgmt_fqdn)
    end

    nagios_helper = Support::Nagios::Service.new
    downtime_secs = 1800 # 1800 = 30 mins
    nagios_helper.schedule_downtime(hosts, downtime_secs) do
      on :success do |response_hash|
        logger(Logger::INFO) do
          "successfully scheduled #{downtime_secs} seconds downtime for #{response_hash[:machine]} " \
          "result: #{response_hash[:result]}"
        end
      end
      on :failed do |response_hash|
        logger(Logger::INFO) do
          "failed to schedule #{downtime_secs} seconds downtime for #{response_hash[:machine]} " \
          "result: #{response_hash[:result]}"
        end
      end
    end
  end

  def self.cancel_downtime(machine_def)
    hosts = []
    machine_def.accept do |child_machine_def|
      hosts << child_machine_def if child_machine_def.respond_to?(:mgmt_fqdn)
    end

    nagios_helper = Support::Nagios::Service.new
    nagios_helper.cancel_downtime(hosts) do
      on :success do |response_hash|
        logger(Logger::INFO) do
          "enabled nagios for #{response_hash[:machine]} " \
          "result: #{response_hash[:result]}"
        end
      end
      on :failed do |response_hash|
        logger(Logger::INFO) do
          "failed to cancel downtime for #{response_hash[:machine]} " \
          "result: #{response_hash[:result]}"
        end
      end
    end
  end
end
