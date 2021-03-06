require 'stackbuilder/stacks/factory'
require 'stacks/test_framework'

describe_stack 'basic rabbitmq cluster' do
  given do
    stack 'rabbit' do
      rabbitmq_cluster 'rabbitmq'
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'rabbit'
    end
  end

  host('e1-rabbitmq-001.mgmt.space.net.local') do |host|
    expect(host.to_enc['role::rabbitmq_server']['vip_fqdn']).to eql('e1-rabbitmq-vip.space.net.local')
    expect(host.to_enc['role::rabbitmq_server']['cluster_nodes']).to eql(['e1-rabbitmq-001', 'e1-rabbitmq-002'])
    expect(host.to_enc['role::rabbitmq_server']['dependant_instances']).to include(
      'e1-rabbitmq-002.space.net.local')
    expect(host.to_enc['role::rabbitmq_server']['dependant_instances']).not_to include(
      'e1-rabbitmq-001.space.net.local')
    expect(host.to_enc['role::rabbitmq_server']['dependencies']).to be_empty
    expect(host.to_enc['role::rabbitmq_server']['users']).to be_nil
    expect(host.to_enc.key?('server')).to eql true
  end
end

describe_stack 'app without requirement' do
  given do
    stack 'rabbit' do
      rabbitmq_cluster 'rabbitmq'
    end

    stack 'example' do
      app_service 'exampleapp' do
        depend_on 'rabbitmq'
      end
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'rabbit'
      instantiate_stack 'example'
    end
  end

  host('e1-exampleapp-001.mgmt.space.net.local') do |host|
    expect { host.to_enc }.to raise_error(RuntimeError)
  end
end

describe_stack 'app with rabbitmq dependency' do
  given do
    stack 'test' do
      rabbitmq_cluster 'rabbitmq'
      app_service 'exampleapp' do
        self.application = 'example'
        depend_on 'rabbitmq', 'e1', :magic
      end
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'test'
    end
  end

  host('e1-exampleapp-001.mgmt.space.net.local') do |host|
    dependencies = host.to_enc['role::http_app']['dependencies']
    expect(dependencies['magic.messaging.enabled']).to eql('true')
    expect(dependencies['magic.messaging.broker_fqdns']).to \
      eql('e1-rabbitmq-001.space.net.local,e1-rabbitmq-002.space.net.local')
    expect(dependencies['magic.messaging.username']).to eql('example')
    expect(dependencies['magic.messaging.password_hiera_key']).to eql('e1/example/messaging_password')
  end

  host('e1-rabbitmq-001.mgmt.space.net.local') do |host|
    expect(host.to_enc['role::rabbitmq_server']['dependant_instances']).to include(
      'e1-exampleapp-001.space.net.local',
      'e1-exampleapp-002.space.net.local',
      'e1-rabbitmq-002.space.net.local')
    expect(host.to_enc['role::rabbitmq_server']['dependant_instances']).not_to include(
      'e1-rabbitmq-001.space.net.local')
  end
end

describe_stack 'when a k8s app is a dependant the cluster appears in the enc' do
  given do
    stack 'test' do
      rabbitmq_cluster 'rabbitmq'
      app_service 'exampleapp', :kubernetes => true do
        self.application = 'example'
        self.maintainers = [person('Testers')]
        self.description = 'Testing'
        depend_on 'rabbitmq', 'e1', :magic
      end
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'test'
    end
  end

  host('e1-rabbitmq-001.mgmt.space.net.local') do |host|
    expect(host.to_enc['role::rabbitmq_server']['allow_kubernetes_clusters']).to include(
      'space')
  end
end

describe_stack 'rabbitmq users are created from dependencies' do
  given do
    stack 'test' do
      rabbitmq_cluster 'rabbitmq'
      app_service 'exampleapp' do
        self.application = 'example'
        depend_on 'rabbitmq', 'e1', :wizard
        depend_on 'rabbitmq', 'e1', :magic
      end
      app_service 'eggapp' do
        self.application = 'egg'
        depend_on 'rabbitmq', 'e1', :spoon
      end
      external_service 'oy-mon-001.oy.net.local' do
        depend_on 'rabbitmq', 'e1', 'external'
      end
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'test'
    end
  end

  host('e1-exampleapp-001.mgmt.space.net.local') do |host|
    dependencies = host.to_enc['role::http_app']['dependencies']
    expect(dependencies['magic.messaging.username']).to eql('example')
    expect(dependencies['magic.messaging.password_hiera_key']).to eql('e1/example/messaging_password')
    expect(dependencies['wizard.messaging.username']).to eql('example')
    expect(dependencies['wizard.messaging.password_hiera_key']).to eql('e1/example/messaging_password')
  end

  host('e1-eggapp-001.mgmt.space.net.local') do |host|
    dependencies = host.to_enc['role::http_app']['dependencies']
    expect(dependencies['spoon.messaging.username']).to eql('egg')
    expect(dependencies['spoon.messaging.password_hiera_key']).to eql('e1/egg/messaging_password')
  end

  host('e1-rabbitmq-001.mgmt.space.net.local') do |host|
    expect(host.to_enc['role::rabbitmq_server']['dependant_users']).to include 'example', 'egg'
    expect(host.to_enc['role::rabbitmq_server']['dependant_users']['example']).to eql(
      'password_hiera_key' => 'e1/example/messaging_password',
      'tags'               => []
    )
    expect(host.to_enc['role::rabbitmq_server']['dependant_users']['egg']).to eql(
      'password_hiera_key' => 'e1/egg/messaging_password',
      'tags'               => []
    )
  end
end

describe_stack 'rabbitmq users are created from dependencies for any service mixing in rabbitmq dependent trait' do
  given do
    stack 'test' do
      rabbitmq_cluster 'rabbitmq'
      standard_service 'standard' do
        extend(Stacks::Services::RabbitMqDependent)
        configure_rabbitmq('my_rabbitmq_username')
        depend_on 'rabbitmq', 'e1', :wizard
      end
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'test'
    end
  end

  host('e1-rabbitmq-001.mgmt.space.net.local') do |host|
    expect(host.to_enc['role::rabbitmq_server']['dependant_users']).to include 'my_rabbitmq_username'
    expect(host.to_enc['role::rabbitmq_server']['dependant_users']['my_rabbitmq_username']).
      to eql(
        'password_hiera_key' => 'e1/my_rabbitmq_username/messaging_password',
        'tags'               => []
      )
  end
end

describe_stack 'rabbitmq users are not created unless services have application' do
  given do
    stack 'test' do
      rabbitmq_cluster 'rabbitmq'
      external_service 'oy-mon-001.oy.net.local' do
        depend_on 'rabbitmq', 'e1', 'external'
      end
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'test'
    end
  end

  host('e1-rabbitmq-001.mgmt.space.net.local') do |host|
    expect(host.to_enc['role::rabbitmq_server']['dependant_users']).to be_empty
  end
end

describe_stack 'applications can depend on rabbitmq clusters in different environments' do
  given do
    stack 'rabbit' do
      rabbitmq_cluster 'rabbitmq'
    end
    stack 'depends_on_rabbit' do
      app_service 'exampleapp' do
        self.application = 'example'
        depend_on 'rabbitmq', 'e1', :wizard
        depend_on 'rabbitmq', 'e2', :magic
      end
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'rabbit'
    end
    env 'e2', :primary_site => 'space' do
      instantiate_stack 'rabbit'
    end
    env 'e3', :primary_site => 'space' do
      instantiate_stack 'depends_on_rabbit'
    end
  end

  host('e3-exampleapp-001.mgmt.space.net.local') do |host|
    dependencies = host.to_enc['role::http_app']['dependencies']
    expect(dependencies['wizard.messaging.broker_fqdns']).to \
      eql('e1-rabbitmq-001.space.net.local,e1-rabbitmq-002.space.net.local')
    expect(dependencies['magic.messaging.broker_fqdns']).to \
      eql('e2-rabbitmq-001.space.net.local,e2-rabbitmq-002.space.net.local')
  end
end

describe_stack 'produces the correct loadbalancer config' do
  given do
    stack "lb" do
      loadbalancer_service
    end

    stack 'rabbit' do
      rabbitmq_cluster 'rabbitmq'
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'lb'
      instantiate_stack 'rabbit'
    end
  end

  host('e1-lb-001.mgmt.space.net.local') do |host|
    enc = host.to_enc['role::loadbalancer']['virtual_servers']['e1-rabbitmq-vip.space.net.local']
    expect(enc['type']).to eql('rabbitmq')
    expect(enc['ports']).to eql([5672])
    expect(enc['realservers']).to eql("blue" => ["e1-rabbitmq-001", "e1-rabbitmq-002"])
  end
end
