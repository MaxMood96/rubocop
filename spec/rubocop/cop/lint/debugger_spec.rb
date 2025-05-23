# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Lint::Debugger, :config do
  context 'with the DebuggerMethods configuration' do
    let(:cop_config) { { 'DebuggerMethods' => %w[custom_debugger] } }

    it 'does not register an offense for a byebug call' do
      expect_no_offenses(<<~RUBY)
        byebug
      RUBY
    end

    it 'does not register an offense for a `custom_debugger` call when used in assignment' do
      expect_no_offenses(<<~RUBY)
        x.y = custom_debugger
      RUBY
    end

    it 'registers an offense for a `custom_debugger` call' do
      expect_offense(<<~RUBY)
        custom_debugger
        ^^^^^^^^^^^^^^^ Remove debugger entry point `custom_debugger`.
      RUBY
    end

    it 'registers an offense for a `custom_debugger` call when used in block' do
      expect_offense(<<~RUBY)
        x.y = do_something { custom_debugger }
                             ^^^^^^^^^^^^^^^ Remove debugger entry point `custom_debugger`.
      RUBY
    end

    it 'registers an offense for a `custom_debugger` call when used in numbered block' do
      expect_offense(<<~RUBY)
        x.y = do_something do
          z(_1)
          custom_debugger
          ^^^^^^^^^^^^^^^ Remove debugger entry point `custom_debugger`.
        end
      RUBY
    end

    it 'registers an offense for a `custom_debugger` call when used in `it` block', :ruby34 do
      expect_offense(<<~RUBY)
        x.y = do_something do
          z(it)
          custom_debugger
          ^^^^^^^^^^^^^^^ Remove debugger entry point `custom_debugger`.
        end
      RUBY
    end

    it 'registers an offense for a `custom_debugger` call when used in lambda literal' do
      expect_offense(<<~RUBY)
        x.y = -> { custom_debugger }
                   ^^^^^^^^^^^^^^^ Remove debugger entry point `custom_debugger`.
      RUBY
    end

    it 'registers an offense for a `custom_debugger` call when used in `lambda`' do
      expect_offense(<<~RUBY)
        x.y = lambda { custom_debugger }
                       ^^^^^^^^^^^^^^^ Remove debugger entry point `custom_debugger`.
      RUBY
    end

    it 'registers an offense for a `custom_debugger` call when used in `proc`' do
      expect_offense(<<~RUBY)
        x.y = proc { custom_debugger }
                     ^^^^^^^^^^^^^^^ Remove debugger entry point `custom_debugger`.
      RUBY
    end

    it 'registers an offense for a `custom_debugger` call when used in `Proc.new`' do
      expect_offense(<<~RUBY)
        x.y = Proc.new { custom_debugger }
                         ^^^^^^^^^^^^^^^ Remove debugger entry point `custom_debugger`.
      RUBY
    end

    it 'registers an offense for a `custom_debugger` call when used within method arguments a `begin`...`end` block' do
      expect_offense(<<~RUBY)
        do_something(
          begin
            custom_debugger
            ^^^^^^^^^^^^^^^ Remove debugger entry point `custom_debugger`.
          end
        )
      RUBY
    end

    context 'nested custom configurations' do
      let(:cop_config) { { 'DebuggerMethods' => { 'Custom' => %w[custom_debugger] } } }

      it 'registers an offense for a `custom_debugger call' do
        expect_offense(<<~RUBY)
          custom_debugger
          ^^^^^^^^^^^^^^^ Remove debugger entry point `custom_debugger`.
        RUBY
      end
    end

    context 'with a method chain' do
      let(:cop_config) { { 'DebuggerMethods' => %w[debugger.foo.bar] } }

      it 'registers an offense for a `debugger.foo.bar` call' do
        expect_offense(<<~RUBY)
          debugger.foo.bar
          ^^^^^^^^^^^^^^^^ Remove debugger entry point `debugger.foo.bar`.
        RUBY
      end
    end

    context 'with a const chain' do
      let(:cop_config) { { 'DebuggerMethods' => %w[Foo::Bar::Baz.debug] } }

      it 'registers an offense for a `Foo::Bar::Baz.debug` call' do
        expect_offense(<<~RUBY)
          Foo::Bar::Baz.debug
          ^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `Foo::Bar::Baz.debug`.
        RUBY
      end
    end

    context 'with a const chain and a method chain' do
      let(:cop_config) { { 'DebuggerMethods' => %w[Foo::Bar::Baz.debug.this.code] } }

      it 'registers an offense for a `Foo::Bar::Baz.debug.this.code` call' do
        expect_offense(<<~RUBY)
          Foo::Bar::Baz.debug.this.code
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `Foo::Bar::Baz.debug.this.code`.
        RUBY
      end
    end
  end

  context 'with the DebuggerRequires configuration' do
    let(:cop_config) do
      {
        'DebuggerRequires' => {
          'my_debugger' => %w[my_debugger],
          'other_debugger' => %w[other_debugger/start]
        }
      }
    end

    it 'registers an offense' do
      expect_offense(<<~RUBY)
        require 'my_debugger'
        ^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `require 'my_debugger'`.
      RUBY
    end

    it 'registers no offense for a require without arguments' do
      expect_no_offenses('require')
    end

    it 'registers no offense for a require with multiple arguments' do
      expect_no_offenses('require "my_debugger", "something_else"')
    end

    it 'registers no offense for a require with non-string arguments' do
      expect_no_offenses('require my_debugger')
    end

    context 'when a require group is disabled with nil' do
      before { cop_config['DebuggerRequires']['my_debugger'] = nil }

      it 'does not register an offense for a require call' do
        expect_no_offenses('require "my_debugger"')
      end

      it 'does register an offense for another group' do
        expect_offense(<<~RUBY)
          require 'other_debugger/start'
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `require 'other_debugger/start'`.
        RUBY
      end
    end

    context 'when the config is specified as an array' do
      let(:cop_config) { { 'DebuggerRequires' => %w[start_debugging] } }

      it 'registers an offense' do
        expect_offense(<<~RUBY)
          require 'start_debugging'
          ^^^^^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `require 'start_debugging'`.
        RUBY
      end
    end
  end

  context 'built-in methods' do
    it 'registers an offense for a `binding.irb` call' do
      expect_offense(<<~RUBY)
        binding.irb
        ^^^^^^^^^^^ Remove debugger entry point `binding.irb`.
      RUBY
    end

    it 'registers an offense for a `Kernel.binding.irb` call' do
      expect_offense(<<~RUBY)
        Kernel.binding.irb
        ^^^^^^^^^^^^^^^^^^ Remove debugger entry point `Kernel.binding.irb`.
      RUBY
    end
  end

  context 'when print debug method is configured by user' do
    let(:cop_config) { { 'DebuggerMethods' => %w[p] } }

    it 'registers an offense for a p call' do
      expect_offense(<<~RUBY)
        p 'foo'
        ^^^^^^^ Remove debugger entry point `p 'foo'`.
      RUBY
    end

    it 'registers an offense for a p call with foo method argument' do
      expect_offense(<<~RUBY)
        foo(p 'foo')
            ^^^^^^^ Remove debugger entry point `p 'foo'`.
      RUBY
    end

    it 'registers an offense for a p call with p method argument' do
      expect_offense(<<~RUBY)
        p(p 'foo')
          ^^^^^^^ Remove debugger entry point `p 'foo'`.
        ^^^^^^^^^^ Remove debugger entry point `p(p 'foo')`.
      RUBY
    end

    it 'does not register an offense for a p.do_something call' do
      expect_no_offenses(<<~RUBY)
        p.do_something
      RUBY
    end

    it 'does not register an offense for a p with Foo call' do
      expect_no_offenses(<<~RUBY)
        Foo.p
      RUBY
    end

    it 'does not register an offense when `p` is an argument of method call' do
      expect_no_offenses(<<~RUBY)
        let(:p) { foo }

        it { expect(do_something(p)).to eq bar }
      RUBY
    end

    it 'does not register an offense when `p` is an argument of safe navigation method call' do
      expect_no_offenses(<<~RUBY)
        let(:p) { foo }

        it { expect(obj&.do_something(p)).to eq bar }
      RUBY
    end

    it 'does not register an offense when `p` is a keyword argument of method call' do
      expect_no_offenses(<<~RUBY)
        let(:p) { foo }

        it { expect(do_something(k: p)).to eq bar }
      RUBY
    end

    it 'does not register an offense when `p` is an array argument of method call' do
      expect_no_offenses(<<~RUBY)
        let(:p) { foo }

        it { expect(do_something([k, p])).to eq bar }
      RUBY
    end
  end

  context 'byebug' do
    it 'registers an offense for a byebug call' do
      expect_offense(<<~RUBY)
        byebug
        ^^^^^^ Remove debugger entry point `byebug`.
      RUBY
    end

    it 'registers an offense for a byebug with an argument call' do
      expect_offense(<<~RUBY)
        byebug foo
        ^^^^^^^^^^ Remove debugger entry point `byebug foo`.
      RUBY
    end

    it 'registers an offense for a Kernel.byebug call' do
      expect_offense(<<~RUBY)
        Kernel.byebug
        ^^^^^^^^^^^^^ Remove debugger entry point `Kernel.byebug`.
      RUBY
    end

    it 'registers an offense for a remote_byebug call' do
      expect_offense(<<~RUBY)
        remote_byebug
        ^^^^^^^^^^^^^ Remove debugger entry point `remote_byebug`.
      RUBY
    end

    it 'registers an offense for a Kernel.remote_byebug call' do
      expect_offense(<<~RUBY)
        Kernel.remote_byebug
        ^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `Kernel.remote_byebug`.
      RUBY
    end
  end

  context 'capybara' do
    it 'registers an offense for save_and_open_page' do
      expect_offense(<<~RUBY)
        save_and_open_page
        ^^^^^^^^^^^^^^^^^^ Remove debugger entry point `save_and_open_page`.
      RUBY
    end

    it 'registers an offense for save_and_open_screenshot' do
      expect_offense(<<~RUBY)
        save_and_open_screenshot
        ^^^^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `save_and_open_screenshot`.
      RUBY
    end

    it 'registers an offense for save_page' do
      expect_offense(<<~RUBY)
        save_page
        ^^^^^^^^^ Remove debugger entry point `save_page`.
      RUBY
    end

    it 'registers an offense for save_screenshot' do
      expect_offense(<<~RUBY)
        save_screenshot
        ^^^^^^^^^^^^^^^ Remove debugger entry point `save_screenshot`.
      RUBY
    end

    context 'with an argument' do
      it 'registers an offense for save_and_open_page' do
        expect_offense(<<~RUBY)
          save_and_open_page foo
          ^^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `save_and_open_page foo`.
        RUBY
      end

      it 'registers an offense for save_and_open_screenshot' do
        expect_offense(<<~RUBY)
          save_and_open_screenshot foo
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `save_and_open_screenshot foo`.
        RUBY
      end

      it 'registers an offense for save_page' do
        expect_offense(<<~RUBY)
          save_page foo
          ^^^^^^^^^^^^^ Remove debugger entry point `save_page foo`.
        RUBY
      end

      it 'registers an offense for save_screenshot' do
        expect_offense(<<~RUBY)
          save_screenshot foo
          ^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `save_screenshot foo`.
        RUBY
      end
    end

    context 'with a page receiver' do
      it 'registers an offense for save_and_open_page' do
        expect_offense(<<~RUBY)
          page.save_and_open_page
          ^^^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `page.save_and_open_page`.
        RUBY
      end

      it 'registers an offense for save_and_open_screenshot' do
        expect_offense(<<~RUBY)
          page.save_and_open_screenshot
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `page.save_and_open_screenshot`.
        RUBY
      end

      it 'registers an offense for save_page' do
        expect_offense(<<~RUBY)
          page.save_page
          ^^^^^^^^^^^^^^ Remove debugger entry point `page.save_page`.
        RUBY
      end

      it 'registers an offense for save_screenshot' do
        expect_offense(<<~RUBY)
          page.save_screenshot
          ^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `page.save_screenshot`.
        RUBY
      end
    end
  end

  context 'debug.rb' do
    it 'registers an offense for a `b` binding call' do
      expect_offense(<<~RUBY)
        binding.b
        ^^^^^^^^^ Remove debugger entry point `binding.b`.
      RUBY
    end

    it 'registers an offense for a `break` binding call' do
      expect_offense(<<~RUBY)
        binding.break
        ^^^^^^^^^^^^^ Remove debugger entry point `binding.break`.
      RUBY
    end

    it 'registers an offense for a `binding.b` with `Kernel` call' do
      expect_offense(<<~RUBY)
        Kernel.binding.b
        ^^^^^^^^^^^^^^^^ Remove debugger entry point `Kernel.binding.b`.
      RUBY
    end

    it 'registers an offense for a `binding.break` with `Kernel` call' do
      expect_offense(<<~RUBY)
        Kernel.binding.break
        ^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `Kernel.binding.break`.
      RUBY
    end
  end

  context 'pry' do
    it 'registers an offense for a pry call' do
      expect_offense(<<~RUBY)
        pry
        ^^^ Remove debugger entry point `pry`.
      RUBY
    end

    it 'registers an offense for a pry with an argument call' do
      expect_offense(<<~RUBY)
        pry foo
        ^^^^^^^ Remove debugger entry point `pry foo`.
      RUBY
    end

    it 'registers an offense for a pry binding call' do
      expect_offense(<<~RUBY)
        binding.pry
        ^^^^^^^^^^^ Remove debugger entry point `binding.pry`.
      RUBY
    end

    it 'registers an offense for a remote_pry binding call' do
      expect_offense(<<~RUBY)
        binding.remote_pry
        ^^^^^^^^^^^^^^^^^^ Remove debugger entry point `binding.remote_pry`.
      RUBY
    end

    it 'registers an offense for a pry_remote binding call' do
      expect_offense(<<~RUBY)
        binding.pry_remote
        ^^^^^^^^^^^^^^^^^^ Remove debugger entry point `binding.pry_remote`.
      RUBY
    end

    it 'registers an offense for a pry binding with an argument call' do
      expect_offense(<<~RUBY)
        binding.pry foo
        ^^^^^^^^^^^^^^^ Remove debugger entry point `binding.pry foo`.
      RUBY
    end

    it 'registers an offense for a remote_pry binding with an argument call' do
      expect_offense(<<~RUBY)
        binding.remote_pry foo
        ^^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `binding.remote_pry foo`.
      RUBY
    end

    it 'registers an offense for a pry_remote binding with an argument call' do
      expect_offense(<<~RUBY)
        binding.pry_remote foo
        ^^^^^^^^^^^^^^^^^^^^^^ Remove debugger entry point `binding.pry_remote foo`.
      RUBY
    end

    it 'registers an offense for a binding.pry with Kernel call' do
      expect_offense(<<~RUBY)
        Kernel.binding.pry
        ^^^^^^^^^^^^^^^^^^ Remove debugger entry point `Kernel.binding.pry`.
      RUBY
    end

    it 'registers an offense for a Pry.rescue call' do
      expect_offense(<<~RUBY)
        def method
          Pry.rescue { puts 1 }
          ^^^^^^^^^^ Remove debugger entry point `Pry.rescue`.
          ::Pry.rescue { puts 1 }
          ^^^^^^^^^^^^ Remove debugger entry point `::Pry.rescue`.
        end
      RUBY
    end

    it 'does not register an offense for a `rescue` call without Pry' do
      expect_no_offenses(<<~RUBY)
        begin
        rescue StandardError
        end
      RUBY
    end
  end

  context 'rails' do
    it 'registers an offense for a debugger call' do
      expect_offense(<<~RUBY)
        debugger
        ^^^^^^^^ Remove debugger entry point `debugger`.
      RUBY
    end

    it 'registers an offense for a debugger with an argument call' do
      expect_offense(<<~RUBY)
        debugger foo
        ^^^^^^^^^^^^ Remove debugger entry point `debugger foo`.
      RUBY
    end

    it 'registers an offense for a debugger with Kernel call' do
      expect_offense(<<~RUBY)
        Kernel.debugger
        ^^^^^^^^^^^^^^^ Remove debugger entry point `Kernel.debugger`.
      RUBY
    end

    it 'registers an offense for a debugger with ::Kernel call' do
      expect_offense(<<~RUBY)
        ::Kernel.debugger
        ^^^^^^^^^^^^^^^^^ Remove debugger entry point `::Kernel.debugger`.
      RUBY
    end
  end

  context 'RubyJard' do
    it 'registers an offense for a jard call' do
      expect_offense(<<~RUBY)
        jard
        ^^^^ Remove debugger entry point `jard`.
      RUBY
    end
  end

  context 'web console' do
    it 'registers an offense for a `binding.console` call' do
      expect_offense(<<~RUBY)
        binding.console
        ^^^^^^^^^^^^^^^ Remove debugger entry point `binding.console`.
      RUBY
    end

    it 'does not register an offense for `console` without a receiver' do
      expect_no_offenses('console')
    end
  end

  it 'does not register an offense for a binding method that is not disallowed' do
    expect_no_offenses('binding.pirate')
  end

  %w[debugger byebug console pry remote_pry pry_remote irb save_and_open_page
     save_and_open_screenshot remote_byebug].each do |src|
    it "does not register an offense for a #{src} in comments" do
      expect_no_offenses(<<~RUBY)
        # #{src}
        # Kernel.#{src}
      RUBY
    end

    it "does not register an offense for a #{src} method" do
      expect_no_offenses("code.#{src}")
    end
  end

  context 'when a method group is disabled with nil' do
    let!(:old_pry_config) { cur_cop_config['DebuggerMethods']['Pry'] }

    before { cur_cop_config['DebuggerMethods']['Pry'] = nil }

    after { cur_cop_config['DebuggerMethods']['Pry'] = old_pry_config }

    it 'does not register an offense for a Pry debugger call' do
      expect_no_offenses('binding.pry')
    end

    it 'does register an offense for another group' do
      expect_offense(<<~RUBY)
        binding.irb
        ^^^^^^^^^^^ Remove debugger entry point `binding.irb`.
      RUBY
    end
  end

  context 'when a method group is disabled with false' do
    let!(:old_pry_config) { cur_cop_config['DebuggerMethods']['Pry'] }

    before { cur_cop_config['DebuggerMethods']['Pry'] = false }

    after { cur_cop_config['DebuggerMethods']['Pry'] = old_pry_config }

    it 'does not register an offense for a Pry debugger call' do
      expect_no_offenses('binding.pry')
    end

    it 'does register an offense for another group' do
      expect_offense(<<~RUBY)
        binding.irb
        ^^^^^^^^^^^ Remove debugger entry point `binding.irb`.
      RUBY
    end
  end
end
