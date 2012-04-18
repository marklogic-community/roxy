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
        ARGV.shift #burn model arg

        model, function = ARGV.shift.split('/')
        filename = ARGV.shift || model
        if (model != nil) then
          create_model model, filename, function
        end
      else
        force = find_arg(['-f']) != nil
        controller, view = ARGV.shift.split('/')

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
      end
    end

    def create_model(model, filename, function)
      target_file = File.expand_path("../../../src/app/models/#{model}.xqy", __FILE__)
      model_file = nil
      if File.exists? target_file then
        if (function != nil) then
          existing = open(target_file).readlines.join

          if (existing.index("m:#{function}()") != nil) then
            @logger.warn "function #{model}:#{function}() already exists. Skipping..."
            return
          end
          model_file = open(File.expand_path('../templates/model-function.xqy', __FILE__)).readlines.join
        else
          @logger.warn "Model #{model} already exists. Skipping..."
        end
      else
        model_file = open(File.expand_path('../templates/model.xqy', __FILE__)).readlines.join
      end

      model_file.gsub!("#model-name", model)
      if (function != nil) then
        model_file.gsub!("#function-name", function)
      end
      File.open(target_file, 'a') {|f| f.write(model_file) }
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