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
module Roxy
  class Framework
    def initialize(options)
      @logger = options[:logger]
    end

    def create
      if (ARGV[0] == "model") then
        burn = ARGV.shift #burn model arg

        str = ARGV.shift
        if (str) then
          model, function = str.split('/')
          filename = ARGV.shift || model
          if (model != nil) then
            create_model model, filename, function
          end
        else
          ARGV.unshift(burn)
          Help.doHelp(@logger, "create")
        end
      elsif (ARGV[0] == "test") then
        burn = ARGV.shift #burn test arg

        str = ARGV.shift
        if str
          suite, test = str.split('/')
          if (suite != nil) then
            create_suite suite, test
          end
        else
          ARGV.unshift(burn)
          Help.doHelp(@logger, "create")
        end
      elsif (ARGV[0] == "layout") then
        burn = ARGV.shift #burn test arg

        layout = ARGV.shift
        format = ARGV.shift || "html"

        if (layout != nil) then
          create_layout(layout, format)
        else
          ARGV.unshift(burn)
          Help.doHelp(@logger, "create")
        end
      else
        force = find_arg(['-f']) != nil

        str = ARGV.shift
        if (str) then
          controller, view = str.split('/')

          view = view || "main"

          format = ARGV.shift || "html"
          @logger.debug "controller: #{controller}"
          @logger.debug "view: #{view}\n"
          @logger.debug "format: #{format}\n"

          if (controller != nil and view != nil) then
            if (force == false) then
              view_type = (format != nil and format != "none") ? ((format == "json") ? "a" : "an") + " #{format} view" : "no view"
              print "\nAbout to create a #{view}() function in the #{controller}.xqy controller with #{view_type}. Proceed?\n> "
              answer = gets()
              answer = answer.downcase.strip
              if (answer != "y" and answer != "yes") then
                return
              end
            end

            create_controller controller, view

            if (format != nil and format != "none") then
              create_view controller, view, format
            end
          end
        else
          Help.doHelp(@logger, "create")
        end
      end
    end

    def create_model(model, filename, function)
      target_file = File.expand_path("../../../src/app/models/#{filename}.xqy", __FILE__)
      model_file = nil
      if File.exists? target_file then
        if (function != nil) then
          model_file = File.read(target_file)

          if (model_file.index("m:#{function}()") != nil) then
            @logger.warn "Function #{model}:#{function}() already exists. Skipping..."
            return
          end
        else
          @logger.warn "Model #{model} already exists. Skipping..."
          return
        end
      else
        model_file = File.read(File.expand_path('../templates/model.xqy', __FILE__))
        model_file.gsub!("#model-name", model)
      end

      if (function != nil) then
        model_file << File.read(File.expand_path('../templates/model-function.xqy', __FILE__))
        model_file.gsub!("#function-name", function)
      end
      File.open(target_file, 'w') { |f| f.write(model_file) }
    end

    def create_suite(suite, test)
      suite_dir = File.expand_path("../../../src/test/suites/#{suite}/", __FILE__)
      Dir.mkdir(suite_dir) unless Dir.exist?(suite_dir)

      if (test)
        target_file = "#{suite_dir}/#{test}.xqy"

        test_file = nil
        if File.exists? target_file then
          @logger.warn "Test #{test} already exists. Skipping..."
          return
        else
          test_file = open(File.expand_path('../templates/test.xqy', __FILE__)).readlines.join
        end

        File.open(target_file, 'a') {|f| f.write(test_file) }
      end
    end

    def create_layout(layout, format)
      layout_dir = File.expand_path("../../../src/app/views/layouts/", __FILE__)
      Dir.mkdir(layout_dir) unless Dir.exist?(layout_dir)

      target_file = "#{layout_dir}/#{layout}.#{format}.xqy"

      layout_file = nil
      if File.exists? target_file then
        @logger.warn "Layout #{layout}.#{format} already exists. Skipping..."
        return
      else
        layout_file = File.expand_path("../templates/layout.#{format}.xqy", __FILE__)
        layout_file = File.expand_path("../templates/layout.xqy", __FILE__) unless File.exists?(layout_file)
      end

      File.open(target_file, 'a') {|f| f.write(File.read(layout_file)) }
    end


    def create_controller(controller, view)
      target_file = File.expand_path("../../../src/app/controllers/#{controller}.xqy", __FILE__)
      controller_file = nil
      if File.exists? target_file then
        existing = open(target_file).readlines.join

        if (existing.index("c:#{view}()") != nil) then
          @logger.warn "function #{controller}:#{view}() already exists. Skipping..."
          return
        end
        controller_file = open(File.expand_path('../templates/controller-function.xqy', __FILE__)).readlines.join
      else
        controller_file = open(File.expand_path('../templates/controller.xqy', __FILE__)).readlines.join
      end

      controller_file.gsub!("#controller-name", controller)
      controller_file.gsub!("#function-name", view)
      File.open(target_file, 'a') {|f| f.write(controller_file) }
    end

    def create_view(controller, view, format)
      dir = File.expand_path("../../../src/app/views/#{controller}/", __FILE__)
      if File.directory?(dir) == false
        Dir.mkdir(dir)
      end

      out_file = "#{dir}/#{view}.#{format}.xqy"

      template_file = File.expand_path("../templates/view.#{format}.xqy", __FILE__)
      template_file = File.expand_path("../templates/view.xqy", __FILE__) unless File.exists?(template_file)

      if File.exists?(out_file) == false then
        view_template = open(template_file).readlines.join
        view_template.gsub!("#location", out_file)
        view_template.gsub!("#controller", controller)
        view_template.gsub!("#view", view)
        File.open(out_file, 'w') {|f| f.write(view_template) }
      else
        @logger.warn "View #{out_file} already exists. Skipping..."
      end
    end
  end
end