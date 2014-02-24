source_paths.push File.dirname __FILE__

def install?(something, color = nil)
  response = ask("Install #{something} (Yes/no)?", color)
  (response =~ /\Ay/i) || response == ""
end

def annotate_gem(msg)
  append_file "Gemfile", " # #{msg}"
end

@heroku = yes?("Are you deploying to heroku? (yes/No)")

@install_devise = install?("Authentication")
@install_activeadmin = install?("ActiveAdmin")
@install_cancan = install?("CanCan (permission management)")

template 'Gemfile.rb.erb', 'Gemfile'

run 'bundle install'

if @install_devise
  gem "devise"
  annotate_gem "For authentication https://github.com/plataformatec/devise#readme"

  generate 'devise:install'
  generate 'devise:views'

  environment 'config.action_mailer.default_url_options = {host: "http://localhost:3000"}', env: 'development'
  environment 'config.action_mailer.default_url_options = {host: "http://example.com"}', env: 'production'

  puts "Please inspect and update config/initializers/devise.rb"
end

if @install_activeadmin
  generate 'active_admin:install'
  inject_into_file "config/initializers/active_admin.rb", " if defined?(ActiveAdmin)", :after => /^end/
  inject_into_file "config/initializers/devise.rb", " if defined?(Devise)", :after => /^end/
  run 'mv app/admin/admin_user.rb app/admin/aa_admin.rb'
end

if @install_cancan
  gem "cancan"
  annotate_gem "For permission management"
  generate "cancan:ability"
end

if @heroku
  copy_file "unicorn.rb", "config/unicorn.rb"
  create_file "config/initializers/rack_timeout.rb", "Rack::Timeout.timeout = 15  # seconds"
end

# ZURB Foundation

copy_file "application.html.slim", "app/views/layouts/application.html.slim"
remove_file "app/views/layouts/application.html.erb"
gsub_file 'config/environments/production.rb', "# config.assets.precompile += %w( search.js )", "config.assets.precompile += %w( vendor/modernizr.js )"
remove_file "app/assets/stylesheets/application.css"
copy_file "application.js", "app/views/assets/javascripts/application.js"
copy_file "application.css.scss", "app/views/assets/stylesheets/application.css.scss"
copy_file "foundation-settings.css.scss", "app/views/assets/stylesheets/foundation-settings.css.scss"

# Generating pages controller
generate 'controller', 'pages', 'index'
gsub_file 'config/routes.rb', "  # root 'welcome#index'", "  root 'pages#index'"
gsub_file 'config/routes.rb', '  get "pages/index"', '  get "pages/:action", controller: "pages"'

# We need this with foreman to see log output immediately
append_file "config/environments/development.rb", "STDOUT.sync = true"

# Better console
railtie = <<DOC
class CustomConsoleRailtie < Rails::Railtie
  console do |app|
    Bundler.require(:console)
    Hirb.enable

    Rails::Console::IRB = Pry 
    require "rails/console/app"
    require "rails/console/helpers"
    TOPLEVEL_BINDING.eval('self').extend ::Rails::ConsoleMethods
  end 
end

DOC
inject_into_file 'config/application.rb', railtie, before: /^module/

# fixing locale (and warning)
gsub_file 'config/application.rb', "# config.i18n.default_locale = :de", "config.i18n.default_locale = :en"
inject_into_file 'config/application.rb', "I18n.config.enforce_available_locales = true\n\n", before: /^module/

# Annotate
# generate 'annotate:install'
copy_file 'auto_annotate_models.rake', 'lib/tasks/auto_annotate_models.rake'

# Guard & Livereload & other *file
copy_file 'Guardfile'
copy_file 'Procfile'
copy_file '.env'

# Airbrake
@airbrake_api_key = ask("Airbrake api key: ")
if @airbrake_api_key.blank?
  puts "No worries. Can be always filled in later in config/initializers/airbrake.rb"
end
template 'airbrake.rb', 'config/initializers/airbrake.rb'

# Git: Initialize
# ==================================================
git :init
git add: "."
git commit: %Q{ -m 'New application generated from Marmot Template' }

if false && yes?("Initialize GitHub repository?")
  git_uri = `git config remote.origin.url`.strip
  unless git_uri.size == 0
    say "Repository already exists:"
    say "#{git_uri}"
  else
    username = ask "What is your GitHub username?"
    run "curl -u #{username} -d '{\"name\":\"#{app_name}\"}' https://api.github.com/user/repos"
    git remote: %Q{ add origin git@github.com:#{username}/#{app_name}.git }
    git push: %Q{ origin master }
  end
end
