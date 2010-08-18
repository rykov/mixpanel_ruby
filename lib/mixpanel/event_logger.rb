require 'base64'
require 'json'
require 'net/http'
require 'uri'
require 'cgi'

module Mixpanel
  class EventLogger
    @@endpoint = 'http://api.mixpanel.com'
    
    attr_accessor :logger
    
    def initialize( token )
      @token = token
      if( Object.const_defined?(:RAILS_DEFAULT_LOGGER) )
        @logger = Object.const_get(:RAILS_DEFAULT_LOGGER)
      end
    end
    
    #
    ## Record an event
    # event_logger.record('Landing', { :distinct_id => 1 })
    #
    ## Record a funnel goal
    # event_logger.record('Landing', { :distinct_id => 1, :funnel => ['Signup', 1] })
    #
    ## Record a funnel goal and an event
    # event_logger.record('Landing', { :distinct_id => 1, :funnel => ['Signup', 1], :event => true })
    #

    def record( name, props = {}, request = nil )
      event  = props.delete(:event)
      funnel = props.delete(:funnel)

      record_event(name, props, request) if funnel.nil? || event
      record_funnel(funnel[0], funnel[1], name, props, request) if funnel
    end

    def record_event( name, props = {}, request = nil )
      send_request( generate_url(name, props, {}, request) ) ||
      on_failure("Failed to log event:#{name}, properties:#{props.inspect}")
    end
    
    def record_funnel( funnel, step, goal, props = {}, request = nil )
      send_request( generate_funnel_url(funnel, step, goal, props, {}, request) ) ||
      on_failure("Failed to log funnel:#{funnel}/#{step}/#{goal}, properties:#{props.inspect}")
    end
    
    # details of which params are allowed, see:
    # http://mixpanel.com/api/docs/specification/
    # data will be generated based on name, and props
    # request is a ActionController::AbstractRequest object
    # we'll attempt to fill in the ip address if given
    def generate_url( name, props = {}, params = {}, request = nil )
      event_props = props.dup
      event_props[:token] = @token
      event_props[:time] = Time.now.to_i if( !props[:time] )
      if( request.respond_to?(:remote_ip) )
        event_props[:ip] = request.remote_ip if( !props[:ip] )
        event_props[:distinct_id] = request.remote_ip if( !props[:distinct_id] )
      end
      
      data = { :event => name, :properties => event_props }
      encoded = Base64::encode64(data.to_json).gsub(/\s/, '')
      params[:data] = encoded
      param_strings = []
      params.each_pair {|key,val|
        param_strings << "#{key}=#{CGI.escape(val)}"
      }
      url = "#{@@endpoint}/track/?#{param_strings.join('&')}"
      return url
    end
    
    def generate_funnel_url( funnel, step, goal, props = {}, params = {}, request = nil )
      return generate_url( 'mp_funnel',
        props.merge( :funnel => funnel, :step => step, :goal => goal ),
        params, request )
    end
    
  protected
    
    def send_request( url )
      uri = URI.parse( url )
      req = Net::HTTP::Post.new(uri.path)
      req.body = uri.query
      res = Net::HTTP.start(uri.host, uri.port) {|http|
        http.request(req)
      }
      
      return res.is_a?(Net::HTTPSuccess)
    end

    def on_failure(error)
      @logger ? @logger.error( error ) : STDERR.puts( error )
      return false
    end
  end
end
