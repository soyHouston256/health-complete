package middleware

import (
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/labstack/echo/v4"
)

// Estados del Circuit Breaker
type State int

const (
	StateClosed State = iota
	StateHalfOpen
	StateOpen
)

func (s State) String() string {
	switch s {
	case StateClosed:
		return "CLOSED"
	case StateHalfOpen:
		return "HALF_OPEN"
	case StateOpen:
		return "OPEN"
	default:
		return "UNKNOWN"
	}
}

// Contadores para el Circuit Breaker
type Counts struct {
	Requests             uint32
	TotalSuccesses       uint32
	TotalFailures        uint32
	ConsecutiveSuccesses uint32
	ConsecutiveFailures  uint32
}

func (c *Counts) OnRequest() {
	c.Requests++
}

func (c *Counts) OnSuccess() {
	c.TotalSuccesses++
	c.ConsecutiveSuccesses++
	c.ConsecutiveFailures = 0
}

func (c *Counts) OnFailure() {
	c.TotalFailures++
	c.ConsecutiveFailures++
	c.ConsecutiveSuccesses = 0
}

func (c *Counts) Clear() {
	c.Requests = 0
	c.TotalSuccesses = 0
	c.TotalFailures = 0
	c.ConsecutiveSuccesses = 0
	c.ConsecutiveFailures = 0
}

// Configuración del Circuit Breaker
type CircuitBreakerSettings struct {
	Name         string
	MaxRequests  uint32
	Interval     time.Duration
	Timeout      time.Duration
	ReadyToTrip  func(counts Counts) bool
	OnStateChange func(name string, from State, to State)
}

// Circuit Breaker principal
type CircuitBreaker struct {
	name         string
	maxRequests  uint32
	interval     time.Duration
	timeout      time.Duration
	readyToTrip  func(counts Counts) bool
	onStateChange func(name string, from State, to State)
	
	mutex      sync.Mutex
	state      State
	generation uint64
	counts     Counts
	expiry     time.Time
}

func NewCircuitBreaker(settings CircuitBreakerSettings) *CircuitBreaker {
	cb := &CircuitBreaker{
		name:         settings.Name,
		maxRequests:  settings.MaxRequests,
		interval:     settings.Interval,
		timeout:      settings.Timeout,
		readyToTrip:  settings.ReadyToTrip,
		onStateChange: settings.OnStateChange,
		state:        StateClosed,
		expiry:       time.Now().Add(settings.Interval),
	}
	
	if cb.readyToTrip == nil {
		cb.readyToTrip = func(counts Counts) bool {
			return counts.ConsecutiveFailures > 5
		}
	}
	
	return cb
}

func (cb *CircuitBreaker) Execute(req func() (interface{}, error)) (interface{}, error) {
	generation, err := cb.beforeRequest()
	if err != nil {
		return nil, err
	}
	
	defer func() {
		if r := recover(); r != nil {
			cb.afterRequest(generation, false)
			panic(r)
		}
	}()
	
	result, err := req()
	cb.afterRequest(generation, err == nil)
	return result, err
}

func (cb *CircuitBreaker) beforeRequest() (uint64, error) {
	cb.mutex.Lock()
	defer cb.mutex.Unlock()
	
	now := time.Now()
	state, generation := cb.currentState(now)
	
	if state == StateOpen {
		return generation, fmt.Errorf("circuit breaker is open")
	} else if state == StateHalfOpen && cb.counts.Requests >= cb.maxRequests {
		return generation, fmt.Errorf("circuit breaker is half-open, too many requests")
	}
	
	cb.counts.OnRequest()
	return generation, nil
}

func (cb *CircuitBreaker) afterRequest(before uint64, success bool) {
	cb.mutex.Lock()
	defer cb.mutex.Unlock()
	
	now := time.Now()
	state, generation := cb.currentState(now)
	
	if generation != before {
		return
	}
	
	if success {
		cb.onSuccess(state, now)
	} else {
		cb.onFailure(state, now)
	}
}

func (cb *CircuitBreaker) onSuccess(state State, now time.Time) {
	cb.counts.OnSuccess()
	
	if state == StateHalfOpen && cb.counts.ConsecutiveSuccesses >= cb.maxRequests {
		cb.setState(StateClosed, now)
	}
}

func (cb *CircuitBreaker) onFailure(state State, now time.Time) {
	cb.counts.OnFailure()
	
	if cb.readyToTrip(cb.counts) {
		cb.setState(StateOpen, now)
	}
}

func (cb *CircuitBreaker) currentState(now time.Time) (State, uint64) {
	switch cb.state {
	case StateClosed:
		if !cb.expiry.IsZero() && cb.expiry.Before(now) {
			cb.toNewGeneration(now)
		}
	case StateOpen:
		if cb.expiry.Before(now) {
			cb.setState(StateHalfOpen, now)
		}
	}
	return cb.state, cb.generation
}

func (cb *CircuitBreaker) setState(state State, now time.Time) {
	if cb.state == state {
		return
	}
	
	prev := cb.state
	cb.state = state
	cb.toNewGeneration(now)
	
	if cb.onStateChange != nil {
		cb.onStateChange(cb.name, prev, state)
	}
	
	// Log del cambio de estado
	fmt.Printf("🔌 Circuit Breaker [%s]: %s -> %s\n", cb.name, prev, state)
}

func (cb *CircuitBreaker) toNewGeneration(now time.Time) {
	cb.generation++
	cb.counts.Clear()
	
	var zero time.Time
	switch cb.state {
	case StateClosed:
		if cb.interval == 0 {
			cb.expiry = zero
		} else {
			cb.expiry = now.Add(cb.interval)
		}
	case StateOpen:
		cb.expiry = now.Add(cb.timeout)
	default: // StateHalfOpen
		cb.expiry = zero
	}
}

// Estado actual del Circuit Breaker
func (cb *CircuitBreaker) State() State {
	cb.mutex.Lock()
	defer cb.mutex.Unlock()
	
	now := time.Now()
	state, _ := cb.currentState(now)
	return state
}

func (cb *CircuitBreaker) Counts() Counts {
	cb.mutex.Lock()
	defer cb.mutex.Unlock()
	
	return cb.counts
}

// Middleware del Circuit Breaker
func CircuitBreakerMiddleware(serviceName string) echo.MiddlewareFunc {
	settings := CircuitBreakerSettings{
		Name:        serviceName,
		MaxRequests: 3,
		Interval:    time.Minute,
		Timeout:     30 * time.Second,
		ReadyToTrip: func(counts Counts) bool {
			failureRatio := float64(counts.TotalFailures) / float64(counts.Requests)
			return counts.Requests >= 3 && failureRatio >= 0.6
		},
		OnStateChange: func(name string, from State, to State) {
			fmt.Printf("🔌 Circuit Breaker [%s] state changed: %s -> %s\n", name, from, to)
		},
	}
	
	cb := NewCircuitBreaker(settings)
	
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			result, err := cb.Execute(func() (interface{}, error) {
				return nil, next(c)
			})
			
			if err != nil {
				if cb.State() == StateOpen {
					return echo.NewHTTPError(http.StatusServiceUnavailable, map[string]interface{}{
						"error": "Service temporarily unavailable",
						"reason": "Circuit breaker is open",
						"service": serviceName,
						"retry_after": cb.timeout.Seconds(),
					})
				}
				return echo.NewHTTPError(http.StatusBadGateway, "Service error")
			}
			
			return result.(error)
		}
	}
}

// Manager para múltiples Circuit Breakers
type CircuitBreakerManager struct {
	breakers map[string]*CircuitBreaker
	mutex    sync.RWMutex
}

func NewCircuitBreakerManager() *CircuitBreakerManager {
	return &CircuitBreakerManager{
		breakers: make(map[string]*CircuitBreaker),
	}
}

func (cbm *CircuitBreakerManager) GetOrCreateBreaker(serviceName string, settings CircuitBreakerSettings) *CircuitBreaker {
	cbm.mutex.Lock()
	defer cbm.mutex.Unlock()
	
	if cb, exists := cbm.breakers[serviceName]; exists {
		return cb
	}
	
	settings.Name = serviceName
	cb := NewCircuitBreaker(settings)
	cbm.breakers[serviceName] = cb
	return cb
}

func (cbm *CircuitBreakerManager) GetBreaker(serviceName string) (*CircuitBreaker, bool) {
	cbm.mutex.RLock()
	defer cbm.mutex.RUnlock()
	
	cb, exists := cbm.breakers[serviceName]
	return cb, exists
}

func (cbm *CircuitBreakerManager) GetAllBreakers() map[string]*CircuitBreaker {
	cbm.mutex.RLock()
	defer cbm.mutex.RUnlock()
	
	result := make(map[string]*CircuitBreaker)
	for name, cb := range cbm.breakers {
		result[name] = cb
	}
	return result
}

// Middleware que usa el manager
func (cbm *CircuitBreakerManager) Middleware(serviceName string) echo.MiddlewareFunc {
	settings := CircuitBreakerSettings{
		MaxRequests: 5,
		Interval:    time.Minute,
		Timeout:     30 * time.Second,
		ReadyToTrip: func(counts Counts) bool {
			return counts.ConsecutiveFailures >= 5 || 
				   (counts.Requests >= 10 && float64(counts.TotalFailures)/float64(counts.Requests) >= 0.5)
		},
		OnStateChange: func(name string, from State, to State) {
			fmt.Printf("🔌 Circuit Breaker [%s] state changed: %s -> %s (failures: %d, requests: %d)\n", 
				name, from, to, cbm.breakers[name].Counts().TotalFailures, cbm.breakers[name].Counts().Requests)
		},
	}
	
	cb := cbm.GetOrCreateBreaker(serviceName, settings)
	
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			_, err := cb.Execute(func() (interface{}, error) {
				err := next(c)
				// Considerar ciertos status codes como fallos
				if err != nil {
					return nil, err
				}
				
				// Verificar status code de la respuesta
				if c.Response().Status >= 500 {
					return nil, fmt.Errorf("server error: %d", c.Response().Status)
				}
				
				return nil, nil
			})
			
			if err != nil {
				state := cb.State()
				counts := cb.Counts()
				
				if state == StateOpen {
					return echo.NewHTTPError(http.StatusServiceUnavailable, map[string]interface{}{
						"error": "Service temporarily unavailable",
						"reason": "Circuit breaker is open",
						"service": serviceName,
						"state": state.String(),
						"failures": counts.TotalFailures,
						"requests": counts.Requests,
						"retry_after": 30, // seconds
					})
				}
				
				return err
			}
			
			// Si no hay error, continuar normalmente
			return nil
		}
	}
}