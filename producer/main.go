package main

import (
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	"github.com/IBM/sarama"
)

const (
	//broker = "localhost:9092" // Kafka broker address
	topic = "orders" // Kafka topic name
)

func main() {

	broker := os.Getenv("BROKER")

	// Configure Kafka producer
	config := sarama.NewConfig()
	config.Producer.Return.Successes = true
	config.Producer.Partitioner = sarama.NewRoundRobinPartitioner // Distribute messages evenly across partitions

	// Create Kafka producer
	producer, err := sarama.NewSyncProducer([]string{broker}, config)
	if err != nil {
		log.Fatalf("Error creating Kafka producer: %v", err)
	}
	defer producer.Close()

	// Send messages to Kafka
	for i := 1; i <= 10; i++ {
		orderID := fmt.Sprintf("Order-%d", i)
		value := fmt.Sprintf("Item-%d, Quantity-%d", rand.Intn(100), rand.Intn(10)+1)

		message := &sarama.ProducerMessage{
			Topic: topic,
			Key:   sarama.StringEncoder(orderID), // Order ID as key
			Value: sarama.StringEncoder(value),   // Order details as value
		}

		partition, offset, err := producer.SendMessage(message)
		if err != nil {
			log.Printf("Failed to send message: %v", err)
		} else {
			fmt.Printf("✅ Sent message: key=%s, value=%s → partition=%d, offset=%d\n",
				orderID, value, partition, offset)
		}

		time.Sleep(500 * time.Millisecond) // Simulate delay
	}

	fmt.Println("✅ Finished sending messages!")
}
