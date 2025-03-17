package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"

	"github.com/IBM/sarama"
)

const (
	//broker        = "localhost:9092"  // Kafka broker address
	topic         = "orders"          // Kafka topic name
	consumerGroup = "inventory-group" // Consumer group name
)

// ConsumerGroupHandler processes messages from Kafka partitions
type ConsumerGroupHandler struct{}

// Setup is called when the consumer group session is initialized
func (h *ConsumerGroupHandler) Setup(sarama.ConsumerGroupSession) error {
	fmt.Println("Consumer group setup completed")
	return nil
}

// Cleanup is called when the consumer group session ends
func (h *ConsumerGroupHandler) Cleanup(sarama.ConsumerGroupSession) error {
	fmt.Println("Consumer group cleanup")
	return nil
}

// ConsumeClaim is called to process messages from an assigned partition
func (h *ConsumerGroupHandler) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for message := range claim.Messages() {
		fmt.Printf("Consumed message: key=%s, value=%s, partition=%d, offset=%d\n",
			string(message.Key), string(message.Value), message.Partition, message.Offset)

		// Mark the message as processed
		session.MarkMessage(message, "")
	}
	return nil
}

func main() {
	// Configure Kafka consumer group
	config := sarama.NewConfig()
	config.Version = sarama.V3_0_0_0                                                 // Kafka version
	config.Consumer.Group.Rebalance.Strategy = sarama.NewBalanceStrategyRoundRobin() // Load balancing
	config.Consumer.Offsets.Initial = sarama.OffsetNewest                            // Start from the latest message

	broker := os.Getenv("BROKER")

	// Create consumer group client
	client, err := sarama.NewConsumerGroup([]string{broker}, consumerGroup, config)
	if err != nil {
		log.Fatalf("Error creating consumer group: %v", err)
	}
	defer client.Close()

	// Handle OS signals for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	wg := &sync.WaitGroup{}
	wg.Add(1)

	go func() {
		defer wg.Done()
		handler := &ConsumerGroupHandler{}

		for {
			err := client.Consume(ctx, []string{topic}, handler)
			if err != nil {
				log.Printf("Error consuming: %v", err)
			}
			if ctx.Err() != nil {
				return
			}
		}
	}()

	// Catch shutdown signals
	sigchan := make(chan os.Signal, 1)
	signal.Notify(sigchan, os.Interrupt, syscall.SIGTERM)
	<-sigchan

	fmt.Println("Shutting down consumer...")
	cancel()
	wg.Wait()
}
