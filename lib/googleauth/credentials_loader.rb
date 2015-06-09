# Copyright 2015, Google Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#     * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'memoist'
require 'rbconfig'

module Google
  # Module Auth provides classes that provide Google-specific authorization
  # used to access Google APIs.
  module Auth
    # CredentialsLoader contains the behaviour used to locate and find default
    # credentials files on the file system.
    module CredentialsLoader
      extend Memoist
      ENV_VAR = 'GOOGLE_APPLICATION_CREDENTIALS'

      PRIVATE_KEY_VAR = 'GOOGLE_PRIVATE_KEY'
      CLIENT_EMAIL_VAR = 'GOOGLE_CLIENT_EMAIL'
      CLIENT_ID_VAR = 'GOOGLE_CLIENT_ID'
      CLIENT_SECRET_VAR = 'GOOGLE_CLIENT_SECRET'
      REFRESH_TOKEN_VAR = 'GOOGLE_REFRESH_TOKEN'
      ACCOUNT_TYPE_VAR = 'GOOGLE_ACCOUNT_TYPE'

      NOT_FOUND_ERROR =
        "Unable to read the credential file specified by #{ENV_VAR}"
      WELL_KNOWN_PATH = 'gcloud/application_default_credentials.json'
      WELL_KNOWN_ERROR = 'Unable to read the default credential file'

      # determines if the current OS is windows
      def windows?
        RbConfig::CONFIG['host_os'] =~ /Windows|mswin/
      end
      memoize :windows?

      # make_creds proxies the construction of a credentials instance
      #
      # By default, it calls #new on the current class, but this behaviour can
      # be modified, allowing different instances to be created.
      def make_creds(*args)
        new(*args)
      end

      # Creates an instance from the path specified in an environment
      # variable.
      #
      # @param scope [string|array|nil] the scope(s) to access
      def from_env(scope = nil)
        if ENV.key?(ENV_VAR)
          path = ENV[ENV_VAR]
          fail "file #{path} does not exist" unless File.exist?(path)
          File.open(path) do |f|
            return make_creds(json_key_io: f, scope: scope)
          end
        elsif service_account_env_vars? || authorized_user_env_vars?
          return make_creds(scope: scope)
        end
      rescue StandardError => e
        raise "#{NOT_FOUND_ERROR}: #{e}"
      end

      # Creates an instance from a well known path.
      #
      # @param scope [string|array|nil] the scope(s) to access
      def from_well_known_path(scope = nil)
        home_var, base = windows? ? 'APPDATA' : 'HOME', WELL_KNOWN_PATH
        root = ENV[home_var].nil? ? '' : ENV[home_var]
        base = File.join('.config', base) unless windows?
        path = File.join(root, base)
        return nil unless File.exist?(path)
        File.open(path) do |f|
          return make_creds(json_key_io: f, scope: scope)
        end
      rescue StandardError => e
        raise "#{WELL_KNOWN_ERROR}: #{e}"
      end

      private

      def service_account_env_vars?
        ([PRIVATE_KEY_VAR, CLIENT_EMAIL_VAR] - ENV.keys).empty?
      end

      def authorized_user_env_vars?
        ([CLIENT_ID_VAR, CLIENT_SECRET_VAR, REFRESH_TOKEN_VAR] -
          ENV.keys).empty?
      end
    end
  end
end
