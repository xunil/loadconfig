require 'rubygems'
require 'net/ssh'
require 'rexml/document'

include REXML

module Juniper
  class JUNOScript
    def initialize(hostname, username, options = {})
      ssh_opts = {}
      [:keys, :logger, :password, :forward_agent].each do |key|
        ssh_opts[key] = options[key] if options.has_key?(key)
      end
      @session = Net::SSH.start(hostname, username, options = ssh_opts)
      @logger = @session.logger
    end

    def rpc_request(xml)
      exec(junoscript(rpc(xml)))
    end

    def exec(xml)
      buffer = Net::SSH::Buffer.new
      @session.open_channel do |channel|
        channel.exec("junoscript") do |ch, success|
          if success
            if block_given?
              yield channel
            else
              # Construct XML document
              doc = Document.new(xml.to_s)
              doc << XMLDecl.new

              # Send to JunOS device
              @logger.debug "sending data: #{doc.to_s}"
              channel.send_data(doc.to_s)
              channel.on_data {|ch, data| buffer.append(data)}
              channel.on_extended_data {|ch, type, data| @logger.warn "Extended data (type #{type}) received: #{data}"}
            end
          else
            channel.close
            return nil
          end
        end
      end
      @session.loop
      buffer.read
    end

    def junoscript(elements)
      js = Element.new('junoscript')
      js.attributes['version'] = '1.0'
      # REXML::Element overrides #to_a, this is the only way to support passing of
      # single elements or arrays of elements
      [elements].flatten.each do |element|
        js << ( element.class == REXML::Element ? element : Document.new(element).root )
      end
      @logger.debug "in junoscript: js=#{js.to_s}"
      js
    end

    def rpc(xml)
      rpc = Element.new('rpc')
      rpc << ( xml.class == REXML::Element ? xml : Document.new(xml).root )
      rpc
    end
  end
end


