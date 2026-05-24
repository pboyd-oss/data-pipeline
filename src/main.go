package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok\n"))
	})
	log.Println("data-pipeline listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
