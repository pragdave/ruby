# frozen_string_literal: false
require 'test/unit'
require 'optparse'

class TestOptionParser < Test::Unit::TestCase
  def setup
    @opt = OptionParser.new
    @flag = self.class		# cannot set by option
  end

  class DummyOutput < String
    alias write concat
  end
  def assert_no_error(*args)
    $stderr, stderr = DummyOutput.new, $stderr
    assert_nothing_raised(*args) {return yield}
  ensure
    stderr, $stderr = $stderr, stderr
    $!.backtrace.delete_if {|e| /\A#{Regexp.quote(__FILE__)}:#{__LINE__-2}/o =~ e} if $!
    assert_empty(stderr)
  end
  alias no_error assert_no_error

  def test_permute
    assert_equal(%w"", no_error {@opt.permute!(%w"")})
    assert_equal(self.class, @flag)
    assert_equal(%w"foo bar", no_error {@opt.permute!(%w"foo bar")})
    assert_equal(self.class, @flag)
    assert_equal(%w"- foo bar", no_error {@opt.permute!(%w"- foo bar")})
    assert_equal(self.class, @flag)
    assert_equal(%w"foo bar", no_error {@opt.permute!(%w"-- foo bar")})
    assert_equal(self.class, @flag)
    assert_equal(%w"foo - bar", no_error {@opt.permute!(%w"foo - bar")})
    assert_equal(self.class, @flag)
    assert_equal(%w"foo bar", no_error {@opt.permute!(%w"foo -- bar")})
    assert_equal(self.class, @flag)
    assert_equal(%w"foo --help bar", no_error {@opt.permute!(%w"foo -- --help bar")})
    assert_equal(self.class, @flag)
  end

  def test_order
    assert_equal(%w"", no_error {@opt.order!(%w"")})
    assert_equal(self.class, @flag)
    assert_equal(%w"foo bar", no_error {@opt.order!(%w"foo bar")})
    assert_equal(self.class, @flag)
    assert_equal(%w"- foo bar", no_error {@opt.order!(%w"- foo bar")})
    assert_equal(self.class, @flag)
    assert_equal(%w"foo bar", no_error {@opt.permute!(%w"-- foo bar")})
    assert_equal(self.class, @flag)
    assert_equal(%w"foo - bar", no_error {@opt.order!(%w"foo - bar")})
    assert_equal(self.class, @flag)
    assert_equal(%w"foo -- bar", no_error {@opt.order!(%w"foo -- bar")})
    assert_equal(self.class, @flag)
    assert_equal(%w"foo -- --help bar", no_error {@opt.order!(%w"foo -- --help bar")})
    assert_equal(self.class, @flag)
  end

  def test_regexp
    return unless defined?(@reopt)
    assert_equal(%w"", no_error {@opt.parse!(%w"--regexp=/foo/")})
    assert_equal(/foo/, @reopt)
    assert_equal(%w"", no_error {@opt.parse!(%w"--regexp=/foo/i")})
    assert_equal(/foo/i, @reopt)
    assert_equal(%w"", no_error {@opt.parse!(%w"--regexp=/foo/n")})
    assert_equal(/foo/n, @reopt)
    assert_equal(%w"", no_error {@opt.parse!(%W"--regexp=/\u{3042}/s")})
    assert_equal(Encoding::Windows_31J, @reopt.encoding)
    assert_equal("\x82\xa0".force_encoding(Encoding::Windows_31J), @reopt.source)
  end

  def test_into
    @opt.def_option "-h", "--host=HOST", "hostname"
    @opt.def_option "-p", "--port=PORT", "port", Integer
    @opt.def_option "-v", "--verbose" do @verbose = true end
    @opt.def_option "-q", "--quiet" do @quiet = true end
    @opt.def_option "-o", "--option [OPT]" do |opt| @option = opt end
    result = {}
    @opt.parse %w(--host localhost --port 8000 -v), into: result
    assert_equal({host: "localhost", port: 8000, verbose: true}, result)
    assert_equal(true, @verbose)
    result = {}
    @opt.parse %w(--option -q), into: result
    assert_equal({quiet: true, option: nil}, result)
    result = {}
    @opt.parse %w(--option OPTION -v), into: result
    assert_equal({verbose: true, option: "OPTION"}, result)
  end

  def test_require_exact
    @opt.def_option('-F', '--zrs=IRS', 'zrs')
    %w(--zrs --zr --z -zfoo -z -F -Ffoo).each do |arg|
      result = {}
      @opt.parse([arg, 'foo'], into: result)
      assert_equal({zrs: 'foo'}, result)
    end

    @opt.require_exact = true
    [%w(--zrs foo), %w(--zrs=foo), %w(-F foo), %w(-Ffoo)].each do |args|
      result = {}
      @opt.parse(args, into: result)
      assert_equal({zrs: 'foo'}, result)
    end

    assert_raise(OptionParser::InvalidOption) {@opt.parse(%w(--zr foo))}
    assert_raise(OptionParser::InvalidOption) {@opt.parse(%w(--z foo))}
    assert_raise(OptionParser::InvalidOption) {@opt.parse(%w(-zrs foo))}
    assert_raise(OptionParser::InvalidOption) {@opt.parse(%w(-zr foo))}
    assert_raise(OptionParser::InvalidOption) {@opt.parse(%w(-z foo))}

    @opt.def_option('-f', '--[no-]foo', 'foo') {|arg| @foo = arg}
    @opt.parse(%w[-f])
    assert_equal(true, @foo)
    @opt.parse(%w[--foo])
    assert_equal(true, @foo)
    @opt.parse(%w[--no-foo])
    assert_equal(false, @foo)
  end

  def test_raise_unknown
    @opt.def_option('--my-foo [ARG]') {|arg| @foo = arg}
    assert @opt.raise_unknown

    @opt.raise_unknown = false
    assert_equal(%w[--my-bar], @opt.parse(%w[--my-foo --my-bar]))
    assert_nil(@foo)

    assert_equal(%w[--my-bar], @opt.parse(%w[--my-foo x --my-bar]))
    assert_equal("x", @foo)
  end

  def test_nonopt_pattern
    @opt.def_option(/^[^-]/) do |arg|
      assert(false, "Never gets called")
    end
    e = assert_raise(OptionParser::InvalidOption) {@opt.parse(%w(-t))}
    assert_equal(["-t"], e.args)
  end
end
