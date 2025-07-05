package middleware

import (
	"math/rand"
	"sync"
	"sync/atomic"
	"time"

	"api-gateway/config"
)

// LoadBalancer interface
type LoadBalancer interface {
	NextBackend() string
	MarkBackendDown(backend string)
	MarkBackendUp(backend string)
	GetHealthyBackends() []string
}

// Round Robin Load Balancer
type RoundRobinLB struct {
	backends        []string
	healthyBackends []string
	current         uint64
	mutex           sync.RWMutex
}

func NewRoundRobinLB(backends []string) *RoundRobinLB {
	return &RoundRobinLB{
		backends:        backends,
		healthyBackends: make([]string, len(backends)),
	}
}

func (lb *RoundRobinLB) NextBackend() string {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()
	
	if len(lb.healthyBackends) == 0 {
		if len(lb.backends) == 0 {
			return ""
		}
		// Si no hay backends saludables, usar todos como fallback
		next := atomic.AddUint64(&lb.current, 1)
		return lb.backends[(next-1)%uint64(len(lb.backends))]
	}
	
	next := atomic.AddUint64(&lb.current, 1)
	return lb.healthyBackends[(next-1)%uint64(len(lb.healthyBackends))]
}

func (lb *RoundRobinLB) MarkBackendDown(backend string) {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()
	
	// Remover de la lista de backends saludables
	newHealthy := make([]string, 0, len(lb.healthyBackends))
	for _, b := range lb.healthyBackends {
		if b != backend {
			newHealthy = append(newHealthy, b)
		}
	}
	lb.healthyBackends = newHealthy
}

func (lb *RoundRobinLB) MarkBackendUp(backend string) {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()
	
	// Verificar si ya está en la lista
	for _, b := range lb.healthyBackends {
		if b == backend {
			return
		}
	}
	
	// Verificar si es un backend válido
	for _, b := range lb.backends {
		if b == backend {
			lb.healthyBackends = append(lb.healthyBackends, backend)
			return
		}
	}
}

func (lb *RoundRobinLB) GetHealthyBackends() []string {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()
	
	result := make([]string, len(lb.healthyBackends))
	copy(result, lb.healthyBackends)
	return result
}

// Random Load Balancer
type RandomLB struct {
	backends        []string
	healthyBackends []string
	rand            *rand.Rand
	mutex           sync.RWMutex
}

func NewRandomLB(backends []string) *RandomLB {
	return &RandomLB{
		backends:        backends,
		healthyBackends: make([]string, len(backends)),
		rand:            rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

func (lb *RandomLB) NextBackend() string {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()
	
	if len(lb.healthyBackends) == 0 {
		if len(lb.backends) == 0 {
			return ""
		}
		return lb.backends[lb.rand.Intn(len(lb.backends))]
	}
	
	return lb.healthyBackends[lb.rand.Intn(len(lb.healthyBackends))]
}

func (lb *RandomLB) MarkBackendDown(backend string) {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()
	
	newHealthy := make([]string, 0, len(lb.healthyBackends))
	for _, b := range lb.healthyBackends {
		if b != backend {
			newHealthy = append(newHealthy, b)
		}
	}
	lb.healthyBackends = newHealthy
}

func (lb *RandomLB) MarkBackendUp(backend string) {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()
	
	for _, b := range lb.healthyBackends {
		if b == backend {
			return
		}
	}
	
	for _, b := range lb.backends {
		if b == backend {
			lb.healthyBackends = append(lb.healthyBackends, backend)
			return
		}
	}
}

func (lb *RandomLB) GetHealthyBackends() []string {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()
	
	result := make([]string, len(lb.healthyBackends))
	copy(result, lb.healthyBackends)
	return result
}

// Weighted Load Balancer
type WeightedLB struct {
	backends []WeightedBackend
	mutex    sync.RWMutex
	current  int
}

type WeightedBackend struct {
	URL           string
	Weight        int
	CurrentWeight int
	Healthy       bool
}

func NewWeightedLB(backends []string, weights []int) *WeightedLB {
	if len(weights) != len(backends) {
		// Si no se proporcionan pesos, usar peso igual para todos
		weights = make([]int, len(backends))
		for i := range weights {
			weights[i] = 1
		}
	}
	
	weightedBackends := make([]WeightedBackend, len(backends))
	for i, backend := range backends {
		weightedBackends[i] = WeightedBackend{
			URL:           backend,
			Weight:        weights[i],
			CurrentWeight: 0,
			Healthy:       true,
		}
	}
	
	return &WeightedLB{
		backends: weightedBackends,
	}
}

func (lb *WeightedLB) NextBackend() string {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()
	
	if len(lb.backends) == 0 {
		return ""
	}
	
	// Algoritmo Weighted Round Robin
	totalWeight := 0
	selectedBackend := -1
	
	for i := range lb.backends {
		if !lb.backends[i].Healthy {
			continue
		}
		
		lb.backends[i].CurrentWeight += lb.backends[i].Weight
		totalWeight += lb.backends[i].Weight
		
		if selectedBackend == -1 || lb.backends[i].CurrentWeight > lb.backends[selectedBackend].CurrentWeight {
			selectedBackend = i
		}
	}
	
	if selectedBackend == -1 {
		// No hay backends saludables, usar el primero como fallback
		return lb.backends[0].URL
	}
	
	lb.backends[selectedBackend].CurrentWeight -= totalWeight
	return lb.backends[selectedBackend].URL
}

func (lb *WeightedLB) MarkBackendDown(backend string) {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()
	
	for i := range lb.backends {
		if lb.backends[i].URL == backend {
			lb.backends[i].Healthy = false
			break
		}
	}
}

func (lb *WeightedLB) MarkBackendUp(backend string) {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()
	
	for i := range lb.backends {
		if lb.backends[i].URL == backend {
			lb.backends[i].Healthy = true
			break
		}
	}
}

func (lb *WeightedLB) GetHealthyBackends() []string {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()
	
	var healthy []string
	for _, backend := range lb.backends {
		if backend.Healthy {
			healthy = append(healthy, backend.URL)
		}
	}
	return healthy
}

// Least Connections Load Balancer
type LeastConnectionsLB struct {
	backends    []ConnectionBackend
	mutex       sync.RWMutex
}

type ConnectionBackend struct {
	URL         string
	Connections int32
	Healthy     bool
}

func NewLeastConnectionsLB(backends []string) *LeastConnectionsLB {
	connectionBackends := make([]ConnectionBackend, len(backends))
	for i, backend := range backends {
		connectionBackends[i] = ConnectionBackend{
			URL:         backend,
			Connections: 0,
			Healthy:     true,
		}
	}
	
	return &LeastConnectionsLB{
		backends: connectionBackends,
	}
}

func (lb *LeastConnectionsLB) NextBackend() string {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()
	
	if len(lb.backends) == 0 {
		return ""
	}
	
	selectedBackend := -1
	minConnections := int32(-1)
	
	for i, backend := range lb.backends {
		if !backend.Healthy {
			continue
		}
		
		if selectedBackend == -1 || backend.Connections < minConnections {
			selectedBackend = i
			minConnections = backend.Connections
		}
	}
	
	if selectedBackend == -1 {
		return lb.backends[0].URL
	}
	
	// Incrementar contador de conexiones
	atomic.AddInt32(&lb.backends[selectedBackend].Connections, 1)
	
	return lb.backends[selectedBackend].URL
}

func (lb *LeastConnectionsLB) ReleaseConnection(backend string) {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()
	
	for i := range lb.backends {
		if lb.backends[i].URL == backend {
			atomic.AddInt32(&lb.backends[i].Connections, -1)
			// Asegurar que no sea negativo
			if atomic.LoadInt32(&lb.backends[i].Connections) < 0 {
				atomic.StoreInt32(&lb.backends[i].Connections, 0)
			}
			break
		}
	}
}

func (lb *LeastConnectionsLB) MarkBackendDown(backend string) {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()
	
	for i := range lb.backends {
		if lb.backends[i].URL == backend {
			lb.backends[i].Healthy = false
			break
		}
	}
}

func (lb *LeastConnectionsLB) MarkBackendUp(backend string) {
	lb.mutex.Lock()
	defer lb.mutex.Unlock()
	
	for i := range lb.backends {
		if lb.backends[i].URL == backend {
			lb.backends[i].Healthy = true
			break
		}
	}
}

func (lb *LeastConnectionsLB) GetHealthyBackends() []string {
	lb.mutex.RLock()
	defer lb.mutex.RUnlock()
	
	var healthy []string
	for _, backend := range lb.backends {
		if backend.Healthy {
			healthy = append(healthy, backend.URL)
		}
	}
	return healthy
}

// Factory para crear load balancers
func NewLoadBalancer(config config.LoadBalancerConfig) LoadBalancer {
	if !config.Enabled || len(config.Backends) == 0 {
		return nil
	}
	
	switch config.Strategy {
	case "round_robin":
		lb := NewRoundRobinLB(config.Backends)
		// Inicializar todos como saludables
		for _, backend := range config.Backends {
			lb.MarkBackendUp(backend)
		}
		return lb
	case "random":
		lb := NewRandomLB(config.Backends)
		for _, backend := range config.Backends {
			lb.MarkBackendUp(backend)
		}
		return lb
	case "weighted":
		// Para weighted, podrías extender la config para incluir pesos
		lb := NewWeightedLB(config.Backends, nil)
		return lb
	case "least_connections":
		return NewLeastConnectionsLB(config.Backends)
	default:
		// Default a round robin
		lb := NewRoundRobinLB(config.Backends)
		for _, backend := range config.Backends {
			lb.MarkBackendUp(backend)
		}
		return lb
	}
}