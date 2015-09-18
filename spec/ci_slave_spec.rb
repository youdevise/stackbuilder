require 'stackbuilder/stacks/factory'
require 'stacks/test_framework'

describe_stack 'jenkins' do
  given do
    stack 'jenkins' do
      cislave 'jenkinsslave' do
        each_machine do |machine|
          machine.vcpus = '8'
          machine.modify_storage('/'.to_sym => { :size => '10G' })
          machine.ram = '8000'
        end
      end

      cislave 'jenkinsslavewithlabels' do
        each_machine do |machine|
          machine.node_labels = %w(first_label second_label)
        end
      end
    end

    env 'e1', :primary_site => 'space' do
      instantiate_stack 'jenkins'
    end
  end

  host('e1-jenkinsslave-002.mgmt.space.net.local') do |host|
    host.to_enc.should eql('role::cinode_precise' => {
                             'mysql_version' => '5.1.49-1ubuntu8',
                             'node_labels'   => []
                           })
  end

  host('e1-jenkinsslavewithlabels-001.mgmt.space.net.local') do |host|
    host.to_enc['role::cinode_precise']['node_labels'].should eql(%w(first_label second_label))
  end
end
