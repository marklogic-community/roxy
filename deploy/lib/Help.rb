class Help
  def self.usage
    <<-DOC.strip_heredoc

      Usage: ml ENVIRONMENT COMMAND [ARGS]

      Deployment Commands:
       init           Creates configuration files for you to customize
       initcpf        Creates cpf configuration files for you to customize
       info           Return settings for a given environment
       credentials    Configures user and password for a given environment
       bootstrap      Configures your application on the MarkLogic server
       wipe           Remove your configuration from the MarkLogic server
       restart        Restart your MarkLogic server
       deploy         Loads modules, data, cpf configuration into the server
       load           Loads a file or folder into the server
       clean          Removes all files from the cpf, modules, or content databases
       info           Prints the environment-specific configuration information
       test           Runs xquery unit tests
       recordloader   Runs RecordLoader
       xqsync         Runs XQSync
       corb           Runs Corb

      Roxy Scaffolding commands:
       create       Creates a controller or view or model
       index        Adds an index to the configuration
       extend       Create a REST API service extension
       transform    Create a REST API transformation

      Other commands:
       upgrade      Upgrades the Roxy files
       capture      Capture the source code of an existing App Builder application

      All commands can be run with -h for more information.

    DOC
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
        -v, [--verbose]  # Verbose output

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
      Usage: ml {env} restart [group] [options]

      General options:
        -v, [--verbose]  # Verbose output

      Restart the MarkLogic process in the given environment on each host in the
      specified group. If no group is specified, restart the MarkLogic process
      on each host in the group to which the target host belongs.
    DOC
  end

  def self.bootstrap
    <<-DOC.strip_heredoc
      Usage: ml {env} bootstrap [options]

      General options:
        -v, [--verbose]  # Verbose output

      Bootstraps your application to the MarkLogic server in the given
      environment.
    DOC
  end

  def self.wipe
    <<-DOC.strip_heredoc
      Usage: ml {env} wipe [options]

      General options:
        -v, [--verbose]  # Verbose output

      Removes all traces of your application on the MarkLogic serverin the given
      environment.
    DOC
  end

  def self.deploy
    <<-DOC.strip_heredoc
      Usage: ml {env} deploy WHAT [options]

      General options:
        -v, [--verbose]  # Verbose output
        --batch=(yes|no) # enable or disable batch commit. By default
                           batch is disabled for the local environment
                           and enabled for all others.

      Please choose a WHAT below.

        modules # deploys code to your modules db in the given environment
        content # deploys content to your content db in the given environment
        schemas # deploys schemas to your schemas db in the given environment
        cpf     # deploys your cpf config to the server in the given environment
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

        modules # removes all data from the modules db in the given environment
        content # removes all data from the content db in the given environment
        schemas # removes all data from the schemas db in the given environment
        cpf     # removes your cpf config from the server in the given environment
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
        will create a sample.xsl file in your rest-transform directory,
        using the "ex" namespace prefix.

      Example:
        $ ml transform sample
        will create a sample.xsl file in your rest-transform directory.

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
        Captures the source and REST API configuration for an existing
        Application Builder-based application.

      modules-db: (required)
        The modules database of the App Builder application.
    DOC
  end

  def self.doHelp(logger, command, error_message = nil)
    logger.error "#{error_message}\n" if error_message
	  logger.info Help.send(command)
  end
end
