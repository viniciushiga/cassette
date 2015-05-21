module Cassette
  class Version
    MAJOR = '1'
    MINOR = '0'
    PATCH = '16'

    def self.version
      [MAJOR, MINOR, PATCH].join('.')
    end
  end
end
