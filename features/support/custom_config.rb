require "erb"
require 'yaml'
#require 'singleton'


module CONFIG
 #class CONFIG
   #include Singleton

  unless defined? @@CONFIG
    puts '====== CustomConfig module ======'
    $default_env_name = ':ptrade1'
    $config_file = File.expand_path('../../../config/environments.yml', __FILE__)
    args = {}
    ARGV.each do |arg|
      $custom_env=true  if (arg =~ /env=[a-zA-Z0-9.-_]+$/)
      if $custom_env
         $custom_env_name= arg.dup.sub(/env=/,'')
         break
      end
    end


    if !$custom_env
      $env_name = $default_env_name
      puts '====== Using the Default Environment ' + $config_file + ' environments.yml '+$env_name+'...'
      env = (ENV['ENVIRONMENT'] && ENV['ENVIRONMENT'].to_sym) || :ptrade1  #$env_name
    else
      $env_name = $custom_env_name
      puts '====== Using Custom Environment  ' + $config_file + ' environments.yml ' + $env_name + '...'
      env = (ENV['ENVIRONMENT'] && ENV['ENVIRONMENT'].to_sym) || $env_name
    end

    environments = YAML.load(ERB.new(File.read($config_file)).result)
    $config = environments[env.to_s]
    @@CONFIG = $config #Hash[*config]
        #p @@CONFIG
    raise "Error:No config for environment #{$env_name}" unless @@CONFIG
  end

  def CONFIG.get
     @@CONFIG
  end


end

ENV.each_pair do |k, v|
  $config.each_with_index { | v2,k2 |
    $config[k]=v if(v2[0].to_s.downcase==k.to_s.downcase)
  }
end

class String
  def to_bool
    return true if self == true || self =~ (/^(true|t|yes|y|1)$/i)
    return false if self == false ||  self =~ (/^(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end

class Object
  def is_number?
    self.to_f.to_s == self.to_s || self.to_i.to_s == self.to_s
  end
end




World(CONFIG)
