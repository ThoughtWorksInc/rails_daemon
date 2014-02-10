module RailsDaemon::Logger
  class Formatter < ::Logger::Formatter

    def show_time=(show=false)
      @show_time = show
    end

    def call(severity, time, progname, msg)
      if @show_time
        sprintf("[%s] %s: %s\n", time.iso8601(), severity, msg2str(msg))
      else
        sprintf("%s: %s\n", severity, msg2str(msg))
      end
    end

    def msg2str(msg)
      case msg
      when ::String
        msg
      when ::Exception
        "#{ msg.message } (#{ msg.class })\n" <<
        (msg.backtrace || []).join("\n")
      else
        msg.inspect
      end
    end
  end
end
