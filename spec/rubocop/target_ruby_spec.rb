# frozen_string_literal: true

RSpec.describe RuboCop::TargetRuby, :isolated_environment do
  include FileHelper

  subject(:target_ruby) { described_class.new(configuration) }

  let(:configuration) { RuboCop::Config.new(hash, loaded_path) }
  let(:default_version) { described_class::DEFAULT_VERSION }

  let(:hash) { {} }
  let(:loaded_path) { 'example/.rubocop.yml' }

  context 'when TargetRubyVersion is set' do
    let(:ruby_version) { 2.5 }

    let(:hash) { { 'AllCops' => { 'TargetRubyVersion' => ruby_version } } }

    it 'uses TargetRubyVersion' do
      expect(target_ruby.version).to eq ruby_version
    end

    it 'does not read .ruby-version' do
      expect(File).not_to receive(:file?).with('.ruby-version')
      expect(target_ruby.version).to eq 2.5
    end

    it 'does not read Gemfile.lock or gems.locked' do
      expect(File).not_to receive(:file?).with('Gemfile')
      expect(File).not_to receive(:file?).with('gems.locked')
      expect(target_ruby.version).to eq 2.5
    end
  end

  context 'when RUBOCOP_TARGET_RUBY_VERSION is set' do
    it 'uses RUBOCOP_TARGET_RUBY_VERSION' do
      old_version = ENV.fetch('RUBOCOP_TARGET_RUBY_VERSION', nil)
      begin
        ENV['RUBOCOP_TARGET_RUBY_VERSION'] = '2.7'
        expect(target_ruby.version).to eq 2.7
      ensure
        ENV['RUBOCOP_TARGET_RUBY_VERSION'] = old_version
      end
    end

    it 'does not read .ruby-version' do
      expect(File).not_to receive(:file?).with('.ruby-version')
      old_version = ENV.fetch('RUBOCOP_TARGET_RUBY_VERSION', nil)
      begin
        ENV['RUBOCOP_TARGET_RUBY_VERSION'] = '2.7'
        expect(target_ruby.version).to eq 2.7
      ensure
        ENV['RUBOCOP_TARGET_RUBY_VERSION'] = old_version
      end
    end

    it 'does not read Gemfile.lock or gems.locked' do
      expect(File).not_to receive(:file?).with('Gemfile')
      expect(File).not_to receive(:file?).with('gems.locked')
      old_version = ENV.fetch('RUBOCOP_TARGET_RUBY_VERSION', nil)
      begin
        ENV['RUBOCOP_TARGET_RUBY_VERSION'] = '2.7'
        expect(target_ruby.version).to eq 2.7
      ensure
        ENV['RUBOCOP_TARGET_RUBY_VERSION'] = old_version
      end
    end
  end

  context 'when TargetRubyVersion is not set' do
    context 'when gemspec file is present' do
      let(:base_path) { configuration.base_dir_for_path_parameters }
      let(:gemspec_file_path) { File.join(base_path, 'example.gemspec') }

      context 'when file contains `required_ruby_version` as a string' do
        it 'sets target_ruby from inclusive range' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = '>= 3.2.2'
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 3.2
        end

        it 'sets target_ruby from exclusive range' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = '> 3.2.2'
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 3.2
        end

        it 'sets target_ruby from approximate version' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = '~> 3.2.0'
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 3.2
        end
      end

      context 'when file contains `required_ruby_version` as a requirement' do
        it 'sets target_ruby from required_ruby_version from inclusive requirement range' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = Gem::Requirement.new('>= 2.3.1')
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 2.3
        end

        it 'falls back to the minimal supported analysable ruby version' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.required_ruby_version = '>= 1.9.0'
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 2.0
        end

        it 'sets first known ruby version that satisfies requirement' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = Gem::Requirement.new('< 3.0.0')
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 2.0
        end

        it 'sets first known ruby version that satisfies range requirement' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = Gem::Requirement.new('>= 2.3.1', '< 3.0.0')
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 2.3
        end

        it 'sets first known ruby version that satisfies range requirement in array notation' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = Gem::Requirement.new(['>= 2.3.1', '< 3.0.0'])
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 2.3
        end

        it 'sets first known ruby version that satisfies range requirement with frozen strings' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = Gem::Requirement.new('>= 2.3.1'.freeze, '< 3.0.0'.freeze)
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 2.3
        end

        it 'sets first known ruby version that satisfies range requirement in array notation with frozen strings' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = Gem::Requirement.new(['>= 2.3.1'.freeze, '< 3.0.0'.freeze])
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 2.3
        end
      end

      context 'when file contains `required_ruby_version` as an array' do
        it 'sets target_ruby to the minimal version satisfying the requirements' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = ['<=3.3.0', '>=3.1.3']
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 3.1
        end

        it 'sets target_ruby from required_ruby_version with many requirements' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = ['<=3.3.0', '>3.1.1', '~>3.2.1']
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 3.2
        end
      end

      context 'when file reads the required_ruby_version from another file' do
        it 'uses the default target ruby version' do
          content = <<~'HEREDOC'
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = Gem::Requirement.new(">= #{File.read('.ruby-version').rstrip}")
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq default_version
        end
      end

      context 'when file reads the required_ruby_version from another file in an array' do
        it 'uses the default target ruby version' do
          content = <<~'HEREDOC'
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = [">= #{File.read('.ruby-version').rstrip}"]
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq default_version
        end
      end

      context 'when required_ruby_version sets the target ruby' do
        before do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = '>= 2.7.2'
              s.licenses = ['MIT']
            end
          HEREDOC
          create_file(gemspec_file_path, content)
        end

        it 'does not check the other sources' do
          expect(described_class::RubyVersionFile).not_to receive(:new)
          expect(described_class::ToolVersionsFile).not_to receive(:new)
          expect(described_class::BundlerLockFile).not_to receive(:new)
          expect(described_class::Default).not_to receive(:new)
          expect(target_ruby.version).to eq 2.7
        end
      end

      context 'when file does not contain `required_ruby_version`' do
        before do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.platform = Gem::Platform::RUBY
              s.licenses = ['MIT']
              s.summary = 'test tool.'
            end
          HEREDOC
          create_file(gemspec_file_path, content)
        end

        it 'checks the rest of the sources' do
          expect(described_class::RubyVersionFile).to receive(:new).and_call_original
          expect(described_class::ToolVersionsFile).to receive(:new).and_call_original
          expect(described_class::BundlerLockFile).to receive(:new).and_call_original
          expect(described_class::Default).to receive(:new).and_call_original
          expect(target_ruby.version).to eq default_version
        end
      end

      context 'when file contains a syntax error' do
        it 'uses the default target ruby version' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.required_ruby_version = '>= 3.3.0'' # invalid syntax
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq default_version
        end
      end

      context 'when the gemspec is not named the same as the directory' do
        let(:gemspec_file_path) { File.join(base_path, 'whatever.gemspec') }

        it 'sets target_ruby from the version' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = '~> 3.2.0'
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(gemspec_file_path, content)
          expect(target_ruby.version).to eq 3.2
        end
      end

      context 'when there are multiple gemspecs in the same directory' do
        let(:first_gemspec_file_path) { File.join(base_path, 'first.gemspec') }
        let(:second_gemspec_file_path) { File.join(base_path, 'second.gemspec') }

        it 'takes neither' do
          content = <<~HEREDOC
            Gem::Specification.new do |s|
              s.name = 'test'
              s.required_ruby_version = '~> 3.2.0'
              s.licenses = ['MIT']
            end
          HEREDOC

          create_file(first_gemspec_file_path, content)
          create_file(second_gemspec_file_path, content)
          expect(target_ruby.version).to eq default_version
        end
      end
    end

    context 'when .ruby-version is present' do
      before do
        dir = configuration.base_dir_for_path_parameters
        create_file(File.join(dir, '.ruby-version'), ruby_version)
      end

      context 'when .ruby-version contains an MRI version' do
        let(:ruby_version) { '2.4.10' }
        let(:ruby_version_to_f) { 2.4 }

        it 'reads it to determine the target ruby version' do
          expect(target_ruby.version).to eq ruby_version_to_f
        end
      end

      context 'when the MRI version contains multiple digits' do
        let(:ruby_version) { '10.11.0' }
        let(:ruby_version_to_f) { 10.11 }

        it 'reads it to determine the target ruby version' do
          expect(target_ruby.version).to eq ruby_version_to_f
        end
      end

      context 'when .ruby-version contains a version prefixed by "ruby-"' do
        let(:ruby_version) { 'ruby-2.4.0' }
        let(:ruby_version_to_f) { 2.4 }

        it 'correctly determines the target ruby version' do
          expect(target_ruby.version).to eq ruby_version_to_f
        end
      end

      context 'when .ruby-version contains a JRuby version' do
        let(:ruby_version) { 'jruby-9.1.2.0' }

        it 'uses the default target ruby version' do
          expect(target_ruby.version).to eq default_version
        end
      end

      context 'when .ruby-version contains a Rbx version' do
        let(:ruby_version) { 'rbx-3.42' }

        it 'uses the default target ruby version' do
          expect(target_ruby.version).to eq default_version
        end
      end

      context 'when .ruby-version contains "system" version' do
        let(:ruby_version) { 'system' }

        it 'uses the default target ruby version' do
          expect(target_ruby.version).to eq default_version
        end
      end

      it 'does not read .tool-versions, Gemfile.lock or gems.locked' do
        expect(File).not_to receive(:file?).with('.tool-versions')
        expect(File).not_to receive(:file?).with('Gemfile')
        expect(File).not_to receive(:file?).with('gems.locked')
        expect(target_ruby.version).to eq default_version
      end
    end

    context 'when .tool-versions is present' do
      before do
        dir = configuration.base_dir_for_path_parameters
        create_file(File.join(dir, '.tool-versions'), tool_versions)
      end

      context 'when .tool-versions does not contain a ruby version' do
        let(:tool_versions) { ['nodejs 14.9.0'] }

        it 'uses the default ruby version' do
          expect(target_ruby.version).to eq default_version
        end
      end

      context 'when .tool-versions contains only a ruby version' do
        let(:tool_versions) { ['ruby 3.0.0'] }
        let(:ruby_version_to_f) { 3.0 }

        it 'reads it to determine the target ruby version' do
          expect(target_ruby.version).to eq ruby_version_to_f
        end

        it 'does not read Gemfile.lock, gems.locked' do
          expect(File).not_to receive(:file?).with(/Gemfile/)
          expect(File).not_to receive(:file?).with(/gems\.locked/)
          expect(target_ruby.version).to eq default_version
        end
      end

      context 'when .tool-versions contains different runtimes' do
        let(:tool_versions) { ['nodejs 14.9.0', 'ruby 3.0.0'] }
        let(:ruby_version_to_f) { 3.0 }

        it 'reads it to determine the target ruby version' do
          expect(target_ruby.version).to eq ruby_version_to_f
        end

        it 'does not read Gemfile.lock, gems.locked' do
          expect(File).not_to receive(:file?).with(/Gemfile/)
          expect(File).not_to receive(:file?).with(/gems\.locked/)
          expect(target_ruby.version).to eq default_version
        end
      end
    end

    context 'when .ruby-version is not present' do
      ['Gemfile.lock', 'gems.locked'].each do |file_name|
        context "and #{file_name} exists" do
          let(:base_path) { configuration.base_dir_for_path_parameters }
          let(:lock_file_path) { File.join(base_path, file_name) }

          it "uses MRI Ruby version when it is present in #{file_name}" do
            content = <<~HEREDOC
              GEM
                remote: https://rubygems.org/
                specs:
                  actionmailer (4.1.0)
                  actionpack (= 4.1.0)
                rails (4.1.0)
                  actionmailer (= 4.1.0)
                  actionpack (= 4.1.0)
                  railties (= 4.1.0)
                railties (4.1.0)

              PLATFORMS
                ruby

              DEPENDENCIES
                ruby-extensions (~> 1.9.0)

              RUBY VERSION
                  ruby 2.0.0p0

              BUNDLED WITH
                1.16.1
            HEREDOC
            create_file(lock_file_path, content)
            expect(target_ruby.version).to eq 2.0
          end

          it 'uses MRI Ruby version when it has multiple digits' do
            content = <<~HEREDOC
              GEM
                remote: https://rubygems.org/
                specs:
                  actionmailer (4.1.0)
                  actionpack (= 4.1.0)
                rails (4.1.0)
                  actionmailer (= 4.1.0)
                  actionpack (= 4.1.0)
                  railties (= 4.1.0)
                railties (4.1.0)

              PLATFORMS
                ruby

              DEPENDENCIES
                ruby-extensions (~> 1.9.0)

              RUBY VERSION
                  ruby 20.10.100p450

              BUNDLED WITH
                1.16.1
            HEREDOC
            create_file(lock_file_path, content)
            expect(target_ruby.version).to eq 20.10
          end

          it "uses the default Ruby when Ruby is not in #{file_name}" do
            content = <<~HEREDOC
              GEM
                remote: https://rubygems.org/
                specs:
                  addressable (2.5.2)
                    public_suffix (>= 2.0.2, < 4.0)
                  ast (2.4.0)
                  bump (0.5.4)

              PLATFORMS
                ruby

              DEPENDENCIES
                bump
                bundler (~> 1.3)
                ruby-extensions (~> 1.9.0)

              BUNDLED WITH
                1.16.1
            HEREDOC
            create_file(lock_file_path, content)
            expect(target_ruby.version).to eq default_version
          end

          it "uses the default Ruby when rbx is in #{file_name}" do
            content = <<~HEREDOC
              GEM
                remote: https://rubygems.org/
                specs:
                  addressable (2.5.2)
                    public_suffix (>= 2.0.2, < 4.0)
                  ast (2.4.0)
                  bump (0.5.4)

              PLATFORMS
                ruby

              DEPENDENCIES
                bump
                bundler (~> 1.3)
                ruby-extensions (~> 1.9.0)

              RUBY VERSION
                  ruby 2.0.0p0 (rbx 3.42)

              BUNDLED WITH
                1.16.1
            HEREDOC
            create_file(lock_file_path, content)
            expect(target_ruby.version).to eq default_version
          end

          it "uses the default Ruby when jruby is in #{file_name}" do
            content = <<~HEREDOC
              GEM
                remote: https://rubygems.org/
                specs:
                  addressable (2.5.2)
                    public_suffix (>= 2.0.2, < 4.0)
                  ast (2.4.0)
                  bump (0.5.4)

              PLATFORMS
                ruby

              DEPENDENCIES
                bump
                bundler (~> 1.3)
                ruby-extensions (~> 1.9.0)

              RUBY VERSION
                  ruby 2.0.0p0 (jruby 9.1.13.0)

              BUNDLED WITH
                1.16.1
            HEREDOC
            create_file(lock_file_path, content)
            expect(target_ruby.version).to eq default_version
          end
        end
      end

      context 'when bundler lock files are not present' do
        it 'uses the default target ruby version' do
          expect(target_ruby.version).to eq default_version
        end
      end
    end

    context 'when .ruby-version is in a parent directory' do
      before do
        dir = configuration.base_dir_for_path_parameters
        create_file(File.join(dir, '..', '.ruby-version'), '2.5.8')
      end

      it 'reads it to determine the target ruby version' do
        expect(target_ruby.version).to eq 2.5
      end
    end

    context 'when .ruby-version is not in a parent directory' do
      ['Gemfile.lock', 'gems.locked'].each do |file_name|
        context "when #{file_name} is in a parent directory" do
          it 'does' do
            content = <<~HEREDOC
              GEM
                remote: https://rubygems.org/
                specs:
                  actionmailer (4.1.0)
                  actionpack (= 4.1.0)
                rails (4.1.0)
                  actionmailer (= 4.1.0)
                  actionpack (= 4.1.0)
                  railties (= 4.1.0)
                railties (4.1.0)

              PLATFORMS
                ruby

              DEPENDENCIES
                ruby-extensions (~> 1.9.0)

              RUBY VERSION
                  ruby 2.0.0p0

              BUNDLED WITH
                1.16.1
            HEREDOC
            dir = configuration.base_dir_for_path_parameters
            create_file(File.join(dir, '..', file_name), content)
            expect(target_ruby.version).to eq 2.0
          end
        end
      end
    end
  end
end
