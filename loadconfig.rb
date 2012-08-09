#!/usr/bin/ruby
require 'optparse'
require 'rubygems'
require 'rexml/document'
require 'erubis'
# Ugly hack required for net/ssh
ENV['HOME'] = '/'
require File.join(File.dirname(__FILE__), "lib", "juniper", "junoscript")

module Juniper
  class ConfigLoader
    def initialize(options)
      @ssh_opts = {}
      @ssh_opts[:keys] = [options[:ssh_key]] unless options[:ssh_key].nil?
      @ssh_opts[:password] = options[:password] unless options[:password].nil?
      @ssh_opts[:forward_agent] = options[:forward_agent] unless options[:forward_agent].nil?
      @override = options[:override]
      @dryrun = options[:dryrun]
      @debug = options[:debug]
      @js = Juniper::JUNOScript.new(options[:hostname], options[:username], options = @ssh_opts)
    end

    def load(filename)
      config_text = File.open(filename).read()
      eruby = Erubis::Eruby.new(config_text)

      reply = @js.rpc_request('<get-configuration/>')
      current_config = Document.new(reply)
      context = {:current_config => current_config}

      config_changes = Element.new('load-configuration')
      config_changes.attributes['format'] = 'text'
      config_changes.attributes['action'] = @override ? 'override' : 'merge'
      config_changes.add_element('configuration-text').text = eruby.evaluate(context)

      success, request, reply = commit_config(config_changes, check=@dryrun)
      puts "DEBUG: Request: #{request}" if @debug
      puts "DEBUG: Reply: #{reply}" if @debug
      return success
    end

    def commit_config(config_changes, check)
      private_config = Element.new('open-configuration')
      private_config.add_element('private')
      commit_tag = Element.new('commit-configuration')
      if check
        commit_tag.add_element('check')
      else
        log = Element.new('log')
        log.text = "Committed by loadconfig.rb"
        commit_tag << log
      end
      elements = [@js.rpc(private_config), @js.rpc(config_changes), @js.rpc(commit_tag)]
      request = @js.junoscript(elements)

      reply = @js.exec(request)
      reply_doc = Document.new(reply)
      success_xpath = (check ? '//commit-check-success' : '//commit-success')
      if (!XPath.match(reply_doc, "//xnm:error").empty?) or (XPath.match(reply_doc, success_xpath).empty?)
        return false, request.to_s, reply
      end
      return true, request.to_s, reply
    end
  end
end
options = {:dryrun => false, :debug => false, :username => ENV['USER']}

optparse = OptionParser.new do |opts|
  opts.on('-u', '--username=USERNAME', 'Juniper username') do |username|
    options[:username] = username
  end

  opts.on('-p', '--password=PASSWORD', 'Juniper password') do |password|
    options[:password] = password
  end

  opts.on('-k', '--ssh-key=KEYFILE', 'Juniper SSH key filename') do |ssh_key|
    options[:ssh_key] = ssh_key
  end

  opts.on('-A', '--forward-agent', 'Enable SSH agent forwarding') do
    options[:forward_agent] = true
  end

  opts.on('-H', '--hostname=HOSTNAME', 'Hostname of Juniper device') do |hostname|
    options[:hostname] = hostname
  end

  opts.on('-f', '--filename=FILENAME', 'Filename of configuration snippet to load') do |filename|
    options[:filename] = filename
  end

  opts.on('-o', '--override', 'Override entire existing config') do
    options[:override] = true
  end

  opts.on('-n', '--dryrun', 'Verify configuration commit would succeed but do not commit') do
    options[:dryrun] = true
  end

  opts.on('-d', '--debug', 'Output JunOScript interactions') do
    options[:debug] = true
  end

  opts.on('-h', '--help', 'Display usage message') do
    puts opts
    exit
  end
end

begin
  optparse.parse!
  mandatory = [:hostname, :filename]
  missing = mandatory.select {|param| options[param].nil?}
  if not missing.empty?
    puts "Missing required options: #{missing.join(', ')}"
    puts optparse
    exit
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit
end

loader = Juniper::ConfigLoader.new(options)
success = loader.load(options[:filename])

puts "%s %s%s" % [options[:hostname], (options[:dryrun] ? "check " : ""), (success ? "success" : "fail")]
exit((success ? 0 : 1))
