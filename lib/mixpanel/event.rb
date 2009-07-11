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
      @logger = Object.const_get(:RAILS_DEFAULT_LOGGER)
    end
    
    def record( name, props = {}, request = nil )
      uri = URI.parse( generate_url(name, props, {}, request) )
      
      req = Net::HTTP::Get.new("#{uri.path}?#{uri.query}")
      res = Net::HTTP.start(uri.host, uri.port) {|http|
        http.request(req)
      }
      if( res != 200 )
        error = "Failed to log event:#{name}, properties:#{props.inspect}"
        if( @logger )
          @logger.error( error )
        else
          STDERR.puts( error )
        end
      end
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
      
      encoded = Base64::encode64(event_props.to_json)[0..-2]
      params[:data] = encoded
      param_strings = []
      params.each_pair {|key,val|
        param_strings << "#{key}=#{CGI.escape(val)}"
      }
      url = "#{@@endpoint}/track/?#{param_strings.join('&')}"
      return url
    end
  end
end
