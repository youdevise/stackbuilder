require 'stackbuilder/stacks/services/selenium/namespace'

class Stacks::Services::Selenium::XpNode < Stacks::MachineDef
  attr_reader :hub
  attr_reader :options

  def initialize(base_hostname, hub, options)
    @base_hostname = base_hostname
    @networks = [:mgmt]
    @hub = hub
    @options = options
    @routes = []
    @location = :primary_site
    @added_cnames = []
    @destroyable = true
    @ram = "2097152"
    @allocation_tags = []
    @storage = {
      '/'.to_sym =>  {
        :type        => 'os',
        :size        => '8G',
        :prepare     => {
          :method => 'image',
          :options => {
            :path => '/var/local/images/gold-precise/generic.img'
          }
        }
      }
    }
  end

  def to_enc
    super
    {}
  end

  def to_spec
    spec = super
    spec[:template] = "senode_xp"
    spec[:kvm_template] = 'kvm_no_virtio'
    spec[:gold_image_url] = options[:gold_image] # TODO: delete me
    spec[:selenium_hub_host] = hub.mgmt_fqdn unless hub.nil?
    # TODO: Remove default once refstack has been updated to pass in :ie_version
    spec[:selenium_version] = options[:selenium_version] || "2.32.0"
    spec[:ie_version] = options[:ie_version]
    spec[:storage]['/'.to_sym][:prepare] = {} if spec[:storage]['/'.to_sym][:prepare].nil?
    spec[:storage]['/'.to_sym][:prepare][:options] = {} if spec[:storage]['/'.to_sym][:prepare][:options].nil?
    spec[:storage]['/'.to_sym][:prepare][:options][:resize] = false
    spec[:storage]['/'.to_sym][:prepare][:options][:path] = options[:gold_image]
    spec[:storage]['/'.to_sym][:prepare][:options][:create_in_fstab] = false
    spec[:storage]['/'.to_sym][:prepare][:options][:virtio] = false

    spec
  end
end
