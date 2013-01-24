require 'support/mcollective'

describe Support::MCollective do
  before do
    extend Support::MCollective
    @mock_rpcclient = double
    class Support::MCollective::MCollectiveRPC

      def self.mco_options
        return @@mco_options
      end


      def self.rpcclient=(rpcclient)
        @@rpcclient = rpcclient
      end
      def rpcclient(name, options)
        @@mco_options = options
        return @@rpcclient
      end
    end
    Support::MCollective::MCollectiveRPC.rpcclient=@mock_rpcclient

    def async_fork_and_return(&block)
      return Support::Forking::Future.new(&block)
    end

    @mock_rpcclient.should_receive(:disconnect)
  end

  it 'shortcuts a nested new_client' do
    @mock_rpcclient.should_receive(:discover).with(no_args)
    new_client("blah") do |mco|
      mco.should eql(@mock_rpcclient)
    end
  end

  it 'applies a filter so that only machines in the fabric are addressed' do
    @mock_rpcclient.should_receive(:discover).with(no_args)
    @mock_rpcclient.should_receive(:fact_filter).with("domain", "mgmt.st.net.local")
    new_client("blah", :fabric => "st") do |mco|
    end
  end

  it 'applies a filter so that only local machines are addressed' do
    @mock_rpcclient.should_receive(:discover).with(no_args).ordered
    @mock_rpcclient.should_receive(:identity_filter).with(`hostname --fqdn`.chomp)
    new_client("blah", :fabric => "local") do |mco|
    end
  end

  it 'uses a timeout if supplied' do
    @mock_rpcclient.should_receive(:discover).with(no_args).ordered
    @mock_rpcclient.should_receive(:identity_filter).with(`hostname --fqdn`.chomp)
    new_client("blah", :fabric => "local", :timeout=>44) do |mco|
    end
    Support::MCollective::MCollectiveRPC.mco_options[:options][:timeout].should eql(44)
  end

  it 'can be pre-injected with a list of hosts to discover' do
    my_nodes = ["1","2","3"]
    @mock_rpcclient.should_receive(:discover).with({:nodes => my_nodes})
    new_client("blah", :nodes => my_nodes) do |fabric, mco|
    end
  end
end
