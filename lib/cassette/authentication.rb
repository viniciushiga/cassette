# encoding: UTF-8

module Cassette
  class Authentication
    def self.method_missing(name, *args)
      @default_authentication ||= new
      @default_authentication.send(name, *args)
    end

    def initialize(opts = {})
      self.config = opts.fetch(:config, Cassette.config)
      self.logger = opts.fetch(:logger, Cassette.logger)
      self.http   = opts.fetch(:http_client, Cassette::Http::Request)
      self.cache  = opts.fetch(:cache, Cassette::Authentication::Cache.new(logger))
    end

    def validate_ticket(ticket, service = config.service)
      logger.debug "Cassette::Authentication validating ticket: #{ticket}, #{service}"
      fail Cassette::Errors::AuthorizationRequired if ticket.blank?

      user = ticket_user(ticket, service)
      logger.info "Cassette::Authentication user: #{user.inspect}"

      fail Cassette::Errors::Forbidden unless user

      user
    end

    def ticket_user(ticket, service = config.service)
      cache.fetch_authentication(ticket, service) do
        begin
          logger.info("Validating #{ticket} on #{validate_uri}")

          response = http.post(validate_uri, ticket: ticket, service: service).body
          ticket_response = Http::TicketResponse.new(response)

          logger.info("Validation resut: #{response.inspect}")

          Cassette::Authentication::User.new(
            login: ticket_response.login,
            name: ticket_response.name,
            authorities: ticket_response.authorities,
            ticket: ticket,
            config: config
          ) if ticket_response.login
        rescue => exception
          logger.error "Error while authenticating ticket #{ticket}: #{exception.message}"
          raise Cassette::Errors::Forbidden, exception.message
        end
      end
    end

    protected

    attr_accessor :cache, :logger, :http, :config

    def try_content(node, *keys)
      keys.inject(node) do |a, e|
        a.try(:[], e)
      end.try(:[], '__content__')
    end

    def extract_user(xml, ticket)
      ActiveSupport::XmlMini.with_backend('LibXML') do
        result = ActiveSupport::XmlMini.parse(xml)

        login = try_content(result, 'serviceResponse', 'authenticationSuccess', 'user')

        if login
          attributes = result['serviceResponse']['authenticationSuccess']['attributes']
          name = try_content(attributes, 'cn')
          authorities = try_content(attributes, 'authorities')

          Cassette::Authentication::User.new(login: login, name: name, authorities: authorities,
                                             ticket: ticket, config: config)
        end
      end
    end

    def validate_uri
      "#{config.base.gsub(/\/?$/, '')}/serviceValidate"
    end
  end
end
