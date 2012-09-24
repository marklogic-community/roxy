class Help
  def self.create
  	sub_cmd = ARGV.shift
  	case sub_cmd
      when 'controller'
	  	%Q{
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
}
      when 'model'
	  	%Q{
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
}
      when 'test'
	  	%Q{
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
}
      when 'layout'
	  	%Q{
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
}
      else
    		%Q{
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
}
    end
  end

  def self.info
    %Q{
Usage: ml {env} info [options]

General options:
  -v, [--verbose]  # Verbose output

Displays the properties for the given environment}
  end

  def self.init
    %Q{
Usage: ml init [options]

General options:
  -v, [--verbose]  # Verbose output

Initializes your application by creating the necessary config files}
  end

  def self.initcpf
    %Q{
Usage: ml initcpf [options]

General options:
  -v, [--verbose]  # Verbose output

Initializes the necessary config files for cpf}
  end

  def self.restart
    %Q{
Usage: ml {env} restart [group] [options]

General options:
  -v, [--verbose]  # Verbose output

Restart the MarkLogic process in the given environment on each host in the
specified group. If no group is specified, restart the MarkLogic process
on each host in the group to which the target host belongs.}
  end

  def self.bootstrap
    %Q{
Usage: ml {env} bootstrap [options]

General options:
  -v, [--verbose]  # Verbose output

Bootstraps your application to the MarkLogic server in the given
environment.}
  end

  def self.wipe
    %Q{
Usage: ml {env} wipe [options]

General options:
  -v, [--verbose]  # Verbose output

Removes all traces of your application on the MarkLogic serverin the given
environment.}
  end

  def self.deploy
    %Q{
Usage: ml {env} deploy WHAT [options]

General options:
  -v, [--verbose]  # Verbose output
  --batch=(yes|no) # enable or disable batch commit. By default
                     batch is disabled for the local environment
                     and enabled for all others.

Please choose a WHAT below.

  modules # deploys code to your modules db in the given environment
  content # deploys content to your content db in the given environment
  cpf     # deploys your cpf config to the server in the given environment}
  end

  def self.clean
    %Q{
Usage: ml {env} clean WHAT [options]

General options:
  -v, [--verbose]  # Verbose output

Please choose a WHAT below.

  modules # removes all data from the modules db in the given environment
  content # removes all data from the content dv in the given environment
  cpf     # removes your cpf config from the server in the given environment}
  end

  def self.test
    %Q{
Usage: ml {env} test [options]

General options:
  -v, [--verbose]       # Verbose output
  --skip-test-teardown  # Skip teardown after each test
  --skip-suite-teardown # Skip teardown after each suite

Runs your xquery unit tests on the given environment}
  end

  def self.recordloader
    %Q{
Usage: ml {env} recordloader configfile [options]

configfile must be a relative or absolute path to a Java properties file.
See http://marklogic.github.com/recordloader/

General options:
  -v, [--verbose]  # Verbose output

Runs recordloader with the given properties file. Properties files employ
variable substitution.

You may use variables like:

INPUT_PATH=${ml.data.dir}/}
  end

  def self.xqsync
    %Q{
Usage: ml {env} xqsync configfile [options]

configfile must be a relative or absolute path to a Java properties file.
See http://marklogic.github.com/xqsync/

General options:
  -v, [--verbose]  # Verbose output

Runs xqsync with the given properties file. Properties files employ variable
substitution.

You may use variables like:

INPUT_PACKAGE=${ml.data.dir}/}
  end

  def self.plugin
    %Q{
Usage: ml {env} plugin [command] [package] [version] [options]

command:
  (install|remove|list|refresh)

package:
  Name of a depx package

version:
  Package Version

General options:
  -v, [--verbose]  # Verbose output}
  end

  def self.index
    %Q{
Usage: ml index
  ml will ask questions to help you build an index
    }
  end

  def self.doHelp(logger, command)
		logger.formatter = proc { |severity, datetime, progname, msg|
	    "#{msg}\n"
	  }

	  logger.info(eval("Help.#{command}"))
  end
end