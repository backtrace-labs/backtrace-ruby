require 'json'
require 'securerandom'
require 'socket'
require 'time'
require 'uri'
require 'net/http'
require 'net/https'

module Backtrace

class SubmissionTarget

    @@token = ''
    @@url = ''

    def initialize(token, url)
        @token = token
        @url = url
    end

    def submit(processed, ignoreSSL=false)
      uri = URI.parse(@url)
      uri.query = "format=json&token=" + @token
      uri.path = "/api/post"
      req = Net::HTTP::Post.new(uri.request_uri, "Content-Type"=>"application/json")
      req.body = processed.to_json
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      if ignoreSSL
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.request(req)
    end

    def self.token
        @@token
    end

    def self.token=(token)
        @@token = token
    end

    def self.url
        @@url
    end

    def self.url=(url)
        @@url = url
    end
end

class Report

    attr_accessor :uuid
    attr_accessor :timestamp
    attr_accessor :threads
    attr_accessor :mainThread
    attr_accessor :attributes
    attr_accessor :annotations
    attr_accessor :lang
    attr_accessor :langVersion
    attr_accessor :agent
    attr_accessor :agentVersion

    def initialize
        self.uuid = SecureRandom.hex(16)
        self.timestamp = Time.now.to_i

        self.threads = Thread.list.map do |t|
            processed = Report.process_thread t
            [processed[:name], processed]
        end.to_h

        self.mainThread = "main"

        self.attributes = {}
        self.annotations = {}

        add_default_attributes

        self.lang = 'ruby'
        self.langVersion = RUBY_VERSION
        self.agent = 'backtrace-ruby'
        self.agentVersion = '0.1.0'
    end

    def to_hash
        fields = [
            :uuid, :timestamp, :lang, :langVersion, :agent, :agentVersion,
            :mainThread, :threads, :attributes, :annotations
        ]
        fields.map{ |sym| [sym, self.send(sym)] }.to_h
    end

    def to_json
        self.to_hash.to_json
    end

    def Report.make_thread_callstack(t)
        t.backtrace_locations.map do |bl|
            {
                funcName: bl.base_label,
                line: bl.lineno.to_s,
                library: bl.path,
            }
        end
    end

    def Report.process_thread(t)
        name = t == Thread.main ? 'main' : t.object_id.to_s
        fault = Thread.current == t or t.status == nil

        {
            name: name,
            fault: fault,
            stack: Report.make_thread_callstack(t),
        }
    end

    def add_exception_data(e)
        t = Thread.current
        thread_name = name = t == Thread.main ? 'main' : t.object_id.to_s

        self.threads[thread_name][:stack] = Report.make_thread_callstack e
    end

    def add_default_attributes
        self.attributes['application'] = $0
        self.attributes['hostname'] = Socket.gethostname
    end
end

def Backtrace.register_error_handler(token, url)
    SubmissionTarget.token = token
    SubmissionTarget.url = url

    at_exit do
        if $! and $!.class != SystemExit
        # if $! and $!.class <= StandardError
            report = Backtrace::Report.new
            report.add_exception_data $!
            st = SubmissionTarget.new SubmissionTarget.token, SubmissionTarget.url
            st.submit report.to_hash
        end
    end
end

end
