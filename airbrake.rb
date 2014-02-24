if defined?(Airbrake) # Generally production
  Airbrake.configure do |config|
    config.api_key = '<%= @airbrake_api_key %>'
  end
else
  module Airbrake
    def self.notify(e)
      c = lambda{|color_code, text| "\e[#{color_code}m#{text}\e[0m"}
      red = 31
      green = 32
      yellow = 33

      if e.is_a?(Hash)
        backtrace = Rails.backtrace_cleaner.clean(e[:backtrace] || [])
        color = e[:error_message] =~ /successful/ ? green : yellow
        Rails.logger.error(c[color, "#{e[:error_class]}: #{e[:error_message]}"] + "\n #{backtrace.join("\n  ")}")
      elsif e.is_a?(Exception)
        backtrace = Rails.backtrace_cleaner.clean(e.backtrace || [])
        Rails.logger.error(c[red, "Exception: #{e}"]+"\n  #{backtrace.join("\n  ")}")
      end
    end

    def self.notify_or_ignore(e)
      notify(e)
    end
  end
end

