def sudo(*args)
  %w[/usr/bin/sudo -E --] + args.flatten
end

module Hbc
  class FakeSystemCommand
    def self.responses
      @responses ||= {}
    end

    def self.expectations
      @expectations ||= {}
    end

    def self.system_calls
      @system_calls ||= Hash.new(0)
    end

    def self.clear
      @responses    = nil
      @expectations = nil
      @system_calls = nil
    end

    def self.stubs_command(command, response = "")
      responses[command] = response
    end

    def self.expects_command(command, response = "", times = 1)
      stubs_command(command, response)
      expectations[command] = times
    end

    def self.expect_and_pass_through(command, times = 1)
      pass_through = ->(cmd, opts) { Hbc::SystemCommand.run(cmd, opts) }
      expects_command(command, pass_through, times)
    end

    def self.verify_expectations!
      expectations.each do |command, times|
        unless system_calls[command] == times
          raise("expected #{command.inspect} to be run #{times} times, but got #{system_calls[command]}")
        end
      end
    end

    def self.run(command_string, options = {})
      command = Hbc::SystemCommand.new(command_string, options).command
      puts command
      unless responses.key?(command)
        raise("no response faked for #{command.inspect}, faked responses are: #{responses.inspect}")
      end
      system_calls[command] += 1

      response = responses[command]
      if response.respond_to?(:call)
        response.call(command_string, options)
      else
        Hbc::SystemCommand::Result.new(command, response, "", 0)
      end
    end

    def self.run!(command, options = {})
      run(command, options.merge(must_succeed: true))
    end
  end
end

RSpec.configure do |config|
  config.after(:each) do
    begin
      Hbc::FakeSystemCommand.verify_expectations!
    ensure
      Hbc::FakeSystemCommand.clear
    end
  end
end
