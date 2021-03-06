require 'stackbuilder/support/namespace'
require 'stackbuilder/support/forking'
require 'stackbuilder/support/logger'
require 'mcollective'
require 'mcollective/pluginmanager'

module Support::MCollective
  include ::Support::Forking

  class MCollectiveFabricRunner
    def initialize(options)
      if options.key? :key
        ::MCollective::PluginManager.clear
        @config = ::MCollective::Config.instance
        config_file = options[:config_file] || "/etc/mcollective/client.cfg"
        @config.loadconfig(config_file)
        ENV.delete('MCOLLECTIVE_SSL_PRIVATE')
        ENV.delete('MCOLLECTIVE_SSL_PUBLIC')
        @config.pluginconf["ssl_client_public"] = "/etc/mcollective/ssl/#{options[:key]}.pem"
        @config.pluginconf["ssl_client_private"] = File.expand_path "~/.mc/#{options[:key]}-private.pem"
      end
      @rpc = MCollectiveRPC.new
      @options = options
      @mco_options = ::MCollective::Util.default_options
      @mco_options[:disctimeout] = 5 # Facter can take aaages to respond
      @mco_options[:timeout] = options[:timeout] if options.key?(:timeout)
    end

    def new_client(name)
      client = @rpc.rpcclient(name, :options => @mco_options)
      apply_fabric_filter client, @options[:fabric] if @options.key?(:fabric)
      LoggingMcoRpcClientProxy.new(name, client)
    end

    def apply_fabric_filter(mco, fabric)
      if fabric == "local"
        ENV['FACTERLIB'] = "/var/lib/puppet/lib/facter:/var/lib/puppet/facts"
        if (OwnerFact.owner_fact != "")
          mco.fact_filter "owner", OwnerFact.owner_fact
        end
      else
        mco.fact_filter "domain", "mgmt.#{fabric}.net.local"
      end
    end

    def configure_mco
      # dump hard earnt knowledge about how to configure mcollective programmatically, TODO: test and tidy
      broker = options[:broker]
      timeout = options[:timeout]
      config_file = options[:config_file] || "/etc/mcollective/client.cfg"
      key = options[:key] || nil

      ENV.delete('MCOLLECTIVE_SSL_PRIVATE') unless key.nil?
      ENV.delete('MCOLLECTIVE_SSL_PUBLIC') unless key.nil?

      @config = ::MCollective::Config.instance
      @config.loadconfig(config_file)

      @config.pluginconf["stomp.pool.host1"] = broker unless broker.nil?
      @config.pluginconf["timeout"] = timeout unless timeout.nil?
    end
  end

  class MCollectiveRPC
    include ::MCollective::RPC
  end

  class LoggingMcoRpcClientProxy < BasicObject
    def initialize(rpcName, rpcClient)
      @rpc_name = rpcName
      @rpc_client = rpcClient
    end

    private

    def method_missing(method, *args, &block)
      ::Kernel.logger(::Logger::DEBUG) { "making mco rpc call #{@rpc_name} #{method} #{args}" }
      @rpc_client.send(method, *args, &block)
    end
  end

  private

  def create_fabric_runner(options)
    MCollectiveFabricRunner.new(options)
  end

  # block can be nil
  def mco_client(name, options = {}, &block)
    # N.B. we always fork mco clients because the mco rpc relies on global shared state, so we need to sandbox
    # (learned this following a conversation with david)
    async_mco_client(name, options, &block).value
  end

  # block can be nil
  def async_mco_client(name, options = {}, &block)
    async_fork_and_return do
      runner = create_fabric_runner(options)
      client = runner.new_client(name)
      nodes = options[:nodes] || []
      nodes.empty? ? client.discover : client.discover(:nodes => nodes)
      retval = block.nil? ? nil : block.call(client)
      client.disconnect
      retval
    end
  end
end
