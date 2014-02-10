module RailsDaemon
  class BackgroundJob
    include Rake::FileUtilsExt

    attr_accessor :name, :log_file, :pid_file, :log_level, :log_device, :sleep_interval

    def initialize(name, &block)
      self.name = name
      setup_defaults
      yield(self) if block_given?
    end

    def perform_with_loop_in_transaction(&block)
      prepare!

      loop do
        begin
          ActiveRecord::Base.transaction do
            yield
          end
        rescue Exception => e
          ActiveRecord::Base.clear_active_connections!
          Rails.logger.error("There was an unknown error.")
          Rails.logger.exception(e)
        end

        sleep sleep_interval
      end
    end

    def perform(&block)
      prepare!
      begin
        yield
      rescue Exception => e
        ActiveRecord::Base.clear_active_connections!
        Rails.logger.error("There was an unknown error.")
        Rails.logger.exception(e)
      end
    end

    private
    def setup_defaults
      self.pid_file ||= (ENV['PID_FILE'] || "#{Rails.root}/tmp/#{self.name}.pid")
      self.log_file ||= (ENV['LOG_FILE'] || "#{Rails.root}/log/#{self.name}.log")
      self.log_level ||= ::Logger::Severity.const_get((ENV['LOG_LEVEL'] || (Rails.env.production? ? 'info' : 'debug')).upcase)
      self.log_device ||= File.open(self.log_file, 'a+')
      self.sleep_interval ||= 5
    end

    def prepare!
      raise "PID file(#{self.pid_file}) exists!" if File.exists?(self.pid_file)

      exit if fork
      Process.setsid
      exit if fork

      $0 = self.name
      @master_pid = Process.pid

      File.open(self.pid_file, 'w') { |f| f.puts(@master_pid) }


      STDIN.reopen "/dev/null" rescue nil
      STDOUT.reopen self.log_device rescue nil
      STDERR.reopen self.log_device rescue nil

      STDOUT.sync = true
      STDERR.sync = true
      self.log_device.sync = true

      self.log_device.puts "#{Time.now.utc}: Starting #{self.name}"
      # setup the DB connection on this process, or else the process does not connect to the DB.
      self.log_device.puts "#{Time.now.utc}: Loading rails environment"
      begin
        ::Rake::Task[:environment].invoke
      rescue => e
        begin
          self.log_device.puts "#{Time.now.utc}: Could not initialize rails environment, bailing out!"
          self.log_device.puts "The error was #{e.message}"
          self.log_device.puts e.backtrace.collect { |l| "    #{l}" }.join("\n")
          self.log_device.close
        rescue
          rm_rf(self.pid_file, :verbose => false)
        end
        abort
      end

      self.log_device.puts "#{Time.now.utc}: Done loading rails environment"

      logger = ActiveSupport::TaggedLogging.new(::Logger.new(self.log_device))
      logger.formatter = RailsDaemon::Logger::Formatter.new
      logger.formatter.show_time = true
      Rails.logger.instance_variable_set(:@logger, logger)
      Rails.logger.instance_variable_set(:@logdev, self.log_device)
      Rails.logger.level = self.log_level
      Rails.logger.clear_tags!

      at_exit do
        begin
          Rails.logger.tagged("#{Process.pid}") do
            Rails.logger.info("Exiting #{self.name}")
          end
        ensure
          rm_rf(self.pid_file, :verbose => (self.log_level == :debug)) if Process.pid == @master_pid
          Rails.logger.flush
          self.log_device.close
        end
      end
    end
  end
end
