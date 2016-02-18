require 'singleton'

class  Props
    include Singleton

    #Config for Runtime #TODO Monitor
    class << self
        attr_accessor(:core_host, :ssh_port )
    end


end