###############################################################################
# Copyright 2012-2015 MarkLogic Corporation
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
require 'Help'
require 'server_config'
require 'framework'
require 'util'
require 'upgrader'
require 'scaffold'

if is_jar?
  require ServerConfig.expand_path("./deploy/app_specific")
else
  require 'app_specific'
end

def need_help?
  find_arg(['-h', '--help']) != nil
end

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

@no_prompt = find_arg(['-n', '--no-prompt'])

@logger = Logger.new(STDOUT)
@logger.level = find_arg(['-v', '--verbose']) ? Logger::DEBUG : Logger::INFO
@logger.formatter = proc { |severity, datetime, progname, msg|
  sev = "#{severity}: " if severity == "ERROR"
  "#{sev}#{msg}\n"
}

if ARGV.length == 1 && need_help?
  Help.doHelp(@logger, :usage)
  exit
end

if RUBY_VERSION < "1.8.7"
  @logger.warn <<-MSG

    WARNING!!!
    You are using a very old version of Ruby: #{RUBY_VERSION}
    Roxy works best with Ruby 1.9.3 or greater.
    Proceed with caution.
  MSG
elsif RUBY_VERSION < "1.9.3"
  @logger.warn <<-MSG

    WARNING!!!
    Ruby version 1.9.3 is the oldest supported version. You are running
    Ruby #{RUBY_VERSION}. Some features may not work. You are encouraged to
    upgrade to Ruby 1.9.3+.
  MSG
end

begin
  while ARGV.length > 0
    command = ARGV.shift

    #
    # Roxy framework is a convenience utility for create MVC code
    #
    if command == "create"
      if need_help?
        Help.doHelp(@logger, command)
      else
        f = Roxy::Framework.new :logger => @logger, :properties => ServerConfig.properties, :no_prompt => @no_prompt
        f.create
      end
      break
    elsif command == "extend"
      if need_help?
        Help.doHelp(@logger, command)
      else
        scaffold = Roxy::Scaffold.new :logger => @logger, :properties => ServerConfig.properties
        scaffold.extend ARGV.shift
      end
      break
    elsif command == "transform"
      if need_help?
        Help.doHelp(@logger, command)
      else
        scaffold = Roxy::Scaffold.new :logger => @logger, :properties => ServerConfig.properties
        scaffold.transform ARGV.shift, ARGV.shift
      end
      break
    elsif command == "upgrade"
      if need_help?
        Help.doHelp(@logger, command)
      else
        upgrader = Roxy::Upgrader.new :logger => @logger, :properties => ServerConfig.properties, :no_prompt => @no_prompt
        upgrader.upgrade(ARGV)
      end
      break
    #
    # put things in ServerConfig class methods that don't depend on environment or server info
    #
    elsif ServerConfig.respond_to?(command.to_sym) || ServerConfig.respond_to?(command)
      if need_help?
        Help.doHelp(@logger, command)
      else
        ServerConfig.logger = @logger
        ServerConfig.no_prompt = @no_prompt
        result = ServerConfig.send command
        if !result
          exit!
        end
      end
      break
    #
    # ServerConfig methods require environment to be set in order to talk to a ML server
    #
    else
      # unshift to get the environment in ServerConfig.properties
      ARGV.unshift command
      @properties = ServerConfig.properties
      command = ARGV.shift

      if need_help? && Help.respond_to?(command)
        Help.doHelp(@logger, command)
        break
      elsif command.start_with?("--ml.")
        break
      elsif ServerConfig.instance_methods.include?(command.to_sym) || ServerConfig.instance_methods.include?(command)
        raise HelpException.new(command, "Missing environment for #{command}") if @properties["environment"].nil?
        raise ExitException.new("Missing ml-config.xml file. Check config.file property") if @properties["ml.config.file"].nil?

        result = ServerConfig.new(
          :config_file => File.expand_path(@properties["ml.config.file"], __FILE__),
          :properties => @properties,
          :logger => @logger,
          :no_prompt => @no_prompt
        ).send(command)
        if !result
          exit!
        end
      else
        Help.doHelp(@logger, :usage, "Unknown command #{command}!")
        break
      end
    end
  end
rescue Net::HTTPServerException => e
  case e.response
  when Net::HTTPUnauthorized then
    @logger.error "Invalid login credentials for #{@properties["environment"]} environment!!"
    exit!
  else
    @logger.error e
    @logger.error e.response.body
    exit!
  end
rescue Net::HTTPFatalError => e
  @logger.error e
  @logger.error e.response.body
  exit!
rescue DanglingVarsException => e
  @logger.error "WARNING: The following configuration variables could not be validated:"
  e.vars.each do |k,v|
    @logger.error "#{k}=#{v}"
  end
  exit!
rescue HelpException => e
  Help.doHelp(@logger, e.command, e.message)
  exit!
rescue ExitException => e
  @logger.error e
  exit!
rescue Exception => e
  @logger.error e
  @logger.error e.backtrace
  exit!
end

if @profile then
  result = RubyProf.stop

  # Print a flat profile to text
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(STDOUT)
end
