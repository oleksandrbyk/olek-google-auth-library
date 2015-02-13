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

require 'googleauth/signet'
require 'memoist'
require 'multi_json'
require 'openssl'
require 'rbconfig'

# Reads the private key and client email fields from service account JSON key.
def read_json_key(json_key_io)
  json_key = MultiJson.load(json_key_io.read)
  fail 'missing client_email' unless json_key.key?('client_email')
  fail 'missing private_key' unless json_key.key?('private_key')
  [json_key['private_key'], json_key['client_email']]
end

module Google
  # Module Auth provides classes that provide Google-specific authorization
  # used to access Google APIs.
  module Auth
    # Authenticates requests using Google's Service Account credentials.
    #
    # This class allows authorizing requests for service accounts directly
    # from credentials from a json key file downloaded from the developer
    # console (via 'Generate new Json Key').
    #
    # cf [Application Default Credentials](http://goo.gl/mkAHpZ)
    class ServiceAccountCredentials < Signet::OAuth2::Client
      ENV_VAR = 'GOOGLE_APPLICATION_CREDENTIALS'
      NOT_FOUND_PREFIX =
        "Unable to read the credential file specified by #{ENV_VAR}"
      TOKEN_CRED_URI = 'https://www.googleapis.com/oauth2/v3/token'
      WELL_KNOWN_PATH = 'gcloud/application_default_credentials.json'
      WELL_KNOWN_PREFIX = 'Unable to read the default credential file'

      class << self
        extend Memoist

        # determines if the current OS is windows
        def windows?
          RbConfig::CONFIG['host_os'] =~ /Windows|mswin/
        end
        memoize :windows?

        # Creates an instance from the path specified in an environment
        # variable.
        #
        # @param scope [string|array] the scope(s) to access
        def from_env(scope)
          return nil unless ENV.key?(ENV_VAR)
          path = ENV[ENV_VAR]
          fail 'file #{path} does not exist' unless File.exist?(path)
          return new(scope, File.open(path))
        rescue StandardError => e
          raise "#{NOT_FOUND_PREFIX}: #{e}"
        end

        # Creates an instance from a well known path.
        #
        # @param scope [string|array] the scope(s) to access
        def from_well_known_path(scope)
          home_var = windows? ? 'APPDATA' : 'HOME'
          root = ENV[home_var].nil? ? '' : ENV[home_var]
          base = WELL_KNOWN_PATH
          base = File.join('.config', base) unless windows?
          path = File.join(root, base)
          return nil unless File.exist?(path)
          return new(scope, File.open(path))
        rescue StandardError => e
          raise "#{WELL_KNOWN_PREFIX}: #{e}"
        end
      end

      # Initializes a ServiceAccountCredentials.
      #
      # @param scope [string|array] the scope(s) to access
      # @param json_key_io [IO] an IO from which the JSON key can be read
      def initialize(scope, json_key_io)
        private_key, client_email = read_json_key(json_key_io)
        super(token_credential_uri: TOKEN_CRED_URI,
              audience: TOKEN_CRED_URI,  # TODO: confirm this
              scope: scope,
              issuer: client_email,
              signing_key: OpenSSL::PKey::RSA.new(private_key))
      end
    end
  end
end
