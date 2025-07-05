package health

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"
)

type Checker struct {
	services map[string]*ServiceHealth
	client   *http.Client
	mutex    sync.RWMutex
}

type ServiceHealth struct {
	Name      string
	URL       string
	Healthy   bool
	LastCheck time.Time
	Interval  time.Duration
	Error     string
}

func NewChecker() *Checker {
	return &Checker{
		services: make(map[string]*ServiceHealth),
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

func (hc *Checker) AddService(name, healthURL string, interval time.Duration) {
	hc.mutex.Lock()
	defer hc.mutex.Unlock()

	hc.services[name] = &ServiceHealth{
		Name:     name,
		URL:      healthURL,
		Healthy:  true,
		Interval: interval,
	}

	fmt.Printf("📊 Health check added for service: %s -> %s (every %v)\n", name, healthURL, interval)
}

func (hc *Checker) Start(ctx context.Context) {
	hc.mutex.RLock()
	services := make([]*ServiceHealth, 0, len(hc.services))
	for _, service := range hc.services {
		services = append(services, service)
	}
	hc.mutex.RUnlock()

	for _, service := range services {
		go hc.checkServiceHealth(ctx, service)
	}

	fmt.Printf("🏥 Health checker started for %d services\n", len(services))
}

func (hc *Checker) checkServiceHealth(ctx context.Context, service *ServiceHealth) {
	// Primera verificación inmediata
	hc.performHealthCheck(service)

	ticker := time.NewTicker(service.Interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			fmt.Printf("🏥 Health checker stopped for service: %s\n", service.Name)
			return
		case <-ticker.C:
			hc.performHealthCheck(service)
		}
	}
}

func (hc *Checker) performHealthCheck(service *ServiceHealth) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", service.URL, nil)
	if err != nil {
		hc.updateServiceHealth(service.Name, false, fmt.Sprintf("Error creating request: %v", err))
		return
	}

	resp, err := hc.client.Do(req)
	if err != nil {
		hc.updateServiceHealth(service.Name, false, fmt.Sprintf("Request failed: %v", err))
		return
	}
	defer resp.Body.Close()

	healthy := resp.StatusCode >= 200 && resp.StatusCode < 300
	var errorMsg string
	if !healthy {
		errorMsg = fmt.Sprintf("Unhealthy status code: %d", resp.StatusCode)
	}

	hc.updateServiceHealth(service.Name, healthy, errorMsg)
}

func (hc *Checker) updateServiceHealth(serviceName string, healthy bool, errorMsg string) {
	hc.mutex.Lock()
	defer hc.mutex.Unlock()

	if service, exists := hc.services[serviceName]; exists {
		previousHealth := service.Healthy
		service.Healthy = healthy
		service.LastCheck = time.Now()
		service.Error = errorMsg

		// Log cambios de estado
		if previousHealth != healthy {
			status := "❌ UNHEALTHY"
			if healthy {
				status = "✅ HEALTHY"
			}
			fmt.Printf("🏥 Service %s is now %s (checked at %s)\n",
				serviceName, status, service.LastCheck.Format("15:04:05"))
			if errorMsg != "" {
				fmt.Printf("   Error: %s\n", errorMsg)
			}
		}
	}
}

func (hc *Checker) IsHealthy(serviceName string) bool {
	hc.mutex.RLock()
	defer hc.mutex.RUnlock()

	service, exists := hc.services[serviceName]
	return exists && service.Healthy
}

func (hc *Checker) GetLastCheck(serviceName string) time.Time {
	hc.mutex.RLock()
	defer hc.mutex.RUnlock()

	if service, exists := hc.services[serviceName]; exists {
		return service.LastCheck
	}
	return time.Time{}
}

func (hc *Checker) GetServiceHealth(serviceName string) (*ServiceHealth, bool) {
	hc.mutex.RLock()
	defer hc.mutex.RUnlock()

	service, exists := hc.services[serviceName]
	if !exists {
		return nil, false
	}

	// Retornar una copia para evitar modificaciones concurrentes
	return &ServiceHealth{
		Name:      service.Name,
		URL:       service.URL,
		Healthy:   service.Healthy,
		LastCheck: service.LastCheck,
		Interval:  service.Interval,
		Error:     service.Error,
	}, true
}

func (hc *Checker) GetAllServicesHealth() map[string]*ServiceHealth {
	hc.mutex.RLock()
	defer hc.mutex.RUnlock()

	result := make(map[string]*ServiceHealth)
	for name, service := range hc.services {
		result[name] = &ServiceHealth{
			Name:      service.Name,
			URL:       service.URL,
			Healthy:   service.Healthy,
			LastCheck: service.LastCheck,
			Interval:  service.Interval,
			Error:     service.Error,
		}
	}
	return result
}
