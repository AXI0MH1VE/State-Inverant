package main

import (
	"context"
	"log"
	"net"
	"os"

	pb "axiom-hive/proto"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type server struct {
	pb.UnimplementedAxiomGatewayServer
}

func (s *server) IngestRequest(ctx context.Context, req *pb.Request) (*pb.Response, error) {
	log.Printf("Received request: %s", req.Id)

	// TODO: Implement request processing pipeline
	// 1. Route to Guardian-Legal
	// 2. Route to Guardian-Safety
	// 3. Route to Drone
	// 4. Final safety check
	// 5. Audit logging

	response := &pb.Response{
		Id: req.Id,
		Content: "This is a placeholder response. Implementation pending.",
		Validation: &pb.ValidationResult{
			IsValid: true,
			Reason: "Placeholder validation",
		},
		Timestamp: timestamppb.Now(),
	}

	return response, nil
}

func (s *server) GetHealth(ctx context.Context, req *emptypb.Empty) (*pb.HealthStatus, error) {
	return &pb.HealthStatus{
		Healthy:   true,
		Version:   "1.0.0",
		Timestamp: timestamppb.Now(),
	}, nil
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	s := grpc.NewServer()
	pb.RegisterAxiomGatewayServer(s, &server{})

	log.Printf("Service-Gateway listening on port %s", port)
	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
