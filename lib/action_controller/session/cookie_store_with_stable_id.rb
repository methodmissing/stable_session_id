module ActionController
  module Session
    module CookieStoreWithStableSessionId
      module SessionHashExtensions
        
        def self.install!
          ::ActionController::Session::CookieStore::SessionHash.send( :include, self )
        end
        
        def session_id
          load! unless @loaded
          @id
        end
        
        private
          def load!
            session = @by.send(:load_session, @env)
            ::ActionController::Base.logger.info "session load is #{session.inspect}"
            @id = session[:session_id]
            replace(session)
            @loaded = true
          end
          
      end  
      
      def self.install!
        ::ActionController::Session::CookieStore.send :include, self
      end
      
      def self.included( base )
        base.send :include, InstanceMethods      
        base.alias_method_chain :initialize, :stable_id
        base.alias_method_chain :marshal, :stable_id
      end
      
      module InstanceMethods
        
        def initialize_with_stable_id( app, options = {} )
          options.reverse_merge!( :stable_session_id => false )
          @stable_session_id = options[:stable_session_id]
          initialize_without_stable_id( app, options )
        end
        
        def stable_session_id
          @stable_session_id
        end
        
        def marshal_with_stable_id( session )
          ::ActionController::Base.logger.info "marshal_with_stable_id #{session.inspect}"
          session = stable_session_id!( session )
          marshal_without_stable_id( session )
        end
        
        def call(env)
          session_data = SessionHash.new(self, env)
          ::ActionController::Base.logger.info "[call] session_data #{session_data.inspect}"
          original_value = session_data.dup

          env[ENV_SESSION_KEY] = session_data
          env[ENV_SESSION_OPTIONS_KEY] = @default_options.dup

          status, headers, body = @app.call(env)

          unless env[ENV_SESSION_KEY] == original_value
            session_data = marshal(env[ENV_SESSION_KEY].to_hash)

            ::ActionController::Base.logger.info "[call], not equal to original value, session data #{session_data.inspect}"

            raise CookieOverflow if session_data.size > MAX

            options = env[ENV_SESSION_OPTIONS_KEY]
            cookie = Hash.new
            cookie[:value] = session_data
            unless options[:expire_after].nil?
              cookie[:expires] = Time.now + options[:expire_after]
            end

            cookie = build_cookie(@key, cookie.merge(options))
            case headers[HTTP_SET_COOKIE]
            when Array
              headers[HTTP_SET_COOKIE] << cookie
            when String
              headers[HTTP_SET_COOKIE] = [headers[HTTP_SET_COOKIE], cookie]
            when nil
              headers[HTTP_SET_COOKIE] = cookie
            end
          end

          [status, headers, body]
        end        
        
        def unmarshal(cookie)
          ::ActionController::Base.logger.info "Raw cookie is #{cookie.inspect}"
          if cookie
            cookie_data = verifier.verify(cookie)
            stable_session_id!( cookie_data )
          end
          rescue ActiveSupport::MessageVerifier::InvalidSignature
            #delete
            #raise TamperedWithCookie
            nil
        end            
        
        def load_session(env)
          request = Rack::Request.new(env)
          ::ActionController::Base.logger.info "cookies is #{request.cookies.inspect}"
          session_data = request.cookies[@key]
          unmarshal(session_data) || {}
        end
        
        def stable_session_id!( data  )
          return data unless @stable_session_id
          ( data ||= {} ).merge!( inject_stable_session_id!( data ) )
          ::ActionController::Base.logger.info "stable_session_id! #{data.inspect}"
          #@session.instance_variable_set(:@session_id, data[:session_id])
          data
        end

        def inject_stable_session_id!( data )
          if data.respond_to?(:key?) && !data.key?( :session_id )
            ::ActionController::Base.logger.info "no session_id"
            { :session_id => ::ActiveSupport::SecureRandom.hex(16) }
          else
            ::ActionController::Base.logger.info "has session_id"
           {}
          end  
        end        
        
      end
            
    end
  end
end

ActionController::Session::CookieStoreWithStableSessionId.install!
ActionController::Session::CookieStoreWithStableSessionId::SessionHashExtensions.install!