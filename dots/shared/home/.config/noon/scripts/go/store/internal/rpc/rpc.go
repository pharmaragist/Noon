package rpc

import (
	"encoding/json"
	"os"
	"sync"
)

type Request struct {
	Id     json.RawMessage `json:"id"`
	Method string          `json:"method"`
	Params json.RawMessage `json:"params"`
}

var outMu sync.Mutex

func writeLine(v interface{}) error {
	b, err := json.Marshal(v)
	if err != nil {
		return err
	}
	b = append(b, '\n')
	outMu.Lock()
	defer outMu.Unlock()
	_, err = os.Stdout.Write(b)
	return err
}

func WriteResult(id json.RawMessage, result interface{}) error {
	return writeLine(map[string]interface{}{
		"id":     json.RawMessage(id),
		"result": result,
	})
}

func WriteError(id json.RawMessage, code, message string) error {
	if id == nil {
		return writeLine(map[string]interface{}{
			"error": map[string]string{"code": code, "message": message},
		})
	}
	return writeLine(map[string]interface{}{
		"id":    json.RawMessage(id),
		"error": map[string]string{"code": code, "message": message},
	})
}

func WriteEvent(id json.RawMessage, event string, data interface{}) error {
	return writeLine(map[string]interface{}{
		"id":    json.RawMessage(id),
		"event": event,
		"data":  data,
	})
}

func WriteProgress(id json.RawMessage, recv, total int64, phase string) error {
	return WriteEvent(id, "progress", map[string]interface{}{
		"phase":         phase,
		"receivedBytes": recv,
		"totalBytes":    total,
	})
}
