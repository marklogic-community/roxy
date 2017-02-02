###############################################################################
# Copyright 2012-2017 MarkLogic Corporation
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
module Password

  def self.jruby?
    RUBY_PLATFORM =~ /java/i
  end

  def self.ask_for_password_on_ruby(prompt = "Enter password: ")
    print prompt
    STDIN.noecho(&:gets).chomp
  end

  def self.ask_for_password_on_jruby(prompt = "Enter password: ")
    require 'java'
    java_import 'java.lang.System'
    java_import 'java.io.Console'

    $stderr.print prompt
    $stderr.flush

    console = System.console()
    return unless console != java.null
    java.lang.String.new(console.readPassword()).to_s.strip
  end

  def self.password_prompt(prompt = "Enter password: ")
    if jruby? then
      self.ask_for_password_on_jruby(prompt)
    else
      self.ask_for_password_on_ruby(prompt)
    end
  end
end
