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
require 'rbconfig'

def find_arg(args = [])
  args.each do |arg|
    if (ARGV.include?(arg))
      index = ARGV.index(arg)
      ARGV.slice!(index)
      return arg
    end
  end
  nil
end

def is_windows?
  return (Config::CONFIG['host_os'] =~ /mswin|mingw/).nil? == false
end

def path_separator
	is_windows? ? ";" : ":"
end