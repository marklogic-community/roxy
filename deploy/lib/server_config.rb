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
require 'date'
require 'ml_rest'

class ExitException < Exception; end

class HelpException < Exception
  attr_reader :command, :message
  def initialize(command, message = nil)
    @command = command
    @message = message
  end
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

    @properties["ml.server"] = @properties["ml.#{@environment}-server"] unless @properties["ml.server"]

    @hostname = @properties["ml.server"]
    @bootstrap_port_four = @properties["ml.bootstrap-port-four"]
    @bootstrap_port_five = @properties["ml.bootstrap-port-five"]

    super(
      :user_name => @properties["ml.user"],
      :password => @properties["ml.password"],
      :logger => options[:logger]
    )

    @server_version = @properties["ml.server-version"].to_i

    if @properties["ml.bootstrap-port"]
      @bootstrap_port = @properties["ml.bootstrap-port"]
    else
      if @server_version == 4
        @bootstrap_port = @bootstrap_port_four
      else
        @bootstrap_port = @bootstrap_port_five
        @properties["ml.bootstrap-port"] = @bootstrap_port
      end
    end

    if @properties['ml.qconsole-port']
      @qconsole_port = @properties['ml.qconsole-port']
    else
      @qconsole_port = @bootstrap_port
    end
  end

  def self.pwd
    return Dir.pwd
  end

  def get_properties
    return @properties
  end

  def info
    logger.info "Properties:"
    @properties.each do |k, v|
      logger.info k + ": " + v
    end
  end

  def self.init
    sample_config = File.expand_path("../../sample/ml-config.sample.xml", __FILE__)
    sample_properties = File.expand_path("../../sample/build.sample.properties", __FILE__)
    build_properties = File.expand_path("../../build.properties", __FILE__)
    options_dir = File.expand_path("../../../rest-api/config/options", __FILE__)
    rest_ext_dir = File.expand_path("../../../rest-api/ext", __FILE__)
    rest_transforms_dir = File.expand_path("../../../rest-api/transforms", __FILE__)
    options_file = File.expand_path("../../../rest-api/config/options/all.xml", __FILE__)
    sample_options = File.expand_path("../../sample/all.sample.xml", __FILE__)

    force = find_arg(['--force']).present?
    force_props = find_arg(['--force-properties']).present?
    force_config = find_arg(['--force-config']).present?
    app_type = find_arg(['--app-type'])
    server_version = find_arg(['--server-version'])

    # Check for required --server-version argument value
    if (!server_version.present? || server_version == '--server-version' || !(%w(4 5 6 7).include? server_version))
      server_version = prompt_server_version
    end

    error_msg = []
    if !force && !force_props && File.exists?(build_properties)
      error_msg << "build.properties has already been created."
    else
      #create clean properties file
      FileUtils.cp sample_properties, build_properties

      properties_file = File.read(build_properties)

      # replace the appname if one is provided
      name = ARGV.shift
      properties_file.gsub!(/app-name=roxy/, "app-name=#{name}") if name

      # do app-type customizations
      properties_file.gsub!(/app-type=mvc/, "app-type=#{app_type}")

      # If this app will use the ML REST API, we need rewrite-resolved-globally to get those URLs to work
      if ["rest", "hybrid"].include? app_type
        properties_file.gsub!(/rewrite-resolves-globally=/, "rewrite-resolves-globally=true")
      end

      if app_type == "rest"
        # rest applications don't use Roxy's MVC structure, so they can use MarkLogic's rewriter and error handler
        properties_file.gsub!(/url-rewriter=\/roxy\/rewrite.xqy/, "url-rewriter=/MarkLogic/rest-api/rewriter.xqy")
        properties_file.gsub!(/error-handler=\/roxy\/error.xqy/, "error-handler=/MarkLogic/rest-api/error-handler.xqy")
      end

      # replace the text =random with a random string
      o = (33..126).to_a
      properties_file.gsub!(/=random/) do |match|
        random = (0...20).map{ o[rand(o.length)].chr }.join
        "=#{random}"
      end

      # Update properties file to set server-version to value specified on command-line
      properties_file.gsub!(/server-version=6/, "server-version=#{server_version}")

      # save the replacements
      open(build_properties, 'w') {|f| f.write(properties_file) }
    end

    # If this is a rest or hybrid app, set up some initial options
    if ["rest", "hybrid"].include? app_type
      FileUtils.mkdir_p rest_ext_dir
      FileUtils.mkdir_p rest_transforms_dir
      FileUtils.mkdir_p options_dir
      FileUtils.cp sample_options, options_file
      FileUtils.cp(
        File.expand_path("../../sample/properties.sample.xml", __FILE__),
        File.expand_path("../../../rest-api/config/properties.xml", __FILE__))
    end

    target_config = File.expand_path(ServerConfig.properties["ml.config.file"], __FILE__)

    if !force && !force_config && File.exists?(target_config)
      error_msg << "ml-config.xml has already been created."
    else
      #create clean marklogic configuration file
      FileUtils.cp sample_config, target_config
    end

    raise HelpException.new("init", error_msg.join("\n")) if error_msg.length > 0
  end

  def self.initcpf
    sample_config = File.expand_path("../../sample/pipeline-config.sample.xml", __FILE__)
    target_config = File.expand_path("../../pipeline-config.xml", __FILE__)

    force = find_arg(['--force']).present?
    if !force && File.exists?(target_config)
      raise HelpException.new("initcpf", "cpf configuration has already been created.")
    else
      FileUtils.cp sample_config, target_config
    end
  end

  def self.prompt_server_version
    puts 'Required option --server-version=[version] not specified with valid value.

What is the version number of the target MarkLogic server? [4, 5, 6, or 7]'
    server_version = $stdin.gets.chomp.to_i
    server_version = 6 if server_version == 0
    server_version
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
    collation = "http://marklogic.com/collation/" if collation.blank?
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
    existing = File.read(config_path)
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
    collation = request_collation if scalar_type == "string"
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
    collation = request_collation if scalar_type == "string" # string
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
    elsif @server_version == 5 || @server_version == 6
      r = execute_query_5 query, properties
    else
      r = execute_query_7 query, properties
    end

    raise ExitException.new(r.body) unless r.code.to_i == 200

    return r
  end

  def restart
    group = ARGV.shift
    if group
      logger.info "Restarting MarkLogic Server group #{group} on #{@hostname}"
    else
      logger.info "Restarting MarkLogic Server on #{@hostname}"
    end
    setup = File.read File.expand_path('../xquery/setup.xqy', __FILE__)
    r = execute_query %Q{#{setup} setup:do-restart("#{group}")}
  end

  def self.plugin
    # get src dir and package details
    properties = ServerConfig.properties
    src_dir = properties["ml.xquery.dir"]
    plugin_command = ARGV.shift if ARGV.length
    package = ARGV.shift if ARGV.length
    package_version = ARGV.shift if ARGV.length

    runme = %Q{cd #{src_dir} && }
    if is_windows?
      runme << File.expand_path("../depx-0.1/depx.bat", __FILE__)
    else
      runme << File.expand_path("../depx-0.1/depx", __FILE__)
    end
    runme << " #{plugin_command}" if plugin_command
    runme << " #{package} " if package
    runme << " #{package_version} " if package_version
    logger.debug runme

    logger.info `#{runme}`
  end

  def config
    logger.info get_config
  end

  def bootstrap
    raise ExitException.new("Bootstrap requires the target environment's hostname to be defined") unless @hostname.present?

    logger.info "Bootstrapping your project into MarkLogic on #{@hostname}..."
    setup = File.read(File.expand_path('../xquery/setup.xqy', __FILE__))
    r = execute_query %Q{#{setup} setup:do-setup(#{get_config})}

    logger.debug r.body

    if r.body.match("<error:error")
      logger.error r.body
      logger.error "... Bootstrap FAILED"
      return false
    else
      if r.body.match("(note: restart required)")
        logger.warn "************************************"
        logger.warn "*** RESTART OF MARKLOGIC IS REQUIRED"
        logger.warn "************************************"
      end
      logger.info "... Bootstrap Complete"
      return true
    end
  end

  def wipe
    logger.info "Wiping MarkLogic setup for your project on #{@hostname}..."
    setup = File.read(File.expand_path('../xquery/setup.xqy', __FILE__))
    r = execute_query %Q{#{setup} setup:do-wipe(#{get_config})}
    logger.debug r.body

    if r.body.match("<error:error")
      logger.error r.body
      logger.error "... Wipe FAILED"
      return false
    else
      if r.body.match("(note: restart required)")
        logger.warn "************************************"
        logger.warn "*** RESTART OF MARKLOGIC IS REQUIRED"
        logger.warn "************************************"
      end
      logger.info "... Wipe Complete"
      return true
    end
  end

  def validate_install
    logger.info "Validating your project installation into MarkLogic on #{@hostname}..."
    setup = File.read(File.expand_path('../xquery/setup.xqy', __FILE__))
    begin
      r = execute_query %Q{#{setup} setup:validate-install(#{get_config})}
      logger.info "code: #{r.code.to_i}"
      logger.info r.body

      if r.body.match("<error:error")
        logger.error r.body
        result = false
      else
        logger.info "... Validation SUCCESS"
        result = true
      end
    rescue Net::HTTPFatalError => e
      logger.error e.response.body
      logger.error "... Validation FAILED"
      result = false
    end
    result
  end

  def deploy
    what = ARGV.shift
    raise HelpException.new("deploy", "Missing WHAT") unless what

    case what
      when 'content'
        deploy_content
      when 'modules'
        deploy_modules
      when 'schemas'
        deploy_schemas
      when 'cpf'
        deploy_cpf
      else
        raise HelpException.new("deploy", "Invalid WHAT")
    end
  end

  def load
    dir = ARGV.shift
    db = find_arg(['--db']) || @properties['ml.content-db']
    remove_prefix = find_arg(['--remove-prefix'])
    remove_prefix = File.expand_path(remove_prefix) if remove_prefix
    quiet = find_arg(['--quiet'])

    add_prefix = find_arg(['--add-prefix'])

    raise HelpException.new("load", "File or Directory is required!") unless dir
    count = load_data dir, :remove_prefix => remove_prefix, :add_prefix => add_prefix, :db => db, :quiet => quiet
    logger.info "\nLoaded #{count} #{pluralize(count, "document", "documents")} from #{dir} to #{xcc.hostname}:#{xcc.port}/#{db} at #{DateTime.now.strftime('%m/%d/%Y %I:%M:%S %P')}\n"
  end

  def load_data(dir, options = {})
    batch_override = find_arg(['--batch'])
    batch = @environment != "local" && batch_override.blank? || batch_override.to_b

    options[:batch_commit] = batch
    options[:permissions] = permissions(@properties['ml.app-role'], Roxy::ContentCapability::ER) unless options[:permissions]
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
    raise HelpException.new("clean", "Missing WHAT") unless what

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
      else
        raise HelpException.new("clean", "Invalid WHAT")
    end
  end

  #
  # Invokes unit tests for the project
  #
  def test
    if @environment == "prod"
      logger.error "There is no Test database on the Production server"
    else
      if find_arg(['--skip-suite-teardown']).present?
        suiteTearDown = "&runsuiteteardown=false"
      else
        suiteTearDown = "&runsuiteteardown=true"
      end
      if find_arg(['--skip-test-teardown']).present?
        testTearDown = "&runteardown=false"
      else
        testTearDown = "&runteardown=true"
      end
      r = go %Q{http://#{@hostname}:#{@properties["ml.test-port"]}/test/list}, "get"
      suites = []
      r.body.split(">").each do |line|
        suites << line.gsub(/.*suite path="([^"]+)".*/, '\1').strip if line.match("suite path")
      end

      suites.each do |suite|
        r = go %Q{http://#{@hostname}:#{@properties["ml.test-port"]}/test/run?suite=#{url_encode(suite)}&format=junit#{suiteTearDown}#{testTearDown}}, "get"
        logger.info r.body
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
      statuses << line.gsub(/.*<job:status>([^<]+)<\/job:status>/, '\1').strip if line.match("job:status")
    end

    completed_count = 0
    failed_count = 0
    statuses.each do |status|
      if status == "completed"
        completed_count = completed_count + 1
      elsif status == "failed"
        failed_count = failed_count + 1
      end
    end

    completed = (completed_count + failed_count) == statuses.size

    return completed, failed_count
  end

  def recordloader
    filename = ARGV.shift
    raise HelpException.new("recordloader", "configfile is required!") unless filename
    properties_file = File.expand_path("../../#{filename}", __FILE__)
    properties = ServerConfig.load_properties(properties_file, "")
    properties = ServerConfig.substitute_properties(properties, @properties, "")

    properties.each do |k, v|
      logger.debug "#{k}=#{v}"
    end

    prop_string = ""
    properties.each do |k,v|
      prop_string << %Q{-D#{k}="#{v}" }
    end

    runme = %Q{java -cp #{File.expand_path("../java/recordloader.jar", __FILE__)}#{path_separator}#{File.expand_path("../java/marklogic-xcc-5.0.2.jar", __FILE__)}#{path_separator}#{File.expand_path("../java/xpp3-1.1.4c.jar", __FILE__)} #{prop_string} com.marklogic.ps.RecordLoader}
    logger.info runme
    `#{runme}`
  end

  def xqsync
    filename = ARGV.shift
    raise HelpException.new("xqsync", "configfile is required!") unless filename
    properties_file = File.expand_path("../../#{filename}", __FILE__)
    properties = ServerConfig.load_properties(properties_file, "")
    properties = ServerConfig.substitute_properties(properties, @properties, "")

    properties.each do |k, v|
      logger.debug "#{k}=#{v}"
    end
    prop_string = ""
    properties.each do |k,v|
      prop_string << %Q{-D#{k}="#{v}" }
    end

    runme = %Q{java -Xmx2048m -cp #{File.expand_path("../java/xqsync.jar", __FILE__)}#{path_separator}#{File.expand_path("../java/marklogic-xcc-5.0.2.jar", __FILE__)}#{path_separator}#{File.expand_path("../java/xstream-1.4.2.jar", __FILE__)}#{path_separator}#{File.expand_path("../java/xpp3-1.1.4c.jar", __FILE__)} -Dfile.encoding=UTF-8 #{prop_string} com.marklogic.ps.xqsync.XQSync}
    logger.info runme
    `#{runme}`
  end

  def corb
    connection_string = %Q{xcc://#{@properties['ml.user']}:#{@properties['ml.password']}@#{@properties['ml.server']}:#{@properties['ml.xcc-port']}/#{@properties['ml.content-db']}}
    collection_name = find_arg(['--collection']) || '""'
    xquery_module = find_arg(['--modules'])
    uris_module = find_arg(['--uris']) || '""'


    raise HelpException.new("corb", "modules is required") if xquery_module.blank?
    raise HelpException.new("corb", "uris or collection is required ") if uris_module == '""' && collection_name == '""'

    xquery_module = xquery_module.reverse.chomp("/").reverse
    uris_module = uris_module.reverse.chomp("/").reverse
    thread_count = find_arg(['--threads']) || "1"
    thread_count = thread_count.to_i
    module_root = find_arg(['--root']) || '"/"'
    modules_database = @properties['ml.modules-db']
    install = find_arg(['--install']) == "true" || uris_module == '""'

    # Find the XCC jar
    matches = Dir.glob(File.expand_path("../java/*xcc*.jar", __FILE__))
    raise "Missing XCC Jar." if matches.length == 0
    xcc_file = matches[0]

    if install
      # If we're installing, we need to change directories to the source
      # directory, so that the xquery_modules will be visible with the
      # same path that will be used to see it in the modules database.
      Dir.chdir(@properties['ml.xquery.dir']) do
        runme = %Q{java -cp #{File.expand_path("../java/corb.jar", __FILE__)}#{path_separator}#{xcc_file} com.marklogic.developer.corb.Manager #{connection_string} #{collection_name} #{xquery_module} #{thread_count} #{uris_module} #{module_root} #{modules_database} #{install}}
        logger.info runme
        `#{runme}`
      end
    else
      runme = %Q{java -cp #{File.expand_path("../java/corb.jar", __FILE__)}#{path_separator}#{xcc_file} com.marklogic.developer.corb.Manager #{connection_string} #{collection_name} #{xquery_module} #{thread_count} #{uris_module} #{module_root} #{modules_database} #{install}}
      logger.info runme
      `#{runme}`
    end
  end

  def credentials
    logger.info "credentials #{@environment}"
    # ml will error on invalid environment
    # ask user for admin username and password
    puts "What is the admin username?"
    user = gets.chomp
    puts "What is the admin password?"
    # we don't want to install highline
    # we can't rely on STDIN.noecho with older ruby versions
    system "stty -echo"
    password = gets.chomp
    system "stty echo"

    # Create or update environment properties file
    filename = "#{@environment}.properties"
    properties = {}
    properties_file = File.expand_path("../#{filename}", File.dirname(__FILE__))
    begin
      if (File.exists?(properties_file))
        properties = ServerConfig.load_properties(properties_file, "")
      else
        logger.info "#{properties_file} does not yet exist"
      end
    rescue => err
      puts "Exception: #{err}"
    end
    properties["user"] = user
    properties["password"] = password
    open(properties_file, 'w') {
      |f|
      properties.each do |k,v|
        f.write "#{k}=#{v}\n"
      end
    }
    logger.info "wrote #{properties_file}"
  end

  def capture

    if @properties['ml.app-type'] != 'rest'
      raise ExitException.new("This is a #{@properties['ml.app-type']} application; capture only works for app-type=rest")
    end

    target_db = find_arg(['--modules-db'])

    if target_db == nil
      raise HelpException.new("capture", "modules-db is required")
    end

    tmp_dir = Dir.mktmpdir
    logger.debug "using temp dir " + tmp_dir
    logger.info "Retrieving source and REST config from #{target_db}..."

    save_files_to_fs(target_db, "#{tmp_dir}/src")

    # set up the options
    FileUtils.cp_r(
      "#{tmp_dir}/src/#{@properties['ml.group']}/" + target_db.sub("-modules", "") + "/rest-api/.",
      @properties['ml.rest-options.dir']
    )
    FileUtils.rm_rf("#{tmp_dir}/src/#{@properties['ml.group']}/")

    # If we have an application/custom directory, we've probably done a capture
    # before. Don't overwrite that directory. Kill the downloaded custom directory
    # to avoid overwriting.
    if Dir.exists? "#{@properties["ml.xquery.dir"]}/application/custom"
      FileUtils.rm_rf("#{tmp_dir}/src/application/custom")
    end

    FileUtils.cp_r("#{tmp_dir}/src/.", @properties["ml.xquery.dir"])

    FileUtils.rm_rf(tmp_dir)
  end

private

  def save_files_to_fs(target_db, target_dir)
    # Get the list of URIs. We get them in order because Ruby's Dir.mkdir
    # command doesn't have a -p option (create parent).
    dirs = execute_query %Q{
      xquery version "1.0-ml";

      for $uri in cts:uris()
      order by $uri
      return $uri
    },
    { :db_name => target_db }

    # target_dir gets created when we do mkdir on "/"
    if ['5', '6'].include? @properties['ml.server-version']
      # In ML5 and ML6, the response was a bunch of text. Split on the newlines.
      dirs.body.split(/\r?\n/).each do |uri|
        if (uri.end_with?("/"))
          # create the directory so that it will exist when we try to save files
          Dir.mkdir("#{target_dir}" + uri)
        else
          r = execute_query %Q{
            fn:doc("#{uri}")
          },
          { :db_name => target_db }

          File.open("#{target_dir}#{uri}", 'w') { |file| file.write(r.body) }
        end
      end
    else
      # In ML7, the response is JSON
      # [
      #  {"qid":null, "type":"string", "result":"\/"},
      #  {"qid":null, "type":"string", "result":"\/application\/"}
      #  ...
      JSON.parse(dirs.body).each do |item|
        uri = item['result']
        if (uri.end_with?("/"))
          # create the directory so that it will exist when we try to save files
          Dir.mkdir("#{target_dir}" + uri)
        else
          r = execute_query %Q{
            fn:doc("#{uri}")
          },
          { :db_name => target_db }

          body = JSON.parse(r.body)[0]['result']
          File.open("#{target_dir}#{uri}", 'w') { |file| file.write(body) }
        end
      end
    end

  end

  # Build an array of role/capability objects.
  def permissions(role, capabilities)
    if capabilities.is_a?(Array)
      capabilities.map do |c|
        {
          :capability => c,
          :role => role
        }
      end
    else
      [
        {
          :capability => capabilities,
          :role => role
        }
      ]
    end
  end

  def deploy_tests?(target_db)
    @properties['ml.test-content-db'].present? &&
    @properties['ml.test-port'].present? &&
    @environment != "prod" &&
    @properties['ml.test-modules-db'] == target_db
  end

  def modules_databases
    dbs = [@properties['ml.modules-db']]
    dbs << @properties['ml.test-modules-db'] if @properties['ml.test-modules-db'].present? &&
                                                @properties['ml.test-modules-db'] != @properties['ml.modules-db']
    dbs
  end

  def deploy_modules
    test_dir = @properties['ml.xquery-test.dir']
    xquery_dir = @properties['ml.xquery.dir']
    # modules_db = @properties['ml.modules-db']
    app_config_file = File.join xquery_dir, "/app/config/config.xqy"
    test_config_file = File.join test_dir, "/test-config.xqy"
    load_html_as_xml = @properties['ml.load-html-as-xml']

    modules_databases.each do |dest_db|
      ignore_us = []
      ignore_us << "^#{test_dir}.*$" unless test_dir.blank? || deploy_tests?(dest_db)
      ignore_us << "^#{app_config_file}$"
      ignore_us << "^#{test_config_file}$"

      total_count = load_data xquery_dir,
                              :add_prefix => "/",
                              :remove_prefix => xquery_dir,
                              :db => dest_db,
                              :ignore_list => ignore_us,
                              :load_html_as_xml => load_html_as_xml

      if File.exist? app_config_file
        buffer = File.read app_config_file
        @properties.each do |k, v|
          buffer.gsub!("@#{k}", v)
        end

        total_count += xcc.load_buffer "/config.xqy",
                                       buffer,
                                       :db => dest_db,
                                       :add_prefix => File.join(@properties["ml.modules-root"], "app/config"),
                                       :permissions => permissions(@properties['ml.app-role'], Roxy::ContentCapability::ER)
      end

      if deploy_tests?(dest_db) && File.exist?(test_config_file)
        buffer = File.read test_config_file
        @properties.each do |k, v|
          buffer.gsub!("@#{k}", v)
        end

        total_count += xcc.load_buffer "/test-config.xqy",
                                       buffer,
                                       :db => dest_db,
                                       :add_prefix => File.join(@properties["ml.modules-root"], "test"),
                                       :permissions => permissions(@properties['ml.app-role'], Roxy::ContentCapability::EXECUTE)
      end

      # REST API applications need some files put into a collection.
      if ['rest', 'hybrid'].include? @properties["ml.app-type"]
        r = execute_query %Q{
            xquery version "1.0-ml";

            for $uri in cts:uri-match("/marklogic.rest.*")
            return xdmp:document-set-collections($uri, "http://marklogic.com/extension/plugin")
          },
          { :db_name => dest_db }

        if (@properties.has_key?('ml.rest-options.dir') && File.exist?(@properties['ml.rest-options.dir']))
          total_count += load_data @properties['ml.rest-options.dir'],
              :add_prefix => "/#{@properties['ml.group']}/#{@properties['ml.app-name']}/rest-api",
              :remove_prefix => @properties['ml.rest-options.dir'],
              :db => dest_db
        else
          logger.error "Could not find REST API options directory: #{@properties['ml.rest-options.dir']}\n";
        end

      end

      logger.info "\nLoaded #{total_count} #{pluralize(total_count, "document", "documents")} from #{xquery_dir} to #{xcc.hostname}:#{xcc.port}/#{dest_db} at #{DateTime.now.strftime('%m/%d/%Y %I:%M:%S %P')}\n"
    end

    if ['rest', 'hybrid'].include? @properties["ml.app-type"]
      if (@properties.has_key?('ml.rest-ext.dir') && File.exist?(@properties['ml.rest-ext.dir']))
        logger.info "\nLoading REST extensions from #{@properties['ml.rest-ext.dir']}\n"
        mlRest.install_extensions(File.expand_path(@properties['ml.rest-ext.dir']))
      end

      if (@properties.has_key?('ml.rest-transforms.dir') && File.exist?(@properties['ml.rest-transforms.dir']))
        logger.info "\nLoading REST transforms from #{@properties['ml.rest-transforms.dir']}\n"
        mlRest.install_transforms(File.expand_path(@properties['ml.rest-transforms.dir']))
      end
    end
  end

  def deploy_schemas
    if @properties.has_key?('ml.schemas-db')
      schema_db = @properties['ml.schemas-db']
    else
      logger.info "\nWarning: app-specific schemas database not defined. Deploying schemas to the Schemas database. The clean and wipe commands will not remove these schemas.\n"
      schema_db = "Schemas"
    end
    total_count = load_data @properties["ml.schemas.dir"],
      :add_prefix => @properties["ml.schemas-root"],
      :remove_prefix => @properties["ml.schemas.dir"],
      :db => schema_db
    logger.info "\nLoaded #{total_count} #{pluralize(total_count, "schema", "schemas")} from #{@properties["ml.schemas.dir"]} to #{xcc.hostname}:#{xcc.port}/#{schema_db}\n"
  end

  def clean_modules
    logger.info "Cleaning #{@properties['ml.modules-db']} on #{@hostname}"
    execute_query %Q{xdmp:forest-clear(xdmp:forest("#{@properties['ml.modules-db']}"))}

    if @properties['ml.test-modules-db'].present? && @properties['ml.test-modules-db'] != @properties['ml.modules-db']
      logger.info "Cleaning #{@properties['ml.test-modules-db']} on #{@hostname}"
      execute_query %Q{xdmp:forest-clear(xdmp:forest("#{@properties['ml.test-modules-db']}"))}
    end
  end

  def clean_schemas
    if @properties['ml.schemas-db']
      logger.info "Cleaning #{@properties['ml.schemas-db']} on #{@hostname}"
      execute_query %Q{xdmp:forest-clear(xdmp:forest("#{@properties['ml.schemas-db']}"))}
    else
      logger.error "No schemas db is configured"
    end
  end

  def clean_triggers
    if @properties['ml.triggers-db']
      logger.info "Cleaning #{@properties['ml.triggers-db']} on #{@hostname}"
      execute_query %Q{xdmp:forest-clear(xdmp:forest("#{@properties['ml.triggers-db']}"))}
    else
      logger.error "No triggers db is configured"
    end
  end

  def deploy_content
    count = load_data @properties["ml.data.dir"],
                      :remove_prefix => @properties["ml.data.dir"],
                      :db => @properties['ml.content-db'],
                      :permissions => permissions(@properties['ml.app-role'], Roxy::ContentCapability::RU)
    logger.info "\nLoaded #{count} #{pluralize(count, "document", "documents")} from #{@properties["ml.data.dir"]} to #{xcc.hostname}:#{xcc.port}/#{@properties['ml.content-db']}\n"
  end

  def clean_content
    logger.info "Cleaning #{@properties['ml.content-db']} on #{@hostname}"
    execute_query %Q{
      for $id in xdmp:database-forests(xdmp:database("#{@properties['ml.content-db']}"))
      return
        xdmp:forest-clear($id)
    }
  end

  def deploy_cpf
    if @properties["ml.triggers-db"].blank? || @properties["ml.data.dir"].blank?
      logger.error "To use CPF, you must define the triggers-db property in your build.properties file"
    elsif !File.exist?(File.expand_path("../../pipeline-config.xml", __FILE__))
      logger.error <<-ERR.strip_heredoc
        Before you can deploy CPF, you must define a configuration. Steps:
        1. Run 'ml initcpf'
        2. Edit deploy/pipeline-config.xml to set up your domain and pipelines
        3. Run 'ml <env> deploy cpf')
      ERR
    else
      cpf_config = File.read File.expand_path("../../pipeline-config.xml", __FILE__)
      @properties.each do |k, v|
        cpf_config.gsub!("@#{k}", v)
      end
      cpf_code = File.read File.expand_path('../xquery/cpf.xqy', __FILE__)
      r = execute_query %Q{#{cpf_code} cpf:load-from-config(#{cpf_config})}, :db_name => @properties["ml.content-db"]
    end
  end

  def clean_cpf
    cpf_code = File.read File.expand_path('../xquery/cpf.xqy', __FILE__)
    r = execute_query %Q{#{cpf_code} cpf:clean-cpf()}, :db_name => @properties["ml.content-db"]
  end

  def xcc
    @xcc ||=
      begin
        password_prompt
        @xcc = Roxy::Xcc.new({
          :user_name => @ml_username,
          :password => @ml_password,
          :xcc_server => @hostname,
          :xcc_port => @properties["ml.xcc-port"],
          :logger => logger
        })
      end
  end

  def mlRest
    if (!@mlRest)
      @mlRest = Roxy::MLRest.new({
        :user_name => @ml_username,
        :password => @ml_password,
        :server => @hostname,
        :port => @properties["ml.app-port"],
        :logger => @logger
      })
    else
      @mlRest
    end
  end

  def get_config
    @config ||= build_config(@options[:config_file])
  end

  def execute_query_4(query, properties)
    r = go "http://#{@hostname}:#{@bootstrap_port}/use-cases/eval2.xqy", "post", {}, {
      :queryInput => query
    }
  end

  def get_any_db_id
    r = go "http://#{@hostname}:#{@bootstrap_port}/manage/LATEST/databases?format=xml", "get"
    return nil unless r.code.to_i == 200
    dbid = $1 if r.body =~ /.*<idref>([^<]+)<\/idref>.*/
  end

  def get_db_id(db_name)
    r = go "http://#{@hostname}:#{@bootstrap_port}/manage/LATEST/databases?format=xml", "get"
    return nil unless r.code.to_i == 200

    use_next_line = false
    r.body.split("\n").each do |line|
      if use_next_line == true
        dbid = $1 if line =~ /.*<idref>([^<]+)<\/idref>.*/
        return dbid
      end

      use_next_line = true if line.match(db_name)
    end

    nil
  end

  def get_sid(app_name)
    r = go "http://#{@hostname}:#{@bootstrap_port}/manage/LATEST/servers?format=xml", "get"
    return nil unless r.code.to_i == 200

    previous_line = ""
    r.body.split("\n").each do |line|
      if line.match "<nameref>#{app_name}</nameref>"
        dbid = $1 if previous_line =~ /.*<idref>([^<]+)<\/idref>.*/
        return dbid
      end

      previous_line = line
    end

    nil
  end

  def execute_query_5(query, properties = {})
    # We need a context for this query. Here's what we look for, in order of preference:
    # 1. A caller-specified database
    # 2. A caller-specified application server
    # 3. An application server that is present by default
    # 4. Any database
    if properties[:db_name] != nil
      db_id = get_db_id(properties[:db_name])
    elsif properties[:app_name] != nil
      sid = get_sid(properties[:app_name])
    else
      sid = get_sid("Manage")
    end

    db_id = get_any_db_id if db_id.nil? && sid.nil?

    if db_id.present?
      logger.debug "using dbid: #{db_id}"
      r = go "http://#{@hostname}:#{@qconsole_port}/qconsole/endpoints/eval.xqy", "post", {}, {
        :dbid => db_id,
        :resulttype => "text",
        :q => query
      }
      logger.debug r.body
    else
      logger.debug "using sid: #{sid}"
      r = go "http://#{@hostname}:#{@qconsole_port}/qconsole/endpoints/eval.xqy", "post", {}, {
        :sid => sid,
        :resulttype => "text",
        :q => query
      }
      logger.debug r.body
    end

    raise ExitException.new(JSON.pretty_generate(JSON.parse(r.body))) if r.body.match(/\{"error"/)

    r
  end

  def execute_query_7(query, properties = {})
    # We need a context for this query. Here's what we look for, in order of preference:
    # 1. A caller-specified database
    # 2. A caller-specified application server
    # 3. An application server that is present by default
    # 4. Any database
    if properties[:db_name] != nil
      db_id = get_db_id(properties[:db_name])
    elsif properties[:app_name] != nil
      sid = get_sid(properties[:app_name])
    else
      sid = get_sid("Manage")
    end

    db_id = get_any_db_id if db_id.nil? && sid.nil?

    if db_id.present?
      logger.debug "using dbid: #{db_id}"
      r = go("http://#{@hostname}:#{@qconsole_port}/qconsole/endpoints/evaler.xqy?dbid=#{db_id}&action=eval&querytype=xquery",
             "post",
             {},
             nil,
             query)
    else
      logger.debug "using sid: #{sid}"
      r = go("http://#{@hostname}:#{@qconsole_port}/qconsole/endpoints/evaler.xqy?sid=#{sid}&action=eval&querytype=xquery",
             "post",
             {},
             nil,
             query)
    end

    raise ExitException.new(JSON.pretty_generate(JSON.parse(r.body))) if r.body.match(/\{"error"/)

    r
  end

  def ServerConfig.substitute_properties(sub_me, with_me, prefix = "")
    dangling_vars = {}
    begin
      needs_rescan = false
      sub_me.each do |k,v|
        if v.match(/\$\{basedir\}/)
          sub_me[k] = File.expand_path(v.sub("${basedir}", ServerConfig.pwd))
        else
          matches = v.scan(/\$\{([^}]+)\}/)
          if matches.length > 0
            var = "#{prefix}#{matches[0][0]}"
            sub = with_me[var]
            if sub
              new_val = v.sub(/\$\{[^}]+\}/, sub)
              sub_me[k] = new_val
              needs_rescan = true if matches.length > 1
            else
              dangling_vars[k] = v
            end
          end
        end
      end
    end while (needs_rescan == true)

    sub_me.each do |k,v|
      sub_me[k] = v.xquery_safe
    end

    raise DanglingVarsException.new(dangling_vars) if dangling_vars.length > 0

    sub_me
  end

  def ServerConfig.load_properties(properties_filename, prefix = "")
    properties = {}
    File.open(properties_filename, 'r') do |properties_file|
      properties_file.read.each_line do |line|
        line.strip!
        if (line[0] != ?#) && (line[0] != ?=) && (line[0] != "")
          i = line.index('=')
          if i
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
    config = File.read(config_file)

    # Build the triggers db if it is provided
    if @properties['ml.triggers-db'].present?
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


    config.gsub!("@ml.xdbc-server",
      %Q{
      <xdbc-server>
        <xdbc-server-name>@ml.app-name-xcc</xdbc-server-name>
        <port>@ml.xcc-port</port>
        <database name="@ml.content-db"/>
        <modules name="@ml.modules-db"/>
        <authentication>digest</authentication>
      </xdbc-server>
      }) if @properties['ml.xcc-port'].present?

    config.gsub!("@ml.odbc-server",
      %Q{
      <odbc-server>
        <odbc-server-name>@ml.app-name-odbc</odbc-server-name>
        <port>@ml.odbc-port</port>
        <database name="@ml.content-db"/>
        <modules name="@ml.modules-db"/>
        <authentication>digest</authentication>
      </odbc-server>
      }) if @properties['ml.odbc-port'].present?

    # Build the schemas db if it is provided
    if @properties['ml.schemas-db'].present?
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
    if @properties['ml.test-content-db'].present? &&
       @properties['ml.test-port'].present? &&
       @environment != "prod"
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

      # The modules database for the test server can be different from the app one
      test_modules_db = @properties['ml.test-modules-db']
      if !@properties['ml.test-modules-db'].present?
        test_modules_db = @properties['ml.app-modules-db']
      end
      test_auth_method = @properties['ml.authentication-method']
      if @properties['ml.test-authentication-method'].present?
        test_auth_method = @properties['ml.test-authentication-method']
      end
      test_default_user = @properties['ml.default-user']
      if @properties['ml.test-default-user'].present?
        test_default_user = @properties['ml.test-default-user']
      end

      config.gsub!("@ml.test-appserver",
      %Q{
        <http-server import="@ml.app-name">
          <http-server-name>@ml.app-name-test</http-server-name>
          <port>@ml.test-port</port>
          <database name="@ml.test-content-db"/>
          <modules name="#{test_modules_db}"/>
          <authentication>#{test_auth_method}</authentication>
          <default-user name="#{test_default_user}"/>
        </http-server>
      })

    else
      config.gsub!("@ml.test-content-db-xml", "")
      config.gsub!("@ml.test-content-db-assignment", "")
      config.gsub!("@ml.test-appserver", "")
    end

    # Build the test modules db if it is different from the app modules db
    if @properties['ml.test-modules-db'].present? &&
       @properties['ml.test-modules-db'] != @properties['ml.app-modules-db']
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


    config.gsub!("@ml.forest-data-dir-xml",
      %Q{
        <data-directory>@ml.forest-data-dir</data-directory>
      }) if @properties['ml.forest-data-dir'].present?

    if @properties['ml.rewrite-resolves-globally'].present?
      config.gsub!("@ml.rewrite-resolves-globally",
        %Q{
          <rewrite-resolves-globally>#{@properties['ml.rewrite-resolves-globally']}</rewrite-resolves-globally>
        })
    elsif ['rest', 'hybrid'].include?(@properties["ml.app-type"])
      config.gsub!("@ml.rewrite-resolves-globally",
        %Q{
          <rewrite-resolves-globally>true</rewrite-resolves-globally>
        })
    else
      config.gsub!("@ml.rewrite-resolves-globally", "")
    end
    @properties.each do |k, v|
      config.gsub!("@#{k}", v)
    end

    config
  end

  def ServerConfig.properties(prop_file_location = "../..")
    default_properties_file = File.expand_path("#{prop_file_location}/default.properties", __FILE__)
    properties_file = File.expand_path("#{prop_file_location}/build.properties", __FILE__)
    raise ExitException.new("You must run ml init to configure your application.") unless File.exist?(properties_file)

    properties = ServerConfig.load_properties(default_properties_file, "ml.")
    properties.merge!(ServerConfig.load_properties(properties_file, "ml."))

    environments = properties['ml.environments'].split(",") if properties['ml.environments']
    environments = ["local", "dev", "prod"] unless environments

    environment = find_arg(environments)

    properties["environment"] = environment if environment

    env_properties_file = File.expand_path("#{prop_file_location}/#{environment}.properties", __FILE__)

    properties.merge!(ServerConfig.load_properties(env_properties_file, "ml.")) if File.exists? env_properties_file

    properties = ServerConfig.substitute_properties(properties, properties, "ml.")
  end

end
