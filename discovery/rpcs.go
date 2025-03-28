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

package discovery

import (
	"context"
	"sort"
	"sync/atomic"

	logger "github.com/rs/zerolog/log"
	"github.com/Hanzheng2021/Orthrus/crypto"
	pb "github.com/Hanzheng2021/Orthrus/protobufs"
	"google.golang.org/grpc/peer"
)

// Implements the RegisterPeer RPC.
// Every node remotely calls this method exactly once at the very start.
// The discovery server waits until all peers have invoked RegisterPeer, gathers their identities,
// and only then sends a response (with information about the whole system) to everyone.
func (ds *DiscoveryServer) RegisterPeer(ctx context.Context, req *pb.RegisterPeerRequest) (*pb.RegisterPeerResponse, error) {
	// FIXME Keys should not be generated by the discovery service
	// FIXME Peer private keys should be generated by peers locally and peers should send their public key
	// FIXME Keys for threshold cryptosystem should be generated with a distributed key generation protocol

	// Get peer info to obtain network address (for logging purposes only).
	p, ok := peer.FromContext(ctx)
	if !ok {
		logger.Error().Msg("Failed to get gRPC peer info from context.")
	}
	addrPort := p.Addr.String()

	// Assign new numeric ID to discovered peer.
	newID := <-ds.peerIDs

	logger.Info().
		Int32("id", newID).
		Str("addrPort", addrPort).
		Str("publicAddr", req.PublicAddr).
		Str("privateAddr", req.PrivateAddr).
		Msg("Discovered node.")

	// Generate a key pair for discovered peer
	var (
		pubKey       interface{}
		privKey      interface{}
		pubKeyBytes  []byte
		privKeyBytes []byte
		err          error
	)
	if privKey, pubKey, err = crypto.GenerateKeyPair(); err != nil {
		logger.Fatal().Err(err).Msg("Failed to generate key pair for registering node.")
	}
	if pubKeyBytes, err = crypto.PublicKeyToBytes(pubKey); err != nil {
		logger.Fatal().Err(err).Msg("Failed to serialize public key for registering node.")
	}
	if privKeyBytes, err = crypto.PrivateKeyToBytes(privKey); err != nil {
		logger.Fatal().Err(err).Msg("Failed to serialize private key for registering node.")
	}

	// Create identity struct for discovered peer
	newIdentity := &pb.NodeIdentity{
		NodeId:      newID,
		PublicAddr:  req.PublicAddr,
		PrivateAddr: req.PrivateAddr,
		Port:        PeerBasePort + (11 * newID), // For old mir, ports need to be 11 apart.
		PubKey:      pubKeyBytes,
	}

	// Add discovered peer to local list of peers.
	ds.peers.Store(newID, newIdentity)
	ds.peerWg.Done()

	// Wait until all peers submit their requests
	ds.peerWg.Wait()

	// Collect all discovered peer identities and save them in ds.peerIdentities
	ds.doOnce.Do(ds.collectPeerIdentities)

	// Generate keys for threshold signatures
	// This step should be executed once after collecting all peer identities, since it depends on the number of peers
	ds.keyGenOnce.Do(ds.generateTBLSKeys)

	// Notify node, sending it the full membership list and its own new ID and key.
	return &pb.RegisterPeerResponse{
		NewPeerId:        newID,
		PrivKey:          privKeyBytes,
		TblsPubKey:       ds.TBLSPublicKey,
		TblsPrivKeyShare: ds.TBLSPrivateKeyShares[newID],
		Peers:            ds.peerIdentities,
	}, nil

}

// Implements the SyncPeer RPC.
// Synchronizes the current peers.
// When a peer initializes connections with other peers, it invokes the SyncPeer RPC.
// Similarly to RegisterPeer, the RPC returns when all peers have invoked SyncPeer, releasing them simultaneously.
func (ds *DiscoveryServer) SyncPeer(ctx context.Context, req *pb.SyncRequest) (*pb.SyncResponse, error) {

	// Get peer info to obtain network address (for logging purposes only).
	p, ok := peer.FromContext(ctx)
	if !ok {
		logger.Error().Msg("Failed to get gRPC peer info from context.")
	}
	addrPort := p.Addr.String()

	logger.Info().
		Int32("id", req.PeerId).
		Str("addrPort", addrPort).
		Msg("Peer initialized.")

	// Wait until all peers invoke SyncPeer
	ds.syncWg.Done()
	ds.syncWg.Wait()

	// Release calling peer.
	return &pb.SyncResponse{}, nil
}

// Implements the RegisterClient RPC.
// Used by the client to discover its own ID and the orderer peer identities.
// Waits until all peers have registered, collects their identities and sends those identities to back to the client.
func (ds *DiscoveryServer) RegisterClient(ctx context.Context, req *pb.RegisterClientRequest) (*pb.RegisterClientResponse, error) {

	// Assign a fresh ID to the new client.
	newClientID := <-ds.clientIDs

	// Get peer info to obtain network address (for logging purposes only)
	p, ok := peer.FromContext(ctx)
	if !ok {
		logger.Error().Msg("Failed to get gRPC peer info from context.")
	}

	logger.Info().
		Int32("id", newClientID).
		Str("addrPort", p.Addr.String()).
		Msg("New client.")

	// Wait until all peers submit their requests
	ds.peerWg.Wait()

	// Collect all discovered peer identities and save them in ds.peerIdentities
	ds.doOnce.Do(ds.collectPeerIdentities)

	// Generate keys for the BLS threshold cryptosystem.
	// Should be executed once, after collecting peerIdentities, since it depends on the number of peers.

	// Return the new client ID and a list of identities of the peers
	return &pb.RegisterClientResponse{
		NewClientId: newClientID,
		Peers:       ds.peerIdentities,
	}, nil
}

// Implements the NextCommand RPC.
// Updates the status of the command previously executed by the slave,
// waits until the next command is ready for this slave, and sends this command to the slave.
// If the request (SlaveStatus) has ID -1, this is the first request of an anonymous slave.
// In such a case, registers a new slave and responds with initialization command (containing a fresh slave ID).
func (ds *DiscoveryServer) NextCommand(ctx context.Context, status *pb.SlaveStatus) (*pb.MasterCommand, error) {

	// Get peer info to obtain network address (for logging purposes only)
	p, ok := peer.FromContext(ctx)
	if !ok {
		logger.Error().Msg("Failed to get gRPC peer info from context.")
	}
	logger.Debug().
		Int32("cmdId", status.CmdId).
		Int32("slaveID", status.SlaveId).
		Int32("statusCode", status.Status).
		Msg("Request from slave.")

	// Look up slave.
	s, ok := ds.slaves.Load(status.SlaveId)

	// If slave is known, update its status and send next command when ready.
	if ok {
		// Update slave status
		s.(*slave).Status = status.Status

		// If status is non-zero, report response as an error.
		if s.(*slave).Status != 0 {
			logger.Error().
				Str("addrPort", p.Addr.String()).
				Int32("slaveID", s.(*slave).SlaveID).
				Int32("cmdID", status.CmdId).
				Int32("status", s.(*slave).Status).
				Msg(status.Message)
			// If status is 0, print response as Info.
		} else {
			logger.Info().
				Str("addrPort", p.Addr.String()).
				Int32("slaveID", s.(*slave).SlaveID).
				Int32("cmdID", status.CmdId).
				Int32("status", s.(*slave).Status).
				Msg(status.Message)
		}

		// If slave just executed a command the master is waiting for, notify the master.
		if atomic.LoadInt32(&ds.waitingForCmd) == status.CmdId && ds.responseWG != nil {

			// This is not at all safe, but it's good enough for now.
			// It can miss the actual maximum, but it will never be falsely 0.
			if atomic.LoadInt32(&ds.maxCommandExitStatus) < status.Status {
				atomic.StoreInt32(&ds.maxCommandExitStatus, status.Status)
			}
			ds.responseWG.Done()
		}

		// Get next master command (block here until one is added to the queue)
		logger.Debug().
			Int32("slaveID", s.(*slave).SlaveID).
			Int32("finishedCmdID", status.CmdId).
			Msg("Waiting for next command for slave.")
		mc := <-s.(*slave).CommandQueue
		logger.Debug().
			Int32("slaveID", s.(*slave).SlaveID).
			Int32("newCmdID", status.CmdId).
			Msg("Sending next command to slave.")

		// Return next command
		return mc, nil

		// If this is the first time the slave is connecting, add it to the list of slaves
	} else if status.SlaveId == -1 {

		// Create and add new slave
		newSlave := ds.addNewSlave(ctx, status.Tag)

		// Respond with InitSlave command, informing the slave about its new ID.
		return &pb.MasterCommand{
			Cmd: &pb.MasterCommand_InitSlave{InitSlave: &pb.InitSlave{
				SlaveId: newSlave.SlaveID,
			}},
		}, nil
	} else {
		logger.Error().Int32("slaveID", status.SlaveId).Msg("Unknown slave.")
		return nil, nil // TODO: return a more meaningful error value.
	}
}

// AUXILIARY METHODS

// Gather all the discovered peer identities and pack them in a slice (to be included in response messages).
func (ds *DiscoveryServer) collectPeerIdentities() {
	logger.Info().Msg("Generating membership list.")

	// Allocate slice with identities
	ds.peerIdentities = make([]*pb.NodeIdentity, 0)

	// Dump node identities to slice
	ds.peers.Range(func(key interface{}, value interface{}) bool {
		ds.peerIdentities = append(ds.peerIdentities, value.(*pb.NodeIdentity))
		return true
	})

	// Sort identities by peer ID. No code should rely on this.
	// The old Mir implementation does, though, that is why we perform the sorting here.
	sort.Slice(ds.peerIdentities, func(i, j int) bool {
		return ds.peerIdentities[i].NodeId < ds.peerIdentities[j].NodeId
	})
}

// Generates keys for the BLS threshold cryptosystem
func (ds *DiscoveryServer) generateTBLSKeys() {
	n := len(ds.peerIdentities)
	f := (n - 1) / 3
	t := 2*f + 1
	pubKey, privKeyShares := crypto.TBLSKeyGeneration(t, n)
	serializedPubKey, err := crypto.TBLSPubKeyToBytes(pubKey)
	if err != nil {
		logger.Error().Msgf("could not serialize TBLS public key: %s", err.Error())
		return
	}
	serializedPrivKeyShares := make([][]byte, 0, 0)
	for _, priv := range privKeyShares {
		serialized, err := crypto.TBLSPrivKeyShareΤοBytes(priv)
		if err != nil {
			logger.Error().Msgf("could not serialize TBLS private key share: %s", err.Error())
			return
		}
		serializedPrivKeyShares = append(serializedPrivKeyShares, serialized)
	}
	ds.TBLSPublicKey = serializedPubKey
	ds.TBLSPrivateKeyShares = serializedPrivKeyShares
}

// Creates a new slave with a fresh ID and adds it to the local list of slaves.
func (ds *DiscoveryServer) addNewSlave(ctx context.Context, tag string) *slave {
	// Get peer info to obtain network address (for logging purposes only)
	p, ok := peer.FromContext(ctx)
	if !ok {
		logger.Error().Msg("Failed to get gRPC peer info from context.")
	}

	// Assign new ID to the slave.
	newID := <-ds.slaveIDs
	logger.Info().
		Int32("slaveID", newID).
		Str("tag", tag).
		Str("addrPort", p.Addr.String()).
		Msg("New slave.")

	// Create new slave data structure and add it to local list of slaves.
	newSlave := &slave{
		SlaveID: newID,
		Status:  0,
		// Note that this channel is unbuffered. When a slave is slow in asking for the next command,
		// writing to this channel might block.
		CommandQueue: make(chan *pb.MasterCommand),
		Tag:          tag,
	}

	ds.slaves.Store(newID, newSlave)

	// Return freshly created slave.
	return newSlave
}
