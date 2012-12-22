require 'set'
require 'stacks/environment'


describe "ENC::DSL" do

  it 'generates an entry for the full stack of boxes' do
    extend Stacks
    env = env "blah" do
      stack "appx" do
        loadbalancer "lb"
        virtualservice "appx"
        virtualservice "dbx"
      end
    end

    env.generate()

    Set.new(env.collapse_registries.keys).should eql(Set.new([
                                                             "blah-lb-001",
                                                             "blah-lb-002",
                                                             "blah-appx-001",
                                                             "blah-appx-002",
                                                             "blah-dbx-001",
                                                             "blah-dbx-002"
    ]))
  end

  it 'works with some services in different environments' do
    extend Stacks
    env = env "a" do
      stack "infra" do
        loadbalancer "lb"
      end
      env "b" do
        stack "appx" do
          virtualservice "appx", :type=>:appserver,:depends_on=>"dbx"
          virtualservice "dbx", :type=>:dbserver
        end
      end
    end
    env.generate()
    Set.new(env.collapse_registries.keys).should eql(Set.new([
                                                             "a-lb-001",
                                                             "a-lb-002",
                                                             "b-appx-001",
                                                             "b-appx-002",
                                                             "b-dbx-001",
                                                             "b-dbx-002"
    ]))
  end

  it 'allows us to duplicate the same stack over multiple environments' do
    extend Stacks
    stack "appx" do
      virtualservice "appx"
      virtualservice "dbx"
    end

    env = env "a" do
      stack "infra" do
        loadbalancer "lb"
      end
      env "b" do
        stack "appx"
      end
      env "c" do
        stack "appx"
      end
    end
    env.generate()

    Set.new(env.collapse_registries.keys).should eql(Set.new([
                                                             "a-lb-001",
                                                             "a-lb-002",
                                                             "b-appx-001",
                                                             "b-appx-002",
                                                             "b-dbx-001",
                                                             "b-dbx-002",
                                                             "c-appx-001",
                                                             "c-appx-002",
                                                             "c-dbx-001",
                                                             "c-dbx-002"   ]))

  end

  it 'roles are reflected in the defined classes' do
    extend Stacks
    stack "appx" do
      virtualservice "appx", :type=>:appserver
      virtualservice "dbx", :type=>:dbserver
    end

    env = env "a" do
      stack "infra" do
        loadbalancer "lb"
      end
      env "b" do
        stack "appx"
      end
      env "c" do
        stack "appx"
      end
    end
    env.generate()

    env.collapse_registries["a-lb-001"].to_spec.should eql({
      :hostname=>"a-lb-001",
      :domain=>"dev.net.local",
      :env=>"dev",
      :template=>"seedapply",
      :enc=>{
      "classes"=>{
      "base"=>nil,
      "mcollective"=>nil,
      "puppetagent"=>{
      "puppetmaster"=>"dev-puppetmaster-001.dev.net.local"
    },
    },
    },
    :master_enc=>{
      "classes"=>{
      "base"=>nil,
      "loadbalancer"=>nil
    }}})

    env.collapse_registries["b-appx-001"].to_spec.should eql({
      :hostname=>"b-appx-001",
      :domain=>"dev.net.local",
      :env=>"dev",
      :template=>"seedapply",
      :enc=>{
      "classes"=>{
      "base"=>nil,
      "mcollective"=>nil,
      "puppetagent"=>{
      "puppetmaster"=>"dev-puppetmaster-001.dev.net.local"
    },
    },
    },
    :master_enc=>{
      "classes"=>{
      "base"=>nil,
      "appserver"=>{
      "environment"=>"b",
      "application"=>"appx",
      "dependencies"=>{}
    }
    }}})

    env.collapse_registries["b-dbx-001"].to_spec.should eql({
      :hostname=>"b-dbx-001",
      :domain=>"dev.net.local",
      :env=>"dev",
      :template=>"seedapply",
      :enc=>{
      "classes"=>{
      "base"=>nil,
      "mcollective"=>nil,
      "puppetagent"=>{
      "puppetmaster"=>"dev-puppetmaster-001.dev.net.local"
    },
    },
    },
    :master_enc=>{
      "classes"=>{
      "base"=>nil,
      "dbserver"=>{
      "environment"=>"b",
      "application"=>"dbx",
      "dependencies"=>{}
    }
    }}})
  end

  it 'roles are reflected in the defined classes' do
    extend Stacks
    stack "appx" do
      virtualservice "appx"
      virtualservice "dbx"
    end

    env = env "a" do
      stack "infra" do
        loadbalancer "lb"
      end
      env "b" do
        stack "appx"
      end
      env "c" do
        stack "appx"
      end
    end
    env.generate()

    Set.new(env.collapse_registries.keys).should eql(Set.new([
                                                             "a-lb-001",
                                                             "a-lb-002",
                                                             "b-appx-001",
                                                             "b-appx-002",
                                                             "b-dbx-001",
                                                             "b-dbx-002",
                                                             "c-appx-001",
                                                             "c-appx-002",
                                                             "c-dbx-001",
                                                             "c-dbx-002"   ]))


  end

  it 'wires in the vip url of the service dependencies' do
    extend Stacks
    env = env "a" do
      self.domain="dev.net.local"

      stack "all" do
        loadbalancer "lb"
        virtualservice "dbx"
        virtualservice "appx" do
          self.dependencies=["dbx"]
        end
      end
    end

    env.generate()
    env.collapse_registries["a-appx-001"].to_spec[:master_enc]["classes"]["appserver"]["dependencies"].should eql({"dbx"=>"a-dbx-vip.dev.net.local"})
  end

  it 'puts domain names in as fqdn'

  it 'allows us to list all the machines in a stack' do
    extend Stacks
    env "a" do
      stack "infra" do
        puppetmaster
      end
    end

    env.stacks['infra'].machines.keys.should eql(
      "a-puppetmaster-001"
    )

    env.generate()
  end

  it 'produces a puppetmaster' do
    extend Stacks
    env = env "a" do
      stack "infra" do
        puppetmaster
      end
    end
    env.generate()

    puppetmaster_object = env.collapse_registries["a-puppetmaster-001"]

    puppetmaster_object.to_spec[:enc].should eql({
      "classes"=>{
      "rabbitmq" =>nil,
      "mcollective"=> nil,
      "puppetmaster"=>nil
    }})

    puppetmaster_object.to_spec[:networks].should eql(
      [
        "mgmt",
        "prod",
        "front"])

    puppetmaster_object.to_spec[:aliases].should eql(
      [
        "puppet",
        "broker"])

    puppetmaster_object.to_spec[:hostname].should eql("a-puppetmaster-001")
    puppetmaster_object.to_spec[:image_size].should eql '10G'
  end

  it 'HA pairs are assigned to different zones'
  def ignore
    extend Stacks
    env = env "a" do
      stack "infra" do
        loadbalancer "lb"
      end
    end
    env.generate()
    env.collapse_registries["a-lb-001"].to_spec[:enc][:zone].should eql("primary.a")
    env.collapse_registries["a-lb-002"].to_spec[:enc][:zone].should eql("primary.b")
  end

  it 'crosssite db slaves should be marked with correct zone' do
  end
end
