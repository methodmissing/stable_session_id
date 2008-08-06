require 'init'

require 'rubygems'
require "#{File.dirname(__FILE__)}/abstract_unit"
require 'action_controller/cgi_process'
require 'action_controller/cgi_ext'

require 'stringio'

class StableSessionIdTest < Test::Unit::TestCase

  def self.default_session_options
    { 'database_manager' => CGI::Session::CookieStore,
      'session_key' => '_myapp_session',
      'secret' => 'Keep it secret; keep it safe.',
      'no_cookies' => true,
      'no_hidden' => true }
  end    
      
  def self.cookies
    { :typical => ['BAh7ByIMdXNlcl9pZGkBeyIKZmxhc2h7BiILbm90aWNlIgxIZXkgbm93--9d20154623b9eeea05c62ab819be0e2483238759', { 'user_id' => 123, 'flash' => { 'notice' => 'Hey now' }}] }
  end

  def setup
    ENV.delete('HTTP_COOKIE')
  end

  def test_should_inject_a_stable_session_id_within_the_cookie
    set_cookie! cookie_value(:typical)
    new_session( 'stable_session_id' => true ) do |session|
      assert_not_nil session['user_id']
      assert_not_nil session[:session_id]      
      assert_not_equal session.session_id, cookie_value(:typical)
    end
  end

  def cookie_value(which)
    self.class.cookies[which].first
  end

  def set_cookie!(value)
    ENV['HTTP_COOKIE'] = "_myapp_session=#{value}"
  end

  def new_session(options = {})
    with_cgi do |cgi|
      assert_nil cgi.output_hidden, "Output hidden params should be empty: #{cgi.output_hidden.inspect}"
      assert_nil cgi.output_cookies, "Output cookies should be empty: #{cgi.output_cookies.inspect}"

      @options = self.class.default_session_options.merge(options)

      session = CGI::Session.new(cgi, @options)
      assert_nil cgi.output_hidden, "Output hidden params should be empty: #{cgi.output_hidden.inspect}"
      assert_nil cgi.output_cookies, "Output cookies should be empty: #{cgi.output_cookies.inspect}"
      
      yield session if block_given?
      session
    end
  end

  def with_cgi
    ENV['REQUEST_METHOD'] = 'GET'
    ENV['HTTP_HOST'] = 'example.com'
    ENV['QUERY_STRING'] = ''

    cgi = CGI.new('query', StringIO.new(''))
    yield cgi if block_given?
    cgi
  end

end