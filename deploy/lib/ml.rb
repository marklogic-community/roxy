###############################################################################
# Copyright 2012 MarkLogic Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################
require File.expand_path('../server_config', __FILE__)
require File.expand_path('../framework', __FILE__)
require File.expand_path('../util', __FILE__)
require File.expand_path('../../app_specific.rb', __FILE__)

ARGV << '--help' if ARGV.empty?

@profile = find_arg(['-p', '--profile'])
if @profile then
  begin
    require 'ruby-prof'
    RubyProf.start
  rescue LoadError
    print("Error: Please install the ruby-prof gem to enable profiling\n> gem install ruby-prof\n")
    exit
  end
end

@logger = Logger.new(STDOUT)
@logger.level = find_arg(['-v', '--verbose']) ? Logger::DEBUG : Logger::INFO
@logger.formatter = proc { |severity, datetime, progname, msg|
  "#{severity}: #{msg}\n"
}

environment = find_arg(['local', 'dev', 'prod'])

while ARGV.length > 0
  command = ARGV.shift

  if ["-h", "--help"].include?(ARGV.first)
    @logger.formatter = proc { |severity, datetime, progname, msg|
      "#{msg}\n"
    }

    @logger.info(eval("Help.#{command}"))
    exit
  end

  #
  # Roxy framework is a convenience utility for create MVC code
  #
  if (command == "create")
    f = Roxy::Framework.new(:logger => @logger)
    f.create# ARGV.join

  #
  # put things in ServerConfig class methods that don't depend on environment or server info
  #
  elsif (ServerConfig.respond_to?(command.to_sym) || ServerConfig.respond_to?(command))
    ServerConfig.set_logger @logger
    eval "ServerConfig.#{command}"

  #
  # ServerConfig methods require environment to be set in order to talk to a ML server
  #
  elsif (ServerConfig.instance_methods.include?(command.to_sym) || ServerConfig.instance_methods.include?(command))

    if (environment == nil)
      @logger.error "Missing environment for #{command}"
      exit
    end

    @s = ServerConfig.new({
      :environment => environment,
      :config_file => File.expand_path("../../ml-config.xml", __FILE__),
      :properties_file => File.expand_path("../../build.properties", __FILE__),
      :env_properties_file => File.expand_path("../../#{environment}.properties", __FILE__),
      :logger => @logger
    })

    begin
      case command
        when 'load'
          dir = ARGV[0]
          db = ARGV[1]
          remove_prefix = ""
          if (ARGV.include?('-r'))
            index = ARGV.index('-r') + 1
            if (ARGV.size > index)
              remove_prefix = ARGV[index]
            else
              @logger.error("invalid option")
            end
          elsif (ARGV.include?('--remove-prefix'))
            # index = ARGV.index('-v') || ARGV.index('--verbose')
            # ARGV.slice!(index)
          end

          if (dir && db)
            @s.load_data dir, remove_prefix, db
          else
            puts "Error: Destination directory and Database are required"
          end
        else
          @s.send(command)
      end
    rescue Net::HTTPServerException => e
      case e.response
      when Net::HTTPUnauthorized then
        @logger.error("Invalid login credentials for #{environment} environment!!")
      else
        @logger.error(e)
        @logger.error(e.response.body)
      end
    rescue Net::HTTPFatalError => e
      @logger.error(e)
      @logger.error(e.response.body)
    rescue Exception => e
      @logger.error(e.class)
      @logger.error(e)
      @logger.error(e.backtrace)
    end
  else
    puts "Error: Command not recognized" unless ['-h', '--help'].include?(command)
    puts <<-EOT
Usage: ml COMMAND [ARGS]

Deployment Commands:
 init           Creates configuration files for you to customize
 initcpf        Creates cpf configuration files for you to customize
 info           Return settings for a given environment
 bootstrap      Configures your application on the MarkLogic server
 wipe           Remove your configuration from the MarkLogic server
 restart        Restart your MarkLogic server
 deploy         Loads modules, data, cpf configuration into the server
 clean          Removes all files from the cpf, modules, or content databases
 info           Prints the configuration information
 test           Runs xquery unit tests
 recordloader   Runs RecordLoader
 xqsync         Runs XQSync
 version        Returns the version of the MarkLogic Server

Roxy MVC Commands:
 create       Creates a controller or view or model

All commands can be run with -h for more information.
      EOT
      exit(1)
  end
end

if @profile then
  result = RubyProf.stop

  # Print a flat profile to text
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(STDOUT)
end