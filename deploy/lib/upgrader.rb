###############################################################################
# Copyright 2013 MarkLogic Corporation
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

require 'tmpdir'
require 'util'

module Roxy
  class Upgrader

    def initialize(options)
      @logger = options[:logger]
      @app_type = options[:properties]["ml.app-type"]
      @no_prompt = options[:no_prompt]
    end

    def upgrade_deploy(tmp_dir)
      Dir.entries(tmp_dir + '/deploy').each do |entry|
        if !['app_specific.rb', '.', '..'].include? entry
          # check whether this is a file or directory. The cp_r command needs to be different
          if Dir.exist?(tmp_dir + '/deploy/' + entry)
            FileUtils.cp_r tmp_dir + '/deploy/' + entry + '/.', './deploy/' + entry
          else
            FileUtils.cp_r tmp_dir + '/deploy/' + entry, './deploy'
          end
        end
      end
    end

    def upgrade_src(tmp_dir)
      FileUtils.cp_r tmp_dir + '/src/roxy/.', './src/roxy'
    end

    def upgrade_base(tmp_dir)
      FileUtils.cp tmp_dir + '/CHANGELOG.mdown', '.'
      FileUtils.cp tmp_dir + '/ml', '.'
      FileUtils.cp tmp_dir + '/ml.bat', '.'
      FileUtils.cp tmp_dir + '/version.txt', '.'
    end

    def upgrade(args)
      if @no_prompt
        raise ExitException.new("--no-prompt parameter prevents prompting for input")
      else
        fork = find_arg(['--fork']) || 'marklogic'
        branch = find_arg(['--branch'])
        raise HelpException.new("upgrade", "Missing branch name") unless branch

        print "This command will attempt to upgrade to the latest Roxy files.\n"
        print "Before running this command, you should have checked all your code\n"
        print "into a source code repository, such as Git or Subversion. Doing so\n"
        print "will make it much easier to fix problems if something goes wrong.\n"

        print "\nAre you ready to proceed? [y/N]\n"
        confirm = STDIN.gets.chomp

        if confirm.match(/^y(es)?$/i)
          @logger.info "Upgrading to the #{branch} branch from #{fork}/roxy"
          tmp_dir = Dir.mktmpdir

          @logger.info "Cloning Roxy in a temp directory..."
          system("git clone git://github.com/#{fork}/roxy.git -b #{branch} #{tmp_dir}")

          @logger.info "Upgrading base project files\n"
          upgrade_base(tmp_dir)

          @logger.info "Upgrading deploy/ files\n"
          upgrade_deploy(tmp_dir)

          if (["mvc", "hybrid"].include? @app_type)
            @logger.info "Upgrading src/roxy files\n"
            upgrade_src(tmp_dir)
          end

          FileUtils.rm_rf(tmp_dir)
        else
          puts "Aborting upgrade"
        end
      end
    end

  end
end
