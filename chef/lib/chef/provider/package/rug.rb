#
# Author:: Adam Jacob (<adam@opscode.com>), Jonathan Tron (<opscode@tron.name>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/provider/package'
require 'chef/mixin/command'
require 'chef/resource/package'
require 'singleton'

class Chef
  class Provider
    class Package
      class Rug < Chef::Provider::Package


        def load_current_resource
          @current_resource = Chef::Resource::Package.new(@new_resource.name)
          @current_resource.package_name(@new_resource.package_name)

          is_installed=false
          version=''
          is_out_of_date=false
          oud_version=''
          Chef::Log.debug("Checking rug for #{@new_resource.package_name}")
          status = popen4("rug info #{@new_resource.package_name}") do |pid, stdin, stdout, stderr|
            stdout.each do |line|
              case line
              when /^Version: (.+)$/
                version = $1
                Chef::Log.debug("rug version=#{$1}")
              when /^Installed: Yes$/
                is_installed=true
                Chef::Log.debug("rug installed true")
              when /^Installed: No$/
                is_installed=false
                Chef::Log.debug("rug installed false")
              when /^Status: out-of-date \(version (.+) installed\)$/
                is_out_of_date=true
                oud_version=$1
                Chef::Log.debug("rug out of date version=#{$1}")
              end
            end
          end

          if !is_installed
            @candidate_version=version
            @current_resource.version(nil)
            Chef::Log.debug("rug installed false");
          end

          if is_installed
            if is_out_of_date
              @current_resource.version(oud_version)
              @candidate_version=version
              Chef::Log.debug("rug installed outofdate");
            else
              @current_resource.version(version)
              @candidate_version=version
              Chef::Log.debug("rug installed");
            end
          end


          unless status.exitstatus == 0
            raise Chef::Exceptions::Package, "rug failed - #{status.inspect}!"
          end

          if @candidate_version == ''
            raise Chef::Exceptions::Package, "rug does not have a version of package #{@new_resource.package_name}"
          end
          
          Chef::Log.debug("rug current resource      #{@current_resource}")
          @current_resource
        end

        def install_package(name, version)
          if version
            run_command(
              :command => "rug --quiet install -y --agree-to-third-party-licences #{name}-#{version}"
            )
          else
            run_command(
              :command => "rug --quiet install -y --agree-to-third-party-licences #{name}"
            )
          end
        end

        def upgrade_package(name, version)
          install_package(name, version)
        end

        def remove_package(name, version)
          if version
            run_command(
              :command => "rug --quiet remove -y #{name}-#{version}"
            )
          else
            run_command(
              :command => "rug --quiet remove -y #{name}"
            )
          end


        end

        def purge_package(name, version)
          remove_package(name, version)
        end

      end
    end
  end
end
