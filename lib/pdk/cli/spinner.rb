require 'tty-spinner'

module PDK
  module CLI
    module Spinner
      def self.new_validation_spinner(count, opts = {})
        raise PDK::CLI::FatalError, 'A threaded spinner already exists' unless @spinner.nil?

        if Gem.win_platform?
          @spinner = WindowsSpinner.new(_("Validating using #{count} threads"), opts)
          @spinner.auto_spin
        else
          @spinner = ThreadedSpinner.new(opts)
          @spinner.add _("Using #{count} threads. Validating: :validations.")
          @spinner.add_list :validations
        end

        @spinner
      end

      def self.threaded_spinner
        @spinner
      end

      def self.clear_threaded_spinner
        @spinner = nil
      end

      def self.new_spinner(message, opts = {})
        Gem.win_platform? ? WindowsSpinner.new(message, opts) : TTY::Spinner.new("[:spinner] #{message}", opts)
      end

      class ThreadedSpinner
        PREFIX = 'spinner_key'.freeze
        LOCK = Monitor.new
        private_constant :PREFIX
        private_constant :LOCK

        def initialize(opts = {})
          @postfix = 0
          @spinner_keys = ''
          @spinner = TTY::Spinner.new('[:spinner] :base_key', opts)
          @spinner.update(base_key: '')
          @spinner.auto_spin

          @lists = {}
        end

        def update(msg)
          update_key(:validations, msg)
        end

        def update_key(key, msg)
          @spinner.update(key => msg)
        end

        def add_new_key
          LOCK.synchronize do
            key = "#{PREFIX}#{@postfix}"
            @spinner_keys = "#{@spinner_keys}:#{key}"
            @postfix += 1
            key.to_sym
          end
        end

        def add_list(key)
          @lists[key] = []
          update_key key, @lists[key].join(', ')
        end

        def add_to_list(list_key, msg)
          LOCK.synchronize do
            return unless @lists.key? list_key

            @lists[list_key].push msg
            update_key list_key, @lists[list_key].join(', ')
          end
        end

        def add(str)
          LOCK.synchronize do
            new_key = add_new_key
            @spinner.update(base_key: @spinner_keys.to_s)
            @spinner.update(new_key => str)
            new_key
          end
        end

        def success
          @spinner.success('')
          PDK::CLI::Spinner.clear_threaded_spinner
        end

        def error
          @spinner.error('')
          PDK::CLI::Spinner.clear_threaded_spinner
        end

        def on(key, &block)
          raise PDK::CLI::FatalError, _("The event :#{key} does not exist. Only :done, :success, and :error allowed.") unless [:done, :success, :error].include? key

          @spinner.on(key, &block)
        end
      end
    end

    # This is a placeholder until we integrate ansicon into Windows packaging
    # or come up with some other progress indicator for Windows.
    class WindowsSpinner
      def initialize(message, _opts = {})
        @message = message
        @block_list = []
      end

      def auto_spin
        $stderr.print @message << '...'
      end

      def add_to_list(list_key, msg); end

      def success(message = '')
        message = 'done.' if message.nil? || message.empty?

        $stderr.print message << "\n"
        emit
      end

      def error(message = '')
        message = 'FAILED' if message.nil? || message.empty?

        $stderr.print message << "\n"
        emit
      end

      def on(key, &block)
        raise PDK::CLI::FatalError, _("The event :#{key} does not exist. Only :done allowed.") unless [:done].include? key

        @block_list.push(block)
      end

      def emit
        @block_list.each do |block|
          block.call
        end
      end
    end
  end
end
