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
require 'uri'
require 'net/http'
require 'fileutils'
require 'json'
require 'RoxyHttp'
require 'xcc'
require 'MLClient'

class ExitException < Exception
end

class DanglingVarsException < Exception
  def initialize(vars)
    @vars = vars
  end

  def vars
    return @vars
  end
end

class ServerConfig < MLClient

  def initialize(options)
    @options = options

    @properties = options[:properties]
    @environment = @properties["environment"]
    @config_file = @properties["ml.config.file"]

    if (!@properties["ml.server"]) then
      @properties["ml.server"] = @properties["ml.#{@environment}-server"]
    end
    @hostname = @properties["ml.server"]
    @bootstrap_port_four = @properties["ml.bootstrap-port-four"]
    @bootstrap_port_five = @properties["ml.bootstrap-port-five"]

    super({
      :user_name => @properties["ml.user"],
      :password => @properties["ml.password"],
      :logger => options[:logger]
    })

    @server_version = @properties["ml.server-version"]

    if (@properties["ml.bootstrap-port"])
      @bootstrap_port = @properties["ml.bootstrap-port"]
    else
      if (@server_version == 4) then
        @bootstrap_port = @bootstrap_port_four
      else
        @bootstrap_port = @bootstrap_port_five
        @properties["ml.bootstrap-port"] = @bootstrap_port
      end
    end

    @logger.debug "config: #{@config_file}"
    @logger.debug "pwd: #{ServerConfig.pwd}"
    @logger.debug "user: #{@ml_username}"
    @logger.debug "password: #{@ml_password}"
    @logger.debug "hostname: #{@hostname}"
    @logger.debug "port: #{@bootstrap_port}"
  end

  def self.pwd
    return Dir.pwd
  end

  def get_properties
    return @properties
  end

  def info
    @logger.info "Properties:"
    @properties.each do |k, v|
      @logger.info k + ": " + v
    end
  end

  def self.init
    # allow the caller to replace roxy with the new app name
    sample_config = File.expand_path("../../sample/ml-config.sample.xml", __FILE__)
    sample_properties = File.expand_path("../../sample/build.sample.properties", __FILE__)
    build_properties = File.expand_path("../../build.properties", __FILE__)
    force = find_arg(['--force']) != nil ? true : false
    force_props = find_arg(['--force-properties']) != nil ? true : false
    force_config = find_arg(['--force-config']) != nil ? true : false
    if (!force and !force_props and File.exists?(build_properties)) then
      @@logger.error "build.properties file found."
      @@logger.error "   Use --force to reset all configuration files."
      @@logger.error "   Use --force-properties to reset just the properties file.\n"
    else
      #create clean properties file
      FileUtils.cp sample_properties, build_properties

      name = ARGV.shift
      if (name)
        properties_file = open(build_properties).read
        properties_file.gsub!(/app-name=roxy/, "app-name=#{name}")
        open(build_properties, 'w') {|f| f.write(properties_file) }
      end
    end

    properties = ServerConfig.properties
    target_config = File.expand_path(properties["ml.config.file"], __FILE__)
    if (!force and !force_config and File.exists?(target_config)) then
      @@logger.error "ml-config.xml file found."
      @@logger.error "   Use --force to reset all configuration files."
      @@logger.error "   Use --force-config to reset just the configuration file.\n"
    else
      #create clean marklogic configuration file
      FileUtils.cp sample_config, target_config
    end
  end

  def self.initcpf
    sample_config = File.expand_path("../../sample/pipeline-config.sample.xml", __FILE__)
    target_config = File.expand_path("../../pipeline-config.xml", __FILE__)

    if (File.exists?(target_config)) then
      @@logger.error "initcpf has already been run. Use --force to rerun it.\n"
    else
      FileUtils.cp sample_config, target_config
    end
  end

  def self.index
    puts "What type of index do you want to build?
  1 element range index
  2 attribute range index"
    # TODO:
    # 3 field range index
    # 4 geospatial index
    type = gets.chomp.to_i
    if type == 1
      build_element_index
    elsif type == 2
      build_attribute_element_index
    else
      puts "Sorry, I don't know how to do that yet"
    end
  end

  def self.request_type
    scalar_types = %w[int unsignedInt long unsignedLong float double decimal dateTime
      time date gYearMonth gYear gMonth gDay yearMonthDuration dayTimeDuration string anyURI]
    puts "What will the scalar type of the index be [1-" + scalar_types.length.to_s + "]? "
    i = 1
    for t in scalar_types
      puts "#{i} #{t}"
      i += 1
    end
    scalar = gets.chomp.to_i
    scalar_types[scalar - 1]
  end

  def self.request_collation
    puts "What is the collation URI (leave blank for the root collation)?"
    collation = gets.chomp
    if collation == ""
      collation = "http://marklogic.com/collation/"
    end
    collation
  end

  def self.request_range_value_positions
    puts "Turn on range value positions? [y/N]"
    positions = gets.chomp.downcase
    if positions == "y"
      positions = "true"
    else
      positions = "false"
    end
    positions
  end

  def self.inject_index(key, index)
    properties = ServerConfig.properties
    config_path = File.expand_path(properties["ml.config.file"], __FILE__)
    existing = File.read(config_path) { |file| file.readlines.join }
    existing = existing.gsub(key) { |match| "#{match}\n#{index}" }
    File.open(config_path, "w") { |file| file.write(existing) }
  end

  def self.build_attribute_element_index
    scalar_type = request_type
    puts "What is the parent element's namespace URI?"
    p_uri = gets.chomp
    puts "What is the parent element's localname?"
    p_localname = gets.chomp
    puts "What is the attribute's namespace URI?"
    uri = gets.chomp
    puts "What is the attribute's localname?"
    localname = gets.chomp
    if scalar_type == "string" # string
      collation = request_collation
    end
    positions = request_range_value_positions
    index = "        <range-element-attribute-index>
          <scalar-type>#{scalar_type}</scalar-type>
          <parent-namespace-uri>#{p_uri}</parent-namespace-uri>
          <parent-localname>#{p_localname}</parent-localname>
          <namespace-uri>#{uri}</namespace-uri>
          <localname>#{localname}</localname>
          <collation>#{collation}</collation>
          <range-value-positions>#{positions}</range-value-positions>
        </range-element-attribute-index>"

    properties = ServerConfig.properties
    puts "Add this index to #{properties["ml.config.file"]}? [y/N]\n" + index
    approve = gets.chomp.downcase
    if approve == "y"
      inject_index("<range-element-attribute-indexes>", index)
      puts "Index added"
    end
  end

  def self.build_element_index
    scalar_type = request_type
    puts "What is the element's namespace URI?"
    uri = gets.chomp
    puts "What is the element's localname?"
    localname = gets.chomp
    if scalar_type == "string" # string
      collation = request_collation
    end
    positions = request_range_value_positions
    index = "        <range-element-index>
          <scalar-type>#{scalar_type}</scalar-type>
          <namespace-uri>#{uri}</namespace-uri>
          <localname>#{localname}</localname>
          <collation>#{collation}</collation>
          <range-value-positions>#{positions}</range-value-positions>
        </range-element-index>"
    properties = ServerConfig.properties
    puts "Add this index to #{properties["ml.config.file"]}? [y/N]\n" + index
    approve = gets.chomp.downcase
    if approve == "y"
      inject_index("<range-element-indexes>", index)
      puts "Index added"
    end
  end

  def execute_query(query, properties = {})
    r = nil
    if @server_version == 4
      r = execute_query_4 query, properties
    else
      r = execute_query_5 query, properties
    end

    if (r.code.to_i != 200)
      raise ExitException.new r.body
    end

    return r
  end

  def restart
    group = ARGV.shift
    if (group)
      @logger.info("Restarting MarkLogic Server group #{group} on #{@hostname}")
    else
      @logger.info("Restarting MarkLogic Server on #{@hostname}")
    end
    setup = open(File.expand_path('../xquery/setup.xqy', __FILE__)).readlines.join
    r = execute_query %Q{#{setup} setup:do-restart("#{group}")}
  end

  def self.plugin
    # get src dir and package details
    properties = ServerConfig.properties
    src_dir = properties["ml.xquery.dir"]
    plugin_command = ARGV.shift if ARGV.count
    package = ARGV.shift if ARGV.count
    package_version = ARGV.shift if ARGV.count

    runme = %Q{cd #{src_dir} && }
    if (is_windows?) then
      runme << File.expand_path("../depx-0.1/depx.bat", __FILE__)
    else
      runme << File.expand_path("../depx-0.1/depx", __FILE__)
    end
    runme << " #{plugin_command}" if plugin_command
    runme << " #{package} " if package
    runme << " #{package_version} " if package_version
    @@logger.debug runme

    output = `#{runme}`
    @@logger.info(output)
  end

  def config
    @logger.info get_config
  end

  def bootstrap
    if @hostname && @hostname != ""
      @logger.info("Bootstrapping your project into MarkLogic on #{@hostname}...")
      setup = open(File.expand_path('../xquery/setup.xqy', __FILE__)).readlines.join
      r = execute_query %Q{#{setup} setup:do-setup(#{get_config})}

      @logger.debug r.body

      if (r.body.match("(note: restart required)")) then
        @logger.warn("NOTE*** RESTART OF MARKLOGIC IS REQUIRED")
      end
      @logger.info("... Bootstrap Complete")
    else
      raise ExitException.new "Bootstrap requires the target environment's hostname to be defined"
    end
  end

  def wipe
    @logger.info("Wiping MarkLogic setup for your project on #{@hostname}...")
    setup = open(File.expand_path('../xquery/setup.xqy', __FILE__)).readlines.join
    r = execute_query %Q{#{setup} setup:do-wipe(#{get_config})}
    @logger.info r.body
    @logger.info "...wipe complete"
  end

  def deploy
    what = ARGV.shift
    if (what)
      case what
        when 'content'
          deploy_content
        when 'modules'
          deploy_modules
        when 'cpf'
          deploy_cpf
        else
          puts Help.deploy
      end
    else
      puts Help.deploy
    end
  end

  def load_data(dir, options = {})
    batch_override = nil
    if (ARGV[0] && ARGV[0].match("--batch=(yes|no)"))
      batch_override = ARGV.shift.split("=")[1] == "yes"
    end
    batch = (((@environment != "local") && (batch_override != false)) || (batch_override == true))

    options[:batch_commit] = batch
    options[:permissions] =
      [
        {
          :capability => Roxy::ContentCapability::EXECUTE,
          :role => @properties['ml.app-role']
        },
        {
          :capability => Roxy::ContentCapability::READ,
          :role => @properties['ml.app-role']
        }
      ] unless options[:permissions]
    xcc.load_files(File.expand_path(dir), options)
  end

  #
  # Cleans something
  #  .. content = cleans the content db
  #  .. modules = cleans the modules db
  #  .. triggers = cleans the triggers db
  #  .. schemas = cleans the schemas db
  #  .. cpf = cleans the cpf configuration
  #
  def clean
    what = ARGV.shift
    if (what)
      case what
        when 'content'
          clean_content
        when 'modules'
          clean_modules
        when 'triggers'
          clean_triggers
        when 'schemas'
          clean_schemas
        when 'cpf'
          clean_cpf
      end
    else
      puts Help.clean
    end
  end

  #
  # Invokes unit tests for the project
  #
  def test
    if (@environment == "prod") then
      @logger.error "There is no Test database on the Production server"
    else
      r = go %Q{http://#{@hostname}:#{@properties["ml.test-port"]}/test/list}, "get"
      suites = []
      r.body.split(">").each do |line|
        if (line.match("suite path")) then
          suites << line.gsub(/.*suite path="([^"]+)".*/, '\1').strip
        end
      end

      suites.each do |suite|
        r = go %Q{http://#{@hostname}:#{@properties["ml.test-port"]}/test/run?suite=#{url_encode(suite)}&format=junit}, "get"
        @logger.info r.body
      end
    end
  end

  def test_cleanup
    src_dir = File.expand_path(@properties["ml.xquery.dir"], __FILE__)
    File.delete("#{src_dir}/app/controllers/missing-map.xqy")
    File.delete("#{src_dir}/app/controllers/tester.xqy")
    FileUtils.rm_r("#{src_dir}/app/views/tester", :force => true)
    File.delete("#{src_dir}/app/views/layouts/different-layout.html.xqy")
  end

  def backup_database(id, dir)
    r = execute_query %Q{xdmp:database-backup(xdmp:database-forests(#{id}), "#{dir}")}
    r.body
  end

  def is_backup_complete(job)
    r = execute_query %Q{xdmp:database-backup-status(#{job})}
    statuses = []
    r.body.split("\n").each do |line|
      if (line.match("job:status")) then
        statuses << line.gsub(/.*<job:status>([^<]+)<\/job:status>/, '\1').strip
      end
    end

    completed_count = 0
    failed_count = 0
    statuses.each do |status|
      if (status == "completed") then
        completed_count = completed_count + 1
      elsif (status == "failed") then
        failed_count = failed_count + 1
      end
    end

    completed = (completed_count + failed_count) == statuses.size

    return completed, failed_count
  end

  def recordloader
    properties_file = File.expand_path("../../#{ARGV.shift}", __FILE__)
    properties = ServerConfig.load_properties(properties_file, "")
    properties = ServerConfig.substitute_properties(properties, @properties, "")

    properties.each do |k, v|
      @logger.info("#{k}=#{v}")
    end

    prop_string = ""
    properties.each do |k,v|
      prop_string << %Q{-D#{k}="#{v}" }
    end

    runme = %Q{java -cp #{File.expand_path("../java/recordloader.jar", __FILE__)}#{path_separator}#{File.expand_path("../java/marklogic-xcc-5.0.2.jar", __FILE__)}#{path_separator}#{File.expand_path("../java/xpp3-1.1.4c.jar", __FILE__)} #{prop_string} com.marklogic.ps.RecordLoader}
    @logger.info runme
    `#{runme}`
  end

  def xqsync
    properties_file = File.expand_path("../../#{ARGV.shift}", __FILE__)
    properties = ServerConfig.load_properties(properties_file, "")
    properties = ServerConfig.substitute_properties(properties, @properties, "")

    properties.each do |k, v|
      @logger.info("#{k}=#{v}")
    end
    prop_string = ""
    properties.each do |k,v|
      prop_string << %Q{-D#{k}="#{v}" }
    end

    runme = %Q{java -Xmx2048m -cp #{File.expand_path("../java/xqsync.jar", __FILE__)}#{path_separator}#{File.expand_path("../java/marklogic-xcc-5.0.2.jar", __FILE__)}#{path_separator}#{File.expand_path("../java/xstream-1.4.2.jar", __FILE__)}#{path_separator}#{File.expand_path("../java/xpp3-1.1.4c.jar", __FILE__)} -Dfile.encoding=UTF-8 #{prop_string} com.marklogic.ps.xqsync.XQSync}
    @logger.info runme
    `#{runme}`
  end

private
  def deploy_modules
    ignore_us = []
    ignore_us = ["^#{@properties['ml.xquery-test.dir']}.*$"] if @properties['ml.xquery-test.dir']
    app_config_file = "#{@properties['ml.xquery.dir']}/app/config/config.xqy"
    ignore_us << "^#{app_config_file}$"
    load_data @properties["ml.xquery.dir"], {
      :add_prefix => "/",
      :remove_prefix => @properties["ml.xquery.dir"],
      :db => @properties['ml.modules-db'],
      :ignore_list => ignore_us
    }

    if (File.exist?(app_config_file))
      buffer = open(app_config_file).readlines.join
      @properties.each do |k, v|
        buffer.gsub!("@#{k}", v)
      end

      xcc.load_buffer("/config.xqy", buffer,{
        :db => @properties['ml.modules-db'],
        :add_prefix => File.join(@properties["ml.modules-root"], "app/config"),
        :permissions => [
          {
            :capability => Roxy::ContentCapability::EXECUTE,
            :role => @properties['ml.app-role']
          },
          {
            :capability => Roxy::ContentCapability::READ,
            :role => @properties['ml.app-role']
          }
        ]
      })
    end
    # only deploy test code if test db is enabled.
    # don't deploy tests to prod
    if (@properties['ml.test-content-db'] && @properties['ml.test-content-db'] != "" &&
        @properties['ml.test-port'] && @properties['ml.test-port'] != "" &&
        @environment != "prod")

      test_config_file = "#{@properties['ml.xquery-test.dir']}/test-config.xqy"

      # if the test-modules-db is different from the app modules db, also load the
      # app modules into it
      if (@properties['ml.test-modules-db'] && @properties['ml.test-modules-db'] != "" &&
          @properties['ml.test-modules-db'] != @properties['ml.modules-db'])
        load_data @properties["ml.xquery-test.dir"], {
          :add_prefix => File.join(@properties["ml.modules-root"], "test"),
          :remove_prefix => @properties["ml.xquery-test.dir"],
          :db => @properties['ml.test-modules-db'],
          :ignore_list => ["^#{test_config_file}$"]
        }

        if (File.exist?(test_config_file))
          buffer = open(test_config_file).readlines.join
          @properties.each do |k, v|
            buffer.gsub!("@#{k}", v)
          end

          xcc.load_buffer("/test-config.xqy", buffer,{
            :db => @properties['ml.test-modules-db'],
            :add_prefix => File.join(@properties["ml.modules-root"], "test"),
            :permissions => [
              {
                :capability => Roxy::ContentCapability::EXECUTE,
                :role => @properties['ml.app-role']
              }
            ]
          })
        end

        load_data @properties["ml.xquery.dir"], {
          :add_prefix => "/",
          :remove_prefix => @properties["ml.xquery.dir"],
          :db => @properties['ml.test-modules-db'],
          :ignore_list => ignore_us
        }

        if (File.exist?(app_config_file))
          buffer = open(app_config_file).readlines.join
          @properties.each do |k, v|
            buffer.gsub!("@#{k}", v)
          end

          xcc.load_buffer("/config.xqy", buffer,{
            :db => @properties['ml.test-modules-db'],
            :add_prefix => File.join(@properties["ml.modules-root"], "app/config"),
            :permissions => [
              {
                :capability => Roxy::ContentCapability::EXECUTE,
                :role => @properties['ml.app-role']
              },
              {
                :capability => Roxy::ContentCapability::READ,
                :role => @properties['ml.app-role']
              }
            ]
          })
        end
      else
        load_data @properties["ml.xquery-test.dir"], {
          :add_prefix => File.join(@properties["ml.modules-root"], "test"),
          :remove_prefix => @properties["ml.xquery-test.dir"],
          :db => @properties['ml.modules-db'],
          :ignore_list => ["^#{test_config_file}$"]
        }

        if (File.exist?(test_config_file))
          buffer = open(test_config_file).readlines.join
          @properties.each do |k, v|
            buffer.gsub!("@#{k}", v)
          end

          xcc.load_buffer("/test-config.xqy", buffer,{
            :db => @properties['ml.modules-db'],
            :add_prefix => File.join(@properties["ml.modules-root"], "test"),
            :permissions => [
              {
                :capability => Roxy::ContentCapability::EXECUTE,
                :role => @properties['ml.app-role']
              }
            ]
          })
        end
      end
    end
  end

  def clean_modules
    @logger.info("Cleaning #{@properties['ml.modules-db']} on #{@hostname}")
    execute_query %Q{xdmp:forest-clear(xdmp:forest("#{@properties['ml.modules-db']}"))}
    if (@properties['ml.test-modules-db'] && @properties['ml.test-modules-db'] != @properties['ml.modules-db'])
      @logger.info("Cleaning #{@properties['ml.test-modules-db']} on #{@hostname}")
      execute_query %Q{xdmp:forest-clear(xdmp:forest("#{@properties['ml.test-modules-db']}"))}
    end
  end

  def clean_schemas
    if (@properties['ml.schemas-db'])
      @logger.info("Cleaning #{@properties['ml.schemas-db']} on #{@hostname}")
      execute_query %Q{xdmp:forest-clear(xdmp:forest("#{@properties['ml.schemas-db']}"))}
    else
      @logger.error("No schemas db is configured")
    end
  end

  def clean_triggers
    if (@properties['ml.triggers-db'])
      @logger.info("Cleaning #{@properties['ml.triggers-db']} on #{@hostname}")
      execute_query %Q{xdmp:forest-clear(xdmp:forest("#{@properties['ml.triggers-db']}"))}
    else
      @logger.error("No triggers db is configured")
    end
  end

  def deploy_content
    load_data @properties["ml.data.dir"], {
      :remove_prefix => @properties["ml.data.dir"],
      :db => @properties['ml.content-db'],
      :permissions => [
        {
          :capability => Roxy::ContentCapability::READ,
          :role => @properties['ml.app-role']
        },
        {
          :capability => Roxy::ContentCapability::UPDATE,
          :role => @properties['ml.app-role']
        }
      ]
    }
  end

  def clean_content
    @logger.info("Cleaning #{@properties['ml.content-db']} on #{@hostname}")
    execute_query %Q{
      for $id in xdmp:database-forests(xdmp:database("#{@properties['ml.content-db']}"))
      return
        xdmp:forest-clear($id)
    }
  end

  def deploy_cpf
    if (!@properties["ml.triggers-db"] || @properties["ml.data.dir"] == "")
      @logger.error("To use CPF, you must define the triggers-db property in your build.properties file")
    elsif (!File.exist?(File.expand_path("../../pipeline-config.xml", __FILE__)))
      @logger.error("
Before you can deploy CPF, you must define a configuration. Steps:
1. Run 'ml initcpf'
2. Edit deploy/pipeline-config.xml to set up your domain and pipelines
3. Run 'ml <env> deploy cpf')")
    else
      cpf_config = open(File.expand_path("../../pipeline-config.xml", __FILE__)).readlines.join
      @properties.each do |k, v|
        cpf_config.gsub!("@#{k}", v)
      end
      cpf_code = open(File.expand_path('../xquery/cpf.xqy', __FILE__)).readlines.join
      r = execute_query %Q{#{cpf_code} cpf:load-from-config(#{cpf_config})}, { :db_name => @properties["ml.content-db"] }
    end
  end

  def clean_cpf
    cpf_code = open(File.expand_path('../xquery/cpf.xqy', __FILE__)).readlines.join
    r = execute_query %Q{#{cpf_code} cpf:clean-cpf()}, { :db_name => @properties["ml.content-db"] }
  end

  def xcc
    if (!@xcc)
      password_prompt
      @xcc = Roxy::Xcc.new({
        :user_name => @ml_username,
        :password => @ml_password,
        :xcc_server => @hostname,
        :xcc_port => @properties["ml.xcc-port"],
        :logger => @logger
      })
    end
    @xcc
  end

  def get_config
    if (@config == nil) then
      @config = build_config @options[:config_file]
    end
    @config
  end

  def execute_query_4(query, properties)
    r = go "http://#{@hostname}:#{@bootstrap_port}/use-cases/eval2.xqy", "post", {}, {
      :queryInput => query
    }
    return r
  end

  def get_any_db_id
    r = go "http://#{@hostname}:#{@bootstrap_port}/manage/LATEST/databases?format=xml", "get"
    if (r.code.to_i == 200) then
      dbid = $1 if r.body =~ /.*<idref>([^<]+)<\/idref>.*/
      return dbid
    end
    return nil
  end

  def get_db_id(db_name)
    r = go "http://#{@hostname}:#{@bootstrap_port}/manage/LATEST/databases?format=xml", "get"
    if (r.code.to_i == 200) then
      use_next_line = false
      r.body.split("\n").each do |line|
        if (use_next_line == true) then
          dbid = $1 if line =~ /.*<idref>([^<]+)<\/idref>.*/
          return dbid
        end
        if (line.match(db_name)) then
          use_next_line = true
        end
      end
    end
    return nil
  end

  def get_sid(app_name)
    r = go "http://#{@hostname}:#{@bootstrap_port}/manage/LATEST/servers?format=xml", "get"
    if (r.code.to_i == 200) then
      previous_line = ""
      r.body.split("\n").each do |line|
        if (line.match("<nameref>#{app_name}</nameref>")) then
          dbid = $1 if previous_line =~ /.*<idref>([^<]+)<\/idref>.*/
          return dbid
        end

        previous_line = line
      end
    end
    return nil
  end

  def execute_query_5(query, properties = {})
    # We need a context for this query. Here's what we look for, in order of preference:
    # 1. A caller-specified database
    # 2. A caller-specified application server
    # 3. An application server that is present by default
    # 4. Any database
    if (properties[:db_name] != nil) then
      db_id = get_db_id(properties[:db_name])
    elsif (properties[:app_name] != nil) then
      sid = get_sid(properties[:app_name])
    else
      sid = get_sid("Manage")
    end

    if (db_id == nil && sid == nil) then
      db_id = get_any_db_id
    end

    if (db_id != nil) then
      @logger.debug("using dbid: #{db_id}")
      r = go "http://#{@hostname}:#{@bootstrap_port}/qconsole/endpoints/eval.xqy", "post", {}, {
        :dbid => db_id,
        :resulttype => "text",
        :q => query
      }
      @logger.debug(r.body)
    else
      @logger.debug("using sid: #{sid}")
      r = go "http://#{@hostname}:#{@bootstrap_port}/qconsole/endpoints/eval.xqy", "post", {}, {
        :sid => sid,
        :resulttype => "text",
        :q => query
      }
      @logger.debug(r.body)
    end

    if (r.body.match(/\{"error"/)) then
      raise ExitException.new JSON.pretty_generate(JSON.parse(r.body))
    end

    return r
  end

  def self.substitute_properties(sub_me, with_me, prefix = "")
    dangling_vars = {}
    begin
      needs_rescan = false
      sub_me.each do |k,v|
        if (v.match(/\$\{basedir\}/)) then
          sub_me[k] = File.expand_path(v.sub("${basedir}", ServerConfig.pwd))
        else
          matches = v.scan(/\$\{([^}]+)\}/)
          if (matches.count > 0) then
            var = "#{prefix}#{matches[0][0]}"
            sub = with_me[var]
            if (sub) then
              new_val = v.sub(/\$\{[^}]+\}/, sub)
              sub_me[k] = new_val
              if (matches.length > 1)
                needs_rescan = true
              end
            else
              dangling_vars[k] = v
            end
          end
        end
      end
    end while (needs_rescan == true)

    if (dangling_vars.count > 0)
      raise DanglingVarsException.new(dangling_vars)
    end

    sub_me
  end

  def self.load_properties(properties_filename, prefix = "")
    properties = {}
    File.open(properties_filename, 'r') do |properties_file|
      properties_file.read.each_line do |line|
        line.strip!
        if ((line[0] != ?#) && (line[0] != ?=) && (line[0] != ""))
          i = line.index('=')
          if (i)
            key = prefix + line[0..i - 1].strip
            value = line[i + 1..-1].strip
            properties[key] = value
          end
        end
      end
    end

    properties
  end

  def build_config(config_file)
    config = open(config_file).readlines.join

    # Build the triggers db if it is provided
    if (@properties['ml.triggers-db'])
      config.gsub!("@ml.triggers-db-xml",
      %Q{
      <database>
        <database-name>@ml.triggers-db</database-name>
        <forests>
          <forest-id name="@ml.triggers-db"/>
        </forests>
      </database>
      })

      config.gsub!("@ml.triggers-assignment",
      %Q{
        <assignment>
          <forest-name>@ml.triggers-db</forest-name>
        </assignment>
      })

      config.gsub!("@ml.triggers-mapping",
      %Q{
      <triggers-database name="@ml.triggers-db"/>
      })
    else
      config.gsub!("@ml.triggers-db-xml", "")
      config.gsub!("@ml.triggers-assignment", "")
      config.gsub!("@ml.triggers-mapping", "")
    end

    if (@properties['ml.xcc-port'])
      config.gsub!("@ml.xdbc-server",
      %Q{
      <xdbc-server>
        <xdbc-server-name>@ml.app-name-xcc</xdbc-server-name>
        <port>@ml.xcc-port</port>
        <database name="@ml.content-db"/>
        <modules name="@ml.modules-db"/>
        <authentication>digest</authentication>
      </xdbc-server>
      })
    end

    # Build the schemas db if it is provided
    if (@properties['ml.schemas-db'])
      config.gsub!("@ml.schemas-db-xml",
      %Q{
      <database>
        <database-name>@ml.schemas-db</database-name>
        <forests>
          <forest-id name="@ml.schemas-db"/>
        </forests>
      </database>
      })

      config.gsub!("@ml.schemas-assignment",
      %Q{
        <assignment>
          <forest-name>@ml.schemas-db</forest-name>
        </assignment>
      })

      config.gsub!("@ml.schemas-mapping",
      %Q{
      <schema-database name="@ml.schemas-db"/>
      })

    else
      config.gsub!("@ml.schemas-db-xml", "")
      config.gsub!("@ml.schemas-assignment", "")
      config.gsub!("@ml.schemas-mapping", "")
    end

    # Build the test appserver and db if it is provided
    if (@properties['ml.test-content-db'] && @properties['ml.test-content-db'] != "" &&
        @properties['ml.test-port'] && @properties['ml.test-port'] != "" &&
        @environment != "prod")
      config.gsub!("@ml.test-content-db-xml",
      %Q{
        <database import="@ml.content-db">
          <database-name>@ml.test-content-db</database-name>
          <forests>
            <forest-id name="@ml.test-content-db"/>
          </forests>
        </database>
      })

      config.gsub!("@ml.test-content-db-assignment",
      %Q{
        <assignment>
          <forest-name>@ml.test-content-db</forest-name>
        </assignment>
      })

      if (@properties['ml.test-modules-db'] && @properties['ml.test-modules-db'] != "" &&
          @properties['ml.test-modules-db'] != @properties['ml.app-modules-db'])
        config.gsub!("@ml.test-appserver",
        %Q{
          <http-server>
            <http-server-name>@ml.app-name-test</http-server-name>
            <port>@ml.test-port</port>
            <database name="@ml.test-content-db"/>
            <modules name="@ml.test-modules-db"/>
            <root>@ml.modules-root</root>
            <authentication>@ml.authentication-method</authentication>
            <default-user name="@ml.default-user"/>
            <url-rewriter>@ml.url-rewriter</url-rewriter>
            <error-handler>@ml.error-handler</error-handler>
          </http-server>
        })
      else
        config.gsub!("@ml.test-appserver",
        %Q{
          <http-server>
            <http-server-name>@ml.app-name-test</http-server-name>
            <port>@ml.test-port</port>
            <database name="@ml.test-content-db"/>
            <modules name="@ml.modules-db"/>
            <root>@ml.modules-root</root>
            <authentication>@ml.authentication-method</authentication>
            <default-user name="@ml.default-user"/>
            <url-rewriter>@ml.url-rewriter</url-rewriter>
            <error-handler>@ml.error-handler</error-handler>
          </http-server>
        })
      end

    else
      config.gsub!("@ml.test-content-db-xml", "")
      config.gsub!("@ml.test-content-db-assignment", "")
      config.gsub!("@ml.test-appserver", "")
    end

    # Build the test modules db if it is different from the app modules db
    if (@properties['ml.test-modules-db'] && @properties['ml.test-modules-db'] != "" &&
        @properties['ml.test-modules-db'] != @properties['ml.app-modules-db'])
      config.gsub!("@ml.test-modules-db-xml",
      %Q{
        <database import="@ml.modules-db">
          <database-name>@ml.test-modules-db</database-name>
          <forests>
            <forest-id name="@ml.test-modules-db"/>
          </forests>
        </database>
      })

      config.gsub!("@ml.test-modules-db-assignment",
      %Q{
        <assignment>
          <forest-name>@ml.test-modules-db</forest-name>
        </assignment>
      })
    else
      config.gsub!("@ml.test-modules-db-xml", "")
    end

    if (@properties['ml.forest-data-dir'])
      config.gsub!("@ml.forest-data-dir-xml",
      %Q{
        <data-directory>@ml.forest-data-dir</data-directory>
      })
    end

    @properties.each do |k, v|
      config.gsub!("@#{k}", v)
    end

    config
  end

  def self.properties
    default_properties_file = File.expand_path("../../default.properties", __FILE__)
    properties_file = File.expand_path("../../build.properties", __FILE__)
    if !File.exist?(properties_file) then
      raise ExitException.new "You must run ml init to configure your application."
    end

    properties = ServerConfig.load_properties(default_properties_file, "ml.")
    properties.merge!(ServerConfig.load_properties(properties_file, "ml."))

    environments = properties['ml.environments'].split(",") if properties['ml.environments']
    environments = ["local", "dev", "prod"] unless environments

    environment = find_arg(environments)

    properties["environment"] = environment if environment

    env_properties_file = File.expand_path("../../#{environment}.properties", __FILE__)
    if (File.exists?(env_properties_file))
      properties.merge!(ServerConfig.load_properties(env_properties_file, "ml."))
    end

    properties = ServerConfig.substitute_properties(properties, properties, "ml.")
  end
end
