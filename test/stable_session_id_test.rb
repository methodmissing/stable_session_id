require 'init'

require "#{File.dirname(__FILE__)}/abstract_unit"
require 'stringio'

class CookieStoreTest < ActionController::IntegrationTest
  SessionKey = '_myapp_session'
  SessionSecret = 'b3c631c314c0bbca50c1b2843150fe33'

  DispatcherApp = ActionController::Dispatcher.new
  CookieStoreApp = ActionController::Session::CookieStore.new(DispatcherApp,
                     :key => SessionKey, :secret => SessionSecret, :stable_session_id => true)

  SignedBar = "BAh7BjoIZm9vIghiYXI%3D--" +
    "fef868465920f415f2c0652d6910d3af288a0367"

  StableSignedBar = "BAh7BzoIZm9vIghiYXI6D3Nlc3Npb25faWQiDnN0YWJsZV9pZA%3D%3D--" + "ff107f1d5a842f00b988a96057abf7e73a49e870"

  class TestController < ActionController::Base
    def no_session_access
      head :ok
    end

    def stable_session_id
      session[:session_id] = 'stable_id'
      render :text => session.id
    end

    def set_session_value
      session[:session_id] = 'stable_id'
      session[:foo] = "bar"
      head :ok
    end

    def get_session_value
      render :text => "foo: #{session[:foo].inspect}"
    end

    def raise_data_overflow
      session[:foo] = 'bye!' * 1024
      head :ok
    end

    def rescue_action(e) raise end
  end

  def setup
    @integration_session = open_session(CookieStoreApp)
  end

  def test_sets_stable_session_id_preference
    assert ActionController::Session::CookieStore.new(DispatcherApp,
                       :key => SessionKey, :secret => SessionSecret, :stable_session_id => true).stable_session_id
  end

  def test_raises_argument_error_if_missing_session_key
    assert_raise(ArgumentError, nil.inspect) {
      ActionController::Session::CookieStore.new(nil,
        :key => nil, :secret => SessionSecret)
    }

    assert_raise(ArgumentError, ''.inspect) {
      ActionController::Session::CookieStore.new(nil,
        :key => '', :secret => SessionSecret)
    }
  end

  def test_raises_argument_error_if_missing_secret
    assert_raise(ArgumentError, nil.inspect) {
      ActionController::Session::CookieStore.new(nil,
       :key => SessionKey, :secret => nil)
    }

    assert_raise(ArgumentError, ''.inspect) {
      ActionController::Session::CookieStore.new(nil,
       :key => SessionKey, :secret => '')
    }
  end

  def test_raises_argument_error_if_secret_is_probably_insecure
    assert_raise(ArgumentError, "password".inspect) {
      ActionController::Session::CookieStore.new(nil,
       :key => SessionKey, :secret => "password")
    }

    assert_raise(ArgumentError, "secret".inspect) {
      ActionController::Session::CookieStore.new(nil,
       :key => SessionKey, :secret => "secret")
    }

    assert_raise(ArgumentError, "12345678901234567890123456789".inspect) {
      ActionController::Session::CookieStore.new(nil,
       :key => SessionKey, :secret => "12345678901234567890123456789")
    }
  end

  def test_setting_session_value
    with_test_route_set do
      get '/set_session_value'
      assert_response :success
      assert_equal ["_myapp_session=#{StableSignedBar}; path=/"],
        headers['Set-Cookie']
   end
  end

  def test_getting_session_value
    with_test_route_set do
      cookies[SessionKey] = SignedBar
      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: "bar"', response.body
   end
  end

  def test_disregards_tampered_sessions
    with_test_route_set do
      cookies[SessionKey] = "BAh7BjoIZm9vIghiYXI%3D--123456780"
      get '/get_session_value'
      assert_response :success
      assert_equal 'foo: nil', response.body
    end
  end

  def test_close_raises_when_data_overflows
    with_test_route_set do
      assert_raise(ActionController::Session::CookieStore::CookieOverflow) {
        get '/raise_data_overflow'
      }
    end
  end

  def test_doesnt_write_session_cookie_if_session_is_not_accessed
    with_test_route_set do
      get '/no_session_access'
      assert_response :success
      assert_equal [], headers['Set-Cookie']
    end
  end

  def test_doesnt_write_session_cookie_if_session_is_unchanged
    with_test_route_set do
      cookies[SessionKey] = "BAh7BjoIZm9vIghiYXI%3D--" +
        "fef868465920f415f2c0652d6910d3af288a0367"
      get '/no_session_access'
      assert_response :success
      assert_equal [], headers['Set-Cookie']
    end
  end

  def test_stable_session_id
    with_test_route_set do
      cookies[SessionKey] = SignedBar
      get '/stable_session_id'
      assert_response :success
      assert_equal 'stable_id', response.body
    end  
  end

  private
    def with_test_route_set
      with_routing do |set|
        set.draw do |map|
          map.with_options :controller => "cookie_store_test/test" do |c|
            c.connect "/:action"
          end
        end
        yield
      end
    end
end