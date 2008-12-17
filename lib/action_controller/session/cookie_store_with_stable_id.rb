module ActionController
  module Session
    module CookieStoreWithStableSessionId
      module SessionHashExtensions
        
        def self.install!
          ::ActionController::Session::CookieStore::SessionHash.send( :include, self )
        end
        
        def session_id
          load! unless @loaded
          begin
            @id || fetch(:session_id)
          rescue
            nil
          end  
        end
        
        private
          def load!
            session = @by.send(:load_session, @env)
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
          session = stable_session_id!( session )
          marshal_without_stable_id( session )
        end

        def unmarshal(cookie)
          if cookie
            cookie_data = verifier.verify(cookie)
            stable_session_id!( cookie_data )
          end
          rescue ActiveSupport::MessageVerifier::InvalidSignature
            nil
        end            
        
        def load_session(env)
          request = Rack::Request.new(env)
          session_data = request.cookies[@key]
          unmarshal(session_data) || {}
        end
        
        def stable_session_id!( data  )
          return data unless @stable_session_id
          ( data ||= {} ).merge!( inject_stable_session_id!( data ) )
          #@session.instance_variable_set(:@session_id, data[:session_id])
          data
        end

        def inject_stable_session_id!( data )
          if data.respond_to?(:key?) && !data.key?( :session_id )
            { :session_id => ::ActiveSupport::SecureRandom.hex(16) }
          else
           {}
          end  
        end        
        
      end
            
    end
  end
end

ActionController::Session::CookieStoreWithStableSessionId.install!
ActionController::Session::CookieStoreWithStableSessionId::SessionHashExtensions.install!