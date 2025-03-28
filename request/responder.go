// Copyright 2022 IBM Corp. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package request

import (
	"sync"

	"github.com/Hanzheng2021/Orthrus/log"
	"github.com/Hanzheng2021/Orthrus/messenger"
	pb "github.com/Hanzheng2021/Orthrus/protobufs"
	"github.com/Hanzheng2021/Orthrus/tracing"
	logger "github.com/rs/zerolog/log"
)

// Represents a responder to client requests
type Responder struct {

	// Channel through which the log will push entries to the responder in sequence number order.
	// The responder reads from this channel and responds to the corresponding client for each entry.
	entriesChan           chan *log.Entry
	entriesOutOfOrderChan chan *log.Entry
}

// Creates a new responder.
// A responder must be created before any protocol messages can be received from the network.
// Otherwise some responses to the client could be missed (in case entries are committed to the log before
// the responder has been created).
func NewResponder() *Responder {
	return &Responder{
		entriesChan:           log.Entries(),
		entriesOutOfOrderChan: log.EntriesOutOfOrder(),
	}
}

// Observes the log and responds to clients in commit order.
// Meant to be run as a separate goroutine.
// Decrements the provided wait group when done.
func (r *Responder) Start(wg *sync.WaitGroup) {
	defer wg.Done()

	// Read log entries (containing ordered batches) from
	// the entries channel until the channel is closed.
	for e := <-r.entriesChan; e != nil; e = <-r.entriesChan {

		// For each ClientRequest in the ordered batch
		for _, req := range e.Batch.Requests {
			if req.IsContract == 1 {

				logger.Trace().
					Int32("clientId", req.RequestId.ClientId).
					Int32("clientSn", req.RequestId.ClientSn).
					Int32("sn", e.Sn).
					Msg("Sending response to client.")
				logger.Debug().Msg("commit a contract transaction.")
				// Respond to the corresponding client.
				tracing.Trace2.EventForClientInPeer(tracing.RESP_SEND, int64(req.RequestId.ClientSn), req.RequestId.ClientId)

				messenger.RespondToClient(req.RequestId.ClientId, &pb.ClientResponse{
					OrderSn:  e.Sn,
					ClientSn: req.RequestId.ClientSn,
				})
			}
		}
	}
}

func (r *Responder) StartOutOfOrder(wg *sync.WaitGroup) {
	defer wg.Done()

	// Read log entries (containing ordered batches) from
	// the entries channel until the channel is closed.
	for e := <-r.entriesOutOfOrderChan; e != nil; e = <-r.entriesOutOfOrderChan {

		// For each ClientRequest in the ordered batch
		for _, req := range e.Batch.Requests {
			if req.IsContract == 0 {
				logger.Trace().
					Int32("clientId", req.RequestId.ClientId).
					Int32("clientSn", req.RequestId.ClientSn).
					Int32("sn", e.Sn).
					Msg("Sending response to client.(Out Of Order)")
				logger.Debug().Msg("commit a payment transaction.")
				// Respond to the corresponding client.
				tracing.Trace2.EventForClientInPeer(tracing.RESP_SEND, int64(req.RequestId.ClientSn), req.RequestId.ClientId)

				messenger.RespondToClient(req.RequestId.ClientId, &pb.ClientResponse{
					OrderSn:  e.Sn,
					ClientSn: req.RequestId.ClientSn,
				})
			}
		}
	}
}
