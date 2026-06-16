# frozen_string_literal: true

module ApiSteward
  # Holds how api_steward should read a request. An instance can be created and passed
  # explicitly (handy for tests or running more than one), or the global one set up via
  # ApiSteward.configure can be used.
  class Configuration
    attr_reader :version_source, :version_header, :version_param

    def initialize
      @version_source = :path
      @version_header = "X-Api-Version"
      @version_param  = "version"
    end

    # Tell api_steward where to find the API version in a request.
    #
    #   version_from :path                            # /api/v1/...
    #   version_from :header, name: "X-Api-Version"
    #   version_from :param,  name: "version"
    def version_from(source, name: nil)
      @version_source = source
      case source
      when :header then @version_header = name if name
      when :param  then @version_param  = name if name
      end
      self
    end
  end
end
