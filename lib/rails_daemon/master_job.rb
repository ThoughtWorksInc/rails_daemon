module RailsDaemon
  class MasterJob
    attr_reader :child_count, :child_processes, :to_execute

    def initialize(options={}, &block)
      @child_count = options[:child_count]
      @child_processes = {}
      @to_execute = block
      @parent_process = true
      @is_child = false
      @parent_exiting = false
    end

    def run
      child_count.times do |counter|
        fork_child(counter)
      end

      handle_master_signals

      while !@parent_exiting do
        reap_all_workers
        rerun_processes_if_needed

        sleep 5
      end

      wait_for_all_processes_to_die

      Rails.logger.info %Q{MasterJob(#{Process.pid}) exiting.}
    end

    def wait_for_all_processes_to_die
      while child_processes.any?
        Rails.logger.info "Waiting for child processes to finish."
        reap_all_workers
        sleep 5
      end
    end

    def rerun_processes_if_needed
      while child_processes.count < child_count
        dead_processes = child_count.times.to_a - child_processes.keys
        dead_processes.each do |counter|
          fork_child(counter)
        end
      end
    end

    def reap_all_workers
      begin
        child_pid, status = Process.waitpid2(-1, Process::WNOHANG)
        return unless child_pid
        Rails.logger.warn "Child process #{status.inspect} exited."
        child_processes.delete_if do |counter, pid|
          pid == child_pid
        end
      rescue Errno::ECHILD
        # there are no children to reap, ignore
      end
    end

    def fork_child(counter)
      child_processes[counter] = fork do
        Rails.logger.info "Starting up child with pid #{Process.pid} as a child of #{Process.ppid}"
        @is_child = true
        to_execute.call(counter)
      end
    end

    def handle_master_signals
      %w(INT TERM).each do |signal|
        cascade_signal(signal)
      end
    end

    def cascade_signal(signal)
      trap(signal.to_sym) do
        unless @is_child
          @parent_exiting = true
          Rails.logger.info "MasterJob(#{Process.pid}) recieved signal SIG#{signal}"
          child_processes.values.each do |pid|
            Rails.logger.info "MasterJob(#{Process.pid}) sending SIG#{signal} to child pid #{pid}"
            Process.kill(signal, pid)
          end

          exit
        end
      end
    end
  end
end
