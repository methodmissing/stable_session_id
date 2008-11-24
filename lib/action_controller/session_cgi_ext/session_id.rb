CGI::Session.class_eval do
  
  def session_id
    @data ||= @dbman.restore
    if @data[:session_id]
      @data[:session_id]
    else
      super
    end    
  end  
  
end