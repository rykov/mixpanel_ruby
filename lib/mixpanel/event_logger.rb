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
    
    def record( name, props = {}, request = nil )
      send_request( generate_url(name, props, {}, request) )
    end
    
    def record_funnel( funnel, step, goal )
      send_request( generate_funnel_url(funnel, step, goal) )
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
      if( !props[:ip] && request.respond_to?(:remote_ip) )
        event_props[:ip] = request.remote_ip
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
      
      if( !res.is_a?(Net::HTTPSuccess) )
        error = "Failed to log event:#{name}, properties:#{props.inspect}"
        if( @logger )
          @logger.error( error )
        else
          STDERR.puts( error )
        end
        return false
      end
      return true
    end
  end
end
