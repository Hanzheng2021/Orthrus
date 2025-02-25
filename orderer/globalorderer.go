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

package orderer

import (
	"sync"
	"time"

	"sort"

	"github.com/Hanzheng2021/orthrus/log"
	"github.com/Hanzheng2021/orthrus/manager"
	"github.com/Hanzheng2021/orthrus/membership"
	pb "github.com/Hanzheng2021/orthrus/protobufs"
	logger "github.com/rs/zerolog/log"
)

// Represents a PBFT Orderer implementation.
type GlobalOrderer struct {
	segmentChan           chan manager.Segment // Channel to which the Manager pushes new Segments.
	dispatcher            globalDispatcher     // map[int32]*globalInstance
	globalordererInstance *globalInstance
	backlog               backlog       // map[int32]chan*ordererMsg
	last                  int32         // Some sequence number we can ignere messages above
	commitTime            time.Duration // Median commit duration
	lock                  sync.Mutex
}

type globalDispatcher struct {
	mm sync.Map
}

// HandleMessage is called by the messenger each time an Orderer-issued message is received over the network.
func (po *GlobalOrderer) HandleMessage(msg *pb.ProtocolMessage) {
	logger.Debug().
		Int32("sn", msg.Sn).
		Int32("senderID", msg.SenderId).
		Msg("Globalorderer handling message.")

	sn := msg.Sn

	if msg.SenderId == membership.OwnID {
		logger.Warn().Int32("sn", sn).Msg("GlobalOrderer handles message from self.")
	}

	// Check if message is from an old segment and needs to be discarded
	// last := atomic.LoadInt32(&po.last)
	// if sn <= last {
	// 	logger.Debug().
	// 		Int32("sn", sn).
	// 		Int32("senderID", msg.SenderId).
	// 		Msg("GlobalOrderer discards message. Message belongs to an old segment.")
	// 	return
	// }

	// Set reception timestamp for Preprepare and Commit messages.
	// This is a hook required for measuring the throughput of different leaders.
	// We use this information to control own batch size as a means to deal with stragglers.
	switch m := msg.Msg.(type) {
	case *pb.ProtocolMessage_Preprepare:
		m.Preprepare.Ts = time.Now().UnixNano()
	case *pb.ProtocolMessage_Commit:
		m.Commit.Ts = time.Now().UnixNano()

		// TODO: Check for message types that should be handled with priority here, once the priority queue is implemented.

	}

	// Check if the message is for a future message and needs to be backlogged
	// pi, ok := po.dispatcher.load(sn)
	// if !ok {
	// 	logger.Info().
	// 		Int32("sn", sn).
	// 		Int32("senderID", msg.SenderId).
	// 		Msg("GlobalOrderer cannot handle message. No segment is available")
	// 	po.backlog.add(msg)
	// 	return
	// }

	// If we are not distinguishing priority from non-priority messages, do not check type.
	po.globalordererInstance.serializer.serialize(msg)

	//// Check the tye of the message.
	//switch msg.Msg.(type) {
	//case *pb.ProtocolMessage_Viewchange:
	//	//pi.priority.serialize(msg)
	//	pi.serializer.serialize(msg)
	//case *pb.ProtocolMessage_Newview:
	//	//pi.priority.serialize(msg)
	//	pi.serializer.serialize(msg)
	//default:
	//	pi.serializer.serialize(msg)
	//}
}

// Handles entries produced externally.
func (po *GlobalOrderer) HandleEntry(entry *log.Entry) {
	// Treat the log entry as a MissingEntry message
	// and process it using the instance according to its sequence number.
	po.HandleMessage(&pb.ProtocolMessage{
		SenderId: -1,
		Sn:       entry.Sn,
		Msg: &pb.ProtocolMessage_MissingEntry{
			MissingEntry: &pb.MissingEntry{
				Sn:      entry.Sn,
				Batch:   entry.Batch,
				Digest:  entry.Digest,
				Aborted: entry.Aborted,
				Suspect: entry.Suspect,
				Proof:   "Dummy Proof.",
			},
		},
	})
}

// Initializes the GlobalOrderer.
// Subscribes to new segments issued by the Manager and allocates internal buffers and data structures.
func (po *GlobalOrderer) Init(mngr manager.Manager) {
	po.segmentChan = mngr.SubscribeOrderer()
	b := backlog{
		epochLast:   -1,
		dispatcher:  make(map[int32]*ordererChannel),
		backlog:     make(map[int32][]*pb.ProtocolMessage),
		gc:          make(chan int32),
		subscribers: make(chan backlogSubscriber, backlogSize),
		messages:    newOrdererChannel(backlogSize),
	}
	po.backlog = b
	// po.last = -1
}

// Starts the GlobalOrderer. Listens on the channel where the Manager issues new Segemnts and starts a goroutine to
// handle each of them.
// Meant to be run as a separate goroutine.
// Decrements the provided wait group when done.
func (po *GlobalOrderer) Start(wg *sync.WaitGroup) {
	defer wg.Done()
	po.runGlobalOrdererInstance()
	//go func() {
	//	time.Sleep(20*time.Second)
	//	if membership.OwnID == 0 {
	//		logger.Fatal().Msg("Peer is crashing")
	//	}
	//}()

	// for s, ok := <-po.segmentChan; ok; s, ok = <-po.segmentChan {

	// 	logger.Info().
	// 		Int("segId", s.SegID()).
	// 		Int32("length", s.Len()).
	// 		Int32("firstSN", s.FirstSN()).
	// 		Int32("lastSN", s.LastSN()).
	// 		Int32("first leader", s.Leaders()[0]).
	// 		Int32("len", s.Len()).
	// 		//Int("bucket", s.Bucket().GetId()).
	// 		Msgf("GlobalOrderer received a new segment: %+v", s.SNs())

	// 	po.runSegment(s)
	// 	go po.killSegment(s)
	// }
}

// Runs the global ordering algorithm.
func (po *GlobalOrderer) runGlobalOrdererInstance() {
	gi := &globalInstance{}
	gi.init(po)
	po.globalordererInstance = gi
	gi.subscribeToBacklog()
	go gi.processSerializedMessages()
	for i := 0; i < 5; i++ {
		logger.Debug().Msg("Tick !")
		time.Sleep(time.Second)
	}
	// time.Sleep(120 * time.Second)
	// gi.serializer.stop()
}

// Runs the pbft ordering algorithm for a Segment.
// func (po *GlobalOrderer) runSegment(seg manager.Segment) {
// 	pi := &globalInstance{}
// 	pi.init(seg, po)
// 	for _, sn := range seg.SNs() {
// 		po.dispatcher.store(sn, pi)

// 	}
// 	logger.Info().Int("segID", seg.SegID()).
// 		Int32("first", seg.FirstSN()).
// 		Int32("last", seg.LastSN()).
// 		Msg("Starting PBFT instance.")

// 	pi.subscribeToBacklog()

// 	if isLeading(seg, membership.OwnID, pi.view) {
// 		go pi.lead()
// 	}
// 	go pi.processSerializedMessages()

// }

// func (po *GlobalOrderer) killSegment(seg manager.Segment) {
// 	// Wait until this segment is part of a stable checkpoint, AND all the sequence numbers are committed.
// 	// It might happen that we obtain a stable checkpoint before committing all sequence numbers, if others are faster.
// 	// It is important to subscribe before getting the current checkpoint, in case of a concurrent checkpoint update.
// 	checkpoints := log.Checkpoints()
// 	currentCheckpoint := log.GetCheckpoint()
// 	for currentCheckpoint == nil || currentCheckpoint.Sn < seg.LastSN() {
// 		currentCheckpoint = <-checkpoints
// 	}
// 	log.WaitForEntry(seg.LastSN())

// 	// Update the last sequence number the orderer accepts messages for
// 	po.lock.Lock()
// 	if seg.LastSN() > po.last {
// 		atomic.StoreInt32(&po.last, seg.LastSN())
// 	}
// 	po.lock.Unlock()

// 	// This is only possible because of the existence of the stable checkpoint.
// 	// Otherwise other segments could be affected, as the sequence numbers interleave.
// 	po.backlog.gc <- seg.LastSN()

// 	// We just need any entry from this segment
// 	pi, ok := po.dispatcher.load(seg.LastSN())
// 	if !ok {
// 		logger.Error().
// 			Int("segId", seg.SegID()).
// 			Msg("No instance available.")
// 		return
// 	}

// 	// Close the message channel for the segment
// 	logger.Info().Int("segID", seg.SegID()).Msg("Closing message serializers.")

// 	pi.priority.stop()
// 	pi.serializer.stop()
// 	pi.stopProposing()

// 	po.setMedianCommitTime(seg)
// 	logger.Info().Int("segID", seg.SegID()).Int64("commit", int64(po.commitTime)).Msg("Median commit time")

// 	// Delete the globalInstance for the segment
// 	for _, sn := range seg.SNs() {
// 		po.dispatcher.delete(sn)
// 	}
// }

func (po *GlobalOrderer) Sign(data []byte) ([]byte, error) {
	// TODO
	return nil, nil
}

func (po *GlobalOrderer) CheckSig(data []byte, senderID int32, signature []byte) error {
	// TODO
	return nil
}

func (po *GlobalOrderer) setMedianCommitTime(seg manager.Segment) {
	commits := make([]time.Duration, 0, 0)
	for _, sn := range seg.SNs() {
		duration := log.GetEntry(sn).CommitTs - log.GetEntry(sn).ProposeTs
		logger.Info().Int32("sn", sn).Int64("commitTs", log.GetEntry(sn).CommitTs).Int64("proposeTs", log.GetEntry(sn).ProposeTs).Int64("duration", duration).Msg("Statistics")
		commits = append(commits, time.Duration(duration)*time.Nanosecond)
	}
	sort.Slice(commits, func(i, j int) bool { return commits[i] < commits[j] })
	po.commitTime = commits[len(commits)/2]
}
