require 'json'
require 'securerandom'
require 'time'

module Backtrace

class Uploader

    def initialize(token, url)
        @token = token
        @url = url
    end


    def upload_error(processed)
        puts "Uploading to %s/%s" % [
            @url, @token
        ]
        puts processed.to_json
    end

end

class Report

    attr_accessor :uuid
    attr_accessor :timestamp
    attr_accessor :threads
    attr_accessor :mainThread

    def initialize
        self.uuid = SecureRandom.hex(16)
        self.timestamp = Time.now.to_i

        self.threads = Thread.list.map do |t|
            processed = Report.process_thread t
            [processed[:name], processed]
        end.to_h

        self.mainThread = "main"
    end

    def lang
        'ruby'
    end

    def langVersion
        RUBY_VERSION
    end

    def agent
        'backtrace-ruby'
    end

    def agentVersion
        '0.1.0'
    end

    def to_hash
        fields = [
            :uuid, :timestamp, :lang, :langVersion, :agent, :agentVersion,
            :mainThread, :threads,
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
end

class << self
    attr_accessor :token
    attr_accessor :url
end

end

at_exit do
    if $! and $!.class != SystemExit
    # if $! and $!.class <= StandardError
        report = Backtrace::Report.new
        report.add_exception_data $!
        up = Backtrace::Uploader.new Backtrace.token, Backtrace.url
        up.upload_error report.to_hash
    end
end