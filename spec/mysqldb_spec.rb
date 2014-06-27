require 'stacks/test_framework'



describe_stack 'should default to disallow destory' do
  given do
    stack "mysql" do
      mysqldb "mydb"
    end

    env "testing", :primary_site=>"space" do
      instantiate_stack "mysql"
    end
  end

  host("testing-mydb-001.mgmt.space.net.local") do |host|
    host.to_specs.shift[:disallow_destroy].should eql true
  end
end

describe_stack 'should allow destroy to be overwritten' do
  given do
    stack "mysql" do
      mysqldb "mydb" do
       each_machine do |machine|
          machine.allow_destroy()
        end
      end
    end
    env "testing", :primary_site=>"space" do
      instantiate_stack "mysql"
    end
  end
  host("testing-mydb-001.mgmt.space.net.local") do |host|
    host.to_specs.shift[:disallow_destroy].should eql nil
  end
end

describe_stack 'should provide correct enc data' do
  given do
    stack "mysql" do
      mysqldb "mydb" do
       self.database_name = "mydb"
       self.application = "myapp"
       each_machine do |machine|
          machine.allow_destroy()
        end
      end
    end
    env "testing", :primary_site=>"space" do
      instantiate_stack "mysql"
    end
  end
  host("testing-mydb-001.mgmt.space.net.local") do |host|
    host.to_enc.should eql({
      'role::databaseserver' => {
          'application' => 'myapp',
          'database_name' => 'mydb',
          'environment' => 'testing',
          'restart_on_config_change' => true
      }
    })
  end
end

describe_stack 'should allow storage options to be overwritten' do
  given do
    stack "mysql" do
      mysqldb "mydb" do
       self.database_name = "mydb"
       self.application = "myapp"
       each_machine do |machine|
          machine.image_size = '5G'
          machine.modify_storage({
            '/var/lib/mysql' => { :type => 'data', :size => '10G' },
          })
        end
      end
    end
    env "testing", :primary_site=>"space" do
      instantiate_stack "mysql"
    end
  end
  host("testing-mydb-001.mgmt.space.net.local") do |host|
    host.to_specs.shift[:storage]['/var/lib/mysql'.to_sym].should include(:type=>"data")
    host.to_specs.shift[:storage]['/var/lib/mysql'.to_sym].should include(:size=>"10G")
    host.to_specs.shift[:storage]['/'.to_sym].should include(:type=>"os")
    host.to_specs.shift[:storage]['/'.to_sym].should include(:size =>"5G")
  end
end
