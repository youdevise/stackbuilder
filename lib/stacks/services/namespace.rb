module Stacks
  module Services
    require 'stacks/services/app_server'
    require 'stacks/services/app_service'
    require 'stacks/services/bind_server'
    require 'stacks/services/ci_slave'
    require 'stacks/services/deb_repo'
    require 'stacks/services/deb_repo_mirror'
    require 'stacks/services/elasticsearch_node'
    require 'stacks/services/fmanalyticsanalysis_server'
    require 'stacks/services/fmanalyticsreporting_server'
    require 'stacks/services/legacy_mysql_cluster'
    require 'stacks/services/legacy_mysqldb_server'
    require 'stacks/services/loadbalancer'
    require 'stacks/services/loadbalancer_cluster'
    require 'stacks/services/logstash_server'
    require 'stacks/services/mail_server'
    require 'stacks/services/mongodb_cluster'
    require 'stacks/services/mongodb_server'
    require 'stacks/services/mysql_cluster'
    require 'stacks/services/mysql_server'
    require 'stacks/services/nat'
    require 'stacks/services/nat_server'
    require 'stacks/services/pentaho_server'
    require 'stacks/services/proxy_server'
    require 'stacks/services/proxy_vhost'
    require 'stacks/services/puppetmaster'
    require 'stacks/services/quantapp_server'
    require 'stacks/services/rabbitmq_server'
    require 'stacks/services/rate_limited_forward_proxy_server'
    require 'stacks/services/selenium/cluster'
    require 'stacks/services/selenium/hub'
    require 'stacks/services/sensu_server'
    require 'stacks/services/sftp_server'
    require 'stacks/services/shadow_server'
    require 'stacks/services/shadow_server_cluster'
    require 'stacks/services/shiny_server'
    require 'stacks/services/standalone_server'
    require 'stacks/services/standard_server'
    require 'stacks/services/virtual_bind_service'
    require 'stacks/services/virtual_mail_service'
    require 'stacks/services/virtual_proxy_service'
    require 'stacks/services/virtual_rabbitmq_service'
    require 'stacks/services/virtual_service'
    require 'stacks/services/virtual_sftp_service'
  end
end
