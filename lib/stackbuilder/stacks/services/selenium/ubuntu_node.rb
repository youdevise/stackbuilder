require 'stackbuilder/stacks/services/selenium/namespace'

class Stacks::Services::Selenium::UbuntuNode < Stacks::MachineDef
  attr_reader :hub
  attr_reader :options

  def initialize(base_hostname, hub, options)
    super(base_hostname, [:mgmt])
    @hub = hub
    @options = options
  end

  def bind_to(environment)
    super(environment)
  end

  def to_spec
    spec = super
    spec[:template] = "senode"
    spec[:selenium_hub_host] = hub.mgmt_fqdn unless hub.nil?
    spec[:selenium_version] = options[:selenium_version] || "2.32.0"
    spec[:firefox_version] = options[:firefox_version]

    spec
  end
end
