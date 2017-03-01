require 'stackbuilder/stacks/factory'
require 'stacks/test_framework'

describe_stack 'rabbitmq logging cluster' do
  given do
    stack 'per_site_log_collecting' do
      logstash_receiver 'logstash-receiver' do
        depend_on 'rabbitmq-logging', 'e1'
      end

      # TODO: add to custom_services, create classes, etc.
      rabbitmq_logging 'rabbitmq-logging' do
      end
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'per_site_log_collecting'
    end
  end

  it_stack 'should contain all the expected hosts' do |stack|
    expect(stack).to have_hosts([
      'e1-rabbitmq-logging-001.mgmt.space.net.local',
      'e1-rabbitmq-logging-002.mgmt.space.net.local',
      'e1-logstash-receiver-001.mgmt.space.net.local',
      'e1-logstash-receiver-002.mgmt.space.net.local'
    ])
  end

  host('e1-logstash-receiver-001.mgmt.space.net.local') do |host|
    expect(host.to_enc).to include('role::logstash_receiver')
    role_enc = host.to_enc['role::logstash_receiver']
    expect(role_enc['rabbitmq_logging_username']).to eql('logstash_receiver')
    expect(role_enc['rabbitmq_logging_password_key']).to eql('e1/logstash_receiver/messaging_password')
    expect(role_enc['rabbitmq_logging_exchange']).to eql('logging')

    # TODO: depend_on and get logging hosts
    # expect(role_enc['rabbitmq_logging_hosts']).to eql(['e1-rabbitmq-logging-001.mgmt.space.net.local', 'e1-rabbitmq-logging-002.mgmt.space.net.local'])
  end
end

describe_stack 'rabbitmq logging exchange is configurable' do
  given do
    stack 'logstash_receiver' do
      logstash_receiver 'logstash-receiver' do
        self.exchange = 'my-logging-exchange'
      end
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'logstash_receiver'
    end
  end

  host('e1-logstash-receiver-001.mgmt.space.net.local') do |host|
    expect(host.to_enc['role::logstash_receiver']['rabbitmq_logging_exchange']).to eql('my-logging-exchange')
  end
end
