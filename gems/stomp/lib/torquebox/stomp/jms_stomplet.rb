puts "loading TorqueBox::Stomp::JmsStomplet"

module TorqueBox
  module Stomp
    class JmsStomplet

      include TorqueBox::Injectors
    
      def initialize()
        @connection_factory = inject( 'xa-connection-factory' )
        @subscriptions = {}
      end
    
      def xa_resources
        @xa_resources 
      end
    
      def configure(stomplet_config)
        @connection = @connection_factory.create_connection
        @connection.start
        @session = @connection.create_session
        @xa_resources = [ @session.xa_resource ]
      end
    
      def destroy
        @connection.stop
        @connection.close
      end
      # -----
      # -----
    
      def on_unsubscribe(subscriber)
        puts "unsubscribe #{subscriber}"
        subscriptions = @subscriptions.delete( subscriber )
        subscriptions.each do |subscription|
          puts "closing #{subscription}"
          subscription.close
        end
      end
    
      # -----
      # -----
    
      def subscribe_to(subscriber, destination_name, destination_type)
        jms_session = @session.jms_session
        destination = destination_type.to_sym == :queue ? jms_session.create_queue( destination_name ) : jms_session.create_topic( destination_name )
        consumer = @session.jms_session.create_consumer( destination.to_java )
        consumer.message_listener = MessageListener.new( subscriber )
        @subscriptions[ subscriber ] ||= []
        @subscriptions[ subscriber ] << consumer
      end
    
      def send_to(stomp_message, destination_name, destination_type)
        jms_session = @session.jms_session
        destination = destination_type.to_sym == :queue ? jms_session.create_queue( destination_name ) : jms_session.create_topic( destination_name )
    
        producer    = @session.jms_session.create_producer( destination.to_java )
        jms_message = @session.jms_session.create_text_message
        jms_message.text = stomp_message.content_as_string
        producer.send( destination, jms_message )
      end
    
      class MessageListener
        include javax.jms.MessageListener
    
        def initialize(subscriber)
          @subscriber = subscriber
        end
    
        def onMessage(jms_message)
          stomp_message = org.projectodd.stilts.stomp::StompMessages.createStompMessage( @subscriber.destination, jms_message.text )
          @subscriber.send( stomp_message )
        end
    
      end
    
    end

  end
end 
