class Help
  def self.usage
    help = <<-DOC.strip_heredoc

      Usage:
        ml [ENVIRONMENT] COMMAND [ARGS]

      General commands (no environment):
        init          Creates configuration files for you to customize
        initcpf       Creates cpf configuration files for you to customize
        jar           Creates a Roxy jar
        new           Creates a new project directory structure
        upgrade       Upgrades the Roxy files

      Scaffolding commands (no environment):
        create        Creates a controller, model, test or layout
        index         Adds an index to the configuration
        extend        Creates a REST API service extension
        transform     Creates a REST API transformation

      Bootstrapping commands (with environment):
        bootstrap     Configures your application on the given environment
        capture       Captures the source code and if applicable the REST configuration of an existing application
        clean         Removes all files from the cpf, modules, or content databases on the given environment
        credentials   Configures user and password for the given environment
        info          Returns settings for the given environment
        restart       Restarts the given environment
        validate      Compare your ml-config against the given environment
        wipe          Removes your application from the given environment

      Deployment/Data commands (with environment):
        corb          Runs Corb against the given environment
        deploy        Loads modules, data, cpf configuration into the given environment
        load          Loads a file or folder into the given environment
        merge         Merges a database on the given environment
        mlcp          Runs MLCP against the given environment
        recordloader  Runs RecordLoader against the given environment
        reindex       Reindexes a database on the given environment
        settings      Lists all supported settings for a given environment
        test          Runs xquery unit tests against the given environment
        xqsync        Runs XQSync against the given environment
    DOC

    help += app_specific || ''

    help += <<-DOC.strip_heredoc

      All commands can be run with -h or --help for more information.
    DOC

    help
  end

  def self.app_specific
    #stub
  end

  def self.create
  	case ARGV.shift
      when 'controller'
  	  	<<-DOC.strip_heredoc
          Usage: ml create controller[/function] [format] [options]

          General options:
            -v, [--verbose]  # Verbose output

            controller/function is the name of the controller and function.
            The function is optional. If a function is omitted then main is assumed.

            Format can be (none | html | xml | json). If no format is provided then
            html is assumed. When "none" is provided no view is created.

            ex: ml create search/facet
              This will create a controller named search.xqy containing
              a function named search().

              Html is assumed for the format thus a file named
              views/search/facet.html.xqy will be created.
        DOC
      when 'model'
  	  	<<-DOC.strip_heredoc
          Usage: ml create model model_name [file_name] [options]

          General options:
            -v, [--verbose]  # Verbose output

            model_name is the name of the model you wish to create.

            file_name: You may optionally specify a file name. By default
            the file will have the same name as the model.

            ex: ml create model search
              This will create a model named search in /app/models/search.xqy.
              The namespace will be "http://marklogic.com/roxy/models/search".

            ex: ml create model search search-lib.xqy
              This will create a model named search.xqy in /app/models/search-lib.xqy.
              The namespace will be "http://marklogic.com/roxy/models/search".
        DOC
      when 'test'
  	  	<<-DOC.strip_heredoc
          Usage: ml create test suite_name[/test] [options]

          General options:
            -v, [--verbose]  # Verbose output

            suite_name is the name of the suite you wish to create.

            test: You may optionally specify the name of a test. If you omit test
            then only the suite folder will be created

            ex: ml create test users
              This will create a test suite named users in /test/suites/users/.

            ex: ml create model users/login
              This will create a test named login in /test/suites/users/login.xqy.
        DOC
      when 'layout'
  	  	<<-DOC.strip_heredoc
          Usage: ml create layout layout_name [format] [options]

          General options:
            -v, [--verbose]  # Verbose output

            layout_name is the name of the layout you wish to create.

            format can be (html | xml | json). If no format is provided then
            html is assumed.

            ex: ml create layout mobile
              This will create a layout named mobile in /app/views/layouts/mobile.html.xqy.

            ex: ml create layout mobile json
              This will create a layout named mobile in /app/views/layouts/mobile.json.xqy.
        DOC
      else
    		<<-DOC.strip_heredoc
          Usage: ml create controller[/function] [format] [options]   or
                 ml create model model_name [file_name] [options]     or
                 ml create test suite_name [test] [options]           or
                 ml create layout layout_name [format] [options]

          General options:
            -v, [--verbose]  # Verbose output

          For more details on each type use:

          ml create controller -h|--help
          ml create model -h|--help
          ml create test -h|--help
          ml create layout -h|--help
        DOC
    end
  end

  def self.credentials
    <<-DOC.strip_heredoc
      Usage: ml {env} credentials

      Prompts the user for admin credentials and writes them into the appropriate properties file
    DOC
  end

  def self.info
    <<-DOC.strip_heredoc
      Usage: ml {env} info [options]

      General options:
        --format                           # Output format can be (json | xml).
        -v, [--verbose]                    # Verbose output

      Displays the properties for the given environment
    DOC
  end

  def self.init
    <<-DOC.strip_heredoc
      Usage: ml init [application-name] [options]

      Optional Parameters:
        application-name                  # The name of your application
      Required option:
        --server-version=version-number   # Version of target MarkLogic Server
                                          # Must be 4, 5, 6, or 7
      General options:
        --force                           # Force reset all configuration files
        --force-properties                # Force reset the properties file. (build.properties)
        --force-config                    # Force reset the configuration file (ml-config.xml)
        -v, [--verbose]                   # Verbose output


      Initializes your application by creating the necessary config files.
    DOC
  end

  def self.initcpf
    <<-DOC.strip_heredoc
      Usage: ml initcpf [options]

      General options:
        -v, [--verbose]  # Verbose output
        --force          # Force reset the config file

      Initializes the necessary config files for cpf
    DOC
  end

  def self.restart
    <<-DOC.strip_heredoc
      Usage: ml {env} restart [{groupname}|cluster] [options]

      General options:
        -v, [--verbose]  # Verbose output

      Restart the MarkLogic process in the given environment on each host in the
      specified group. If no group is specified, restart the MarkLogic process
      on each host in the group to which the target host belongs. Use 'cluster'
      to restart all hosts within the cluster to which the target belongs.
    DOC
  end

  def self.bootstrap
    <<-DOC.strip_heredoc
      Usage: ml {env} bootstrap [options]

      General options:
        -v, [--verbose]  # Verbose output
        --apply-changes=[WHAT]

      Bootstraps your application to the MarkLogic server in the given
      environment.

      --apply-changes allows for a granular application of changes to a given
      environment. Multiple changes may be specified, seperated by commas.
      Changes may include:
        ssl, privileges, roles, users, external-security, mimetypes, groups,
        hosts, forests, databases, amps, indexes, appservers, tasks
    DOC
  end

  def self.wipe
    <<-DOC.strip_heredoc
      Usage: ml {env} wipe [options]

      General options:
        -v, [--verbose]  # Verbose output
        --apply-changes=[WHAT]

      Removes all traces of your application on the MarkLogic serverin the given
      environment.

      --apply-changes allows for a granular application of changes to a given
      environment. Multiple changes may be specified, seperated by commas.
      Changes may include:
        ssl, privileges, roles, users, external-security, mimetypes, groups,
        hosts, forests, databases, amps, indexes, appservers, tasks
    DOC
  end

  def self.deploy
    <<-DOC.strip_heredoc
      Usage: ml {env} deploy WHAT [options]

      General options:
        -v, [--verbose]        # Verbose output
        --batch=(yes|no)       # enable or disable batch commit. By default
                                 batch is disabled for the local environment
                                 and enabled for all others.
        --incremental=(yes|no) # For content, only deploy files which are
                                 newer locally than on the server

      Please choose a WHAT below.

        modules     # deploys all code to your modules db in the given environment
        content     # deploys content to your content db in the given environment
        schemas     # deploys schemas to your schemas db in the given environment
        cpf         # deploys your cpf config to the server in the given environment
        src         # deploys the src code to your modules db in the given environment
        rest        # deploys properties, extensions, and transforms to our modules db in the given environment
        ext         # deploys your rest extensions to the server in the given environment
                    if a name is specified, then only that extension will be deployed
        transform   # deploys your rest extensions to the server in the given environment
                    if a name is specified, then only that transform will be deployed
        triggers    # deploys triggers from deploy/triggers-config.xml to your triggers database
    DOC
  end

  def self.merge
    <<-DOC.strip_heredoc
      Usage: ml {env} merge WHAT [options]

      General options:
        -v, [--verbose]  # Verbose output

      Please choose a WHAT below.

        content     # Merges your content db in the given environment
    DOC
  end

  def self.reindex
    <<-DOC.strip_heredoc
      Usage: ml {env} reindex WHAT [options]

      General options:
        -v, [--verbose]  # Verbose output

      Please choose a WHAT below.

        content     # Reindexes your content db in the given environment
    DOC
  end

  def self.load
    <<-DOC.strip_heredoc
      Usage: ml {env} load {/path/to/file-to-load} [options]

      General options:
        -v, [--verbose]                   # Verbose output
        --db=your-db-name                 # The name of the database to load into
                                            defaults to your content database
        --remove-prefix=/prefix/to/remove # The file path prefix to remove
    DOC
  end

  def self.clean
    <<-DOC.strip_heredoc
      Usage: ml {env} clean WHAT [options]

      General options:
        -v, [--verbose]  # Verbose output

      Please choose a WHAT below.

        modules  # removes all data from the modules db in the given environment
        content  # removes all data from the content db in the given environment
        schemas  # removes all data from the schemas db in the given environment
        cpf      # removes your cpf config from the server in the given environment
        triggers # removes all triggers from your triggers database
    DOC
  end

  def self.test
    <<-DOC.strip_heredoc
      Usage: ml {env} test [options]

      General options:
        -v, [--verbose]       # Verbose output
        --skip-test-teardown  # Skip teardown after each test
        --skip-suite-teardown # Skip teardown after each suite

      Runs your xquery unit tests on the given environment
    DOC
  end

  def self.recordloader
    <<-DOC.strip_heredoc
      Usage: ml {env} recordloader configfile [options]

      configfile must be a relative or absolute path to a Java properties file.
      See http://marklogic.github.com/recordloader/

      General options:
        -v, [--verbose]  # Verbose output

      Runs recordloader with the given properties file. Properties files employ
      variable substitution.

      You may use variables like:

      INPUT_PATH=${ml.data.dir}/
    DOC
  end

  def self.xqsync
    <<-DOC.strip_heredoc
      Usage: ml {env} xqsync configfile [options]

      configfile must be a relative or absolute path to a Java properties file.
      See http://marklogic.github.com/xqsync/

      General options:
        -v, [--verbose]  # Verbose output

      Runs xqsync with the given properties file. Properties files employ variable
      substitution.

      You may use variables like:

      INPUT_PACKAGE=${ml.data.dir}/
    DOC
  end

  def self.corb
    <<-DOC.strip_heredoc
      Usage: ml {env} corb [options]

      See: http://marklogic.github.com/corb/index.html

      Required options:
        --modules=/path/to/modules.xqy  # the xquery module to process the data

        (Only one of the following is required)
        --collection=collection-name    # the name of a collection to process
        --uris=/path/to/uris-module.xqy # path to a uris module

      Corb Options:
        --threads=1                     # the thread count to use
        --root=/                        # the root of the modules database
        --install=false                 # whether or not to install (default: false)

      General options:
        -v, [--verbose]  # Verbose output
    DOC
  end

  def self.mlcp
    <<-DOC.strip_heredoc
      Usage: ml {env} mlcp [options]

      Runs MLCP with given command-line options agains selected environment.
      MLCP supports options files natively using the -options_file parameter.
      The path to the MLCP options file must be an absolute path or a relative
      path from the root of the project directory.
      See http://docs.marklogic.com/guide/ingestion/content-pump#chapter

      General options:
        -v, [--verbose]  # Verbose output
        -h, [--help]     # Shows this help

      Roxy applies variable substitution within option files. You may use variables like:

      -input_file_path
      ${data.dir}
    DOC
  end

  def self.plugin
    <<-DOC.strip_heredoc
      Usage: ml {env} plugin [command] [package] [version] [options]

      command:
        (install|remove|list|refresh)

      package:
        Name of a depx package

      version:
        Package Version

      General options:
        -v, [--verbose]  # Verbose output
    DOC
  end

  def self.index
    <<-DOC.strip_heredoc
      Usage: ml index
        ml will ask questions to help you build an index
    DOC
  end

  def self.extend
    <<-DOC.strip_heredoc
      Usage: ml extend [prefix:]extension
        Create a REST API service extension with the provided name. If a prefix
        is provided, it will be used in the extension module.

        Example:
          $ ml extend ml:tag
          will create a tag.xqy library module in your rest-ext directory, using
          the "ml" prefix for the functions.
    DOC
  end

  def self.transform
    <<-DOC.strip_heredoc
      Usage: ml transform [prefix:]name [type]
        Create a REST API transformation with the provided name. By default,
        the transform will be XSLT.

      prefix:
        The prefix will be used as the namespace prefix.

      name:
        This name will be used for the file in which the transform is stored
        and the name used when deploying to MarkLogic.

      type:
        (xslt|xqy)

      Example:
        $ ml transform ex:sample
        will create a sample.xslt file in your rest-transform directory,
        using the "ex" namespace prefix.

      Example:
        $ ml transform sample
        will create a sample.xslt file in your rest-transform directory.

      Example:
        $ ml transform sample xqy
        will create a sample.xqy library module in your rest-transform directory,
        using a built-in value as the prefix for the functions.
    DOC
  end

  def self.upgrade
    <<-DOC.strip_heredoc
      Usage: ml upgrade --branch=[dev|master]
        Upgrades Roxy files in the current project, using files from the
        specified branch on GitHub. Any project will have its deploy directory
        upgraded. Projects of app-type "mvc" or "hybrid" will also have their
        src/roxy/ directory upgraded.

      branch: (required)
        The name of the Roxy GitHub branch to use for the upgrade.
    DOC
  end

  def self.capture
    <<-DOC.strip_heredoc
      Usage: ml {env} capture --modules-db=[name of modules database]
		Captures the source for an existing application

	  modules-db: (required)
        The modules database of the application.

	  ml {env} capture --app-builder=[name of Application Builder-based application]
        Captures the source and REST API configuration for an existing
        Application Builder-based application.

      app-builder: (required)
        The name of the App Builder application.
    DOC
  end

  def self.jar
    <<-DOC.strip_heredoc
      Usage: ml jar

      General options:
        -v, [--verbose]                   # Verbose output

      Prerequisites:
        - You must be running JRuby http://jruby.org/
        - You must have the warbler gem installed
          > gem install warbler
    DOC
  end

  def self.doHelp(logger, command, error_message = nil)
    logger.info "" if error_message
    logger.error "#{error_message}" if error_message
	  logger.info Help.send(command)
  end
end
