package main

import (
	"fmt"
	"log"
	"os"

	"api-gateway/config"
	"api-gateway/middleware"
)

func main() {
	// Cargar configuración
	cfg, err := config.LoadConfig("config/config.json")
	if err != nil {
		log.Fatal("Error loading config:", err)
	}

	// Crear middleware de auth
	authMiddleware := middleware.NewAuthMiddleware(&cfg.Auth)

	if len(os.Args) < 4 {
		fmt.Println("Uso: go run generate_token.go <user_id> <username> <role>")
		fmt.Println("")
		fmt.Println("Ejemplos:")
		fmt.Println("  go run generate_token.go user123 john_doe user")
		fmt.Println("  go run generate_token.go admin456 admin_user admin")
		fmt.Println("  go run generate_token.go lead789 lead_user lead")
		os.Exit(1)
	}

	userID := os.Args[1]
	username := os.Args[2]
	role := os.Args[3]

	// Generar token
	token, err := authMiddleware.GenerateToken(userID, username, role)
	if err != nil {
		log.Fatal("Error generating token:", err)
	}

	fmt.Printf("🔐 JWT Token generado:\n")
	fmt.Printf("User ID: %s\n", userID)
	fmt.Printf("Username: %s\n", username)
	fmt.Printf("Role: %s\n", role)
	fmt.Printf("Token: %s\n", token)
	fmt.Printf("\n")
	fmt.Printf("💡 Para usar en requests:\n")
	fmt.Printf("curl -H \"Authorization: Bearer %s\" http://localhost:8001/api/lead/\n", token)
	fmt.Printf("\n")
	fmt.Printf("🔗 Headers completos:\n")
	fmt.Printf("-H \"Authorization: Bearer %s\"\n", token)
	fmt.Printf("-H \"Content-Type: application/json\"\n")
}