require 'stackbuilder/stacks/factory'
require 'test_classes'
require 'spec_helper'

describe 'kubernetes' do
  let(:app_deployer) { TestAppDeployer.new('1.2.3') }
  let(:failing_app_deployer) { TestAppDeployer.new(nil) }
  let(:dns_resolver) do
    MyTestDnsResolver.new('e1-x-vip.space.net.local' => '3.1.4.1'
                         )
  end
  let(:hiera_provider) do
    TestHieraProvider.new(
      'stacks/application_credentials_selector' => 0,
      'secrety/looking/thing' => 'ENC[GPG,hQIMAyhja+HHo',
      'kubernetes/masters/space' => ['space-kvm-001.space.net.local', 'space-kvm-005.space.net.local', 'space-kvm-010.space.net.local'])
  end

  def network_policies_for(factory, env, stack, service)
    machine_sets = factory.inventory.find_environment(env).definitions[stack].k8s_machinesets
    machine_set = machine_sets[service]

    machine_set.to_k8s(app_deployer, dns_resolver, hiera_provider).flat_map(&:resources).select do |policy|
      policy['kind'] == "NetworkPolicy"
    end
  end

  def k8s_resource(set, kind)
    set.to_k8s(app_deployer, dns_resolver, hiera_provider).flat_map(&:resources).find { |s| s['kind'] == kind }
  end

  describe 'a cronjob' do
    xit 'defines a CronJob' do
      factory = eval_stacks do
        stack "mystack" do
          cronjob_service "x", :kubernetes => true do
            self.maintainers = [person('Testers')]
            self.description = 'Testing'
            self.alerts_channel = 'test'
            self.startup_alert_threshold = '1s'

            self.application = 'MyApplication'
          end
        end
        env "e1", :primary_site => 'space' do
          instantiate_stack "mystack"
        end
      end
      set = factory.inventory.find_environment('e1').definitions['mystack'].k8s_machinesets['x']
      expected_cronjob = {
        'apiVersion' => 'batch/v1beta1',
        'kind' => 'CronJob',
        'metadata' => {
          'name' => 'x-blue-cronjob',
          'namespace' => 'e1',
          'labels' => {
            'app.kubernetes.io/managed-by' => 'stacks',
            'stack' => 'mystack',
            'machineset' => 'x',
            'group' => 'blue',
            'app.kubernetes.io/instance' => 'blue',
            'app.kubernetes.io/part-of' => 'x',
            'app.kubernetes.io/component' => 'cronjob_service',
            'application' => 'myapplication',
            'app.kubernetes.io/name' => 'myapplication',
            'app.kubernetes.io/version' => '1.2.3'
          },
          'annotations' => {
            'maintainers' => '[{"type":"Individual","name":"Testers"}]',
            'description' => 'Testing',
            'configmap.reloader.stakater.com/reload' => 'x-blue-cronjob',
            'secret.reloader.stakater.com/reload' =>  'x-blue-cronjob'
          }
        },
        'spec' => {
          'concurrencyPolicy' => 'Forbid',
          'failedJobsHistoryLimit' => 10,
          'schedule' => '*/1 * * * *',
          'jobTemplate' => {
            'spec' => {
              'backoffLimit' => 0,
              'template' => {
                'metadata' => {
                  'labels' => {
                    'app.kubernetes.io/managed-by' => 'stacks',
                    'stack' => 'mystack',
                    'machineset' => 'x',
                    'group' => 'blue',
                    'app.kubernetes.io/instance' => 'blue',
                    'app.kubernetes.io/part-of' => 'x',
                    'app.kubernetes.io/component' => 'cronjob_service',
                    'application' => 'myapplication',
                    'app.kubernetes.io/name' => 'myapplication',
                    'app.kubernetes.io/version' => '1.2.3'
                  }
                },
                'spec' => {
                  'initContainers' => [{
                    'image' => 'repo.net.local:8080/timgroup/config-generator:1.0.13',
                    'name' => 'config-generator',
                    'env' => [
                      {
                        'name' => 'CONTAINER_IMAGE',
                        'value' => 'repo.net.local:8080/timgroup/myapplication:1.2.3'
                      },
                      {
                        'name' => 'APP_JVM_ARGS',
                        'value' => '-XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -Xms64M -Xmx64M'
                      },
                      {
                        'name' => 'BASE_JVM_ARGS',
                        'value' => "-Djava.awt.headless=true -Dfile.encoding=UTF-8 -XX:ErrorFile=/var/log/app/error.log \
    -XX:HeapDumpPath=/var/log/app -XX:+HeapDumpOnOutOfMemoryError -Djava.security.egd=file:/dev/./urandom -Dcom.sun.management.jmxremote \
    -Dcom.sun.management.jmxremote.port=5000 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false \
    -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=5000 -Djava.rmi.server.hostname=127.0.0.1 \
    -Dcom.timgroup.infra.platform=k8s"
                      },
                      {
                        'name' => 'GC_JVM_ARGS_JAVA_8',
                        'value' => "-XX:+PrintGC -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps -XX:+PrintGCDetails \
    -Xloggc:/var/log/app/gc.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=25M \
    -XX:+PrintGCApplicationStoppedTime"
                      },
                      {
                        'name' => 'GC_JVM_ARGS_JAVA_11',
                        'value' => '-Xlog:gc*,safepoint:/var/log/app/gc.log:time,uptime,level,tags:filecount=10,filesize=26214400'
                      }
                    ],
                    'volumeMounts' => [
                      {
                        'name' => 'config-volume',
                        'mountPath' => '/config'
                      },
                      {
                        'name' => 'config-template',
                        'mountPath' => '/input/config.properties',
                        'subPath' => 'config.properties'
                      }]
                  }],
                  'containers' => [{
                    'securityContext' => {
                      'readOnlyRootFilesystem' => true,
                      'allowPrivilegeEscalation' => false,
                      'capabilities' => {
                        'drop' => ['ALL']
                      }
                    },
                    'image' => 'repo.net.local:8080/timgroup/myapplication:1.2.3',
                    'name' => 'myapplication',
                    'command' => ["/bin/sh"],
                    'args' => [
                      '-c',
                      'exec /usr/bin/java $(cat /config/jvm_args) -jar /app/app.jar /config/config.properties'
                    ],
                    'ports' => [
                      {
                        'containerPort' => 5000,
                        'name' => 'jmx'
                      }
                    ],
                    'volumeMounts' => [
                      {
                        'name' => 'tmp-volume',
                        'mountPath' => '/tmp'
                      },
                      {
                        'name' => 'config-volume',
                        'mountPath' => '/config',
                        'readOnly' => true
                      }
                    ]
                  }],
                  'volumes' => [
                    {
                      'name' => 'tmp-volume',
                      'emptyDir' => {}
                    },
                    {
                      'name' => 'config-volume',
                      'emptyDir' => {}
                    },
                    {
                      'name' => 'config-template',
                      'configMap' => {
                        'name' => 'x-blue-app'
                      }
                    }
                  ]
                }
              }
            }
          }
        }
      }
      expect(k8s_resource(set, 'CronJob')).to eql(expected_cronjob)

      expected_config_map = {
        'apiVersion' => 'v1',
        'kind' => 'ConfigMap',
        'metadata' => {
          'name' => 'x-blue-cronjob',
          'namespace' => 'e1',
          'labels' => {
            'app.kubernetes.io/managed-by' => 'stacks',
            'stack' => 'mystack',
            'machineset' => 'x',
            'group' => 'blue',
            'app.kubernetes.io/instance' => 'blue',
            'app.kubernetes.io/part-of' => 'x',
            'app.kubernetes.io/component' => 'cronjob_service'
          }
        },
        'data' => {
          'config.properties' => <<EOL
port=8000

log.directory=/var/log/app
log.tags=["env:e1", "app:MyApplication", "instance:blue"]
EOL
        }
      }
      expect(k8s_resource(set, 'ConfigMap')).to eql(expected_config_map)

      k8s_resources = set.to_k8s(app_deployer, dns_resolver, hiera_provider).first.resources
      k8s_resources.group_by { |r| r['metadata']['labels']['app.kubernetes.io/component'] }.each do |_component, resources|
        ordering = {}
        resources.each_with_index do |s, index|
          ordering[s['kind']] = index
        end
        if %w(ConfigMap CronJob).all? { |k| ordering.key? k }
          expect(ordering['ConfigMap']).to be < ordering['CronJob']
        end
      end
    end
  end
end
