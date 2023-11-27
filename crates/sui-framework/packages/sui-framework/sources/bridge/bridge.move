// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module sui::bridge {
    use std::ascii::String;
    use std::string;
    use std::type_name;
    use std::vector;

    use sui::address;
    use sui::balance;
    use sui::bcs;
    use sui::bridge_escrow::{Self, BridgeEscrow};
    use sui::bridge_governance::{Self, BridgeCommittee};
    use sui::bridge_treasury::{Self, BridgeTreasury};
    use sui::chain_ids;
    use sui::coin::{Self, Coin};
    use sui::dynamic_field as df;
    use sui::event::emit;
    use sui::object::UID;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct Bridge has key {
        id: UID,
        // nonce for replay protection
        sequence_num: u64,
        // committee pub keys
        committee: BridgeCommittee,
        // Escrow for storing native tokens
        escrow: BridgeEscrow,
        // Bridge treasury for mint/burn bridged tokens
        treasury: BridgeTreasury
    }

    // message types
    const TOKEN_BRIDGE_MSG: u8 = 0;
    //const OBJ_BRIDGE_MSG: u8 = 1;

    struct BridgeMessage has copy, store, drop {
        // 0: token , 1: object ? TBD
        message_type: u8,
        source_chain: u8,
        bridge_seq_num: u64,
        sender_address: vector<u8>,
        target_chain: u8,
        target_address: vector<u8>,
        payload: vector<u8>
    }

    struct ApprovedBridgeMessage has store {
        message: BridgeMessage,
        approved_epoch: u64,
        signatures: vector<vector<u8>>,
    }

    struct ApprovedBridgeMessageKey has copy, drop, store {
        source_chain: u8,
        bridge_seq_num: u64
    }

    struct BridgeEvent has copy, drop {
        message: BridgeMessage,
        message_bytes: vector<u8>
    }

    const UnexpectedMessageType: u64 = 0;
    const UnauthorisedClaim: u64 = 1;
    const MalformedMessageError: u64 = 2;
    const UnexpectedTokenType: u64 = 3;
    const UnexpectedChainID: u64 = 4;

    fun serialise_token_bridge_payload<T>(token: &Coin<T>): vector<u8> {
        let coin_type = bcs::to_bytes(type_name::borrow_string(&type_name::get<T>()));
        let amount = bcs::to_bytes(&balance::value(coin::balance(token)));
        vector::append(&mut coin_type, amount);
        coin_type
    }

    fun deserialise_token_bridge_payload(message: vector<u8>): (String, u64) {
        let bcs = bcs::new(message);
        let payload = bcs::peel_vec_vec_u8(&mut bcs);
        assert!(vector::length(&payload) == 2, MalformedMessageError);
        let amount_bytes = bcs::new(vector::pop_back(&mut payload));
        let amount = bcs::peel_u64(&mut amount_bytes);

        let coin_type_bytes = bcs::new(vector::pop_back(&mut payload));
        let coin_type = string::to_ascii(string::utf8(bcs::peel_vec_u8(&mut coin_type_bytes)));
        (coin_type, amount)
    }

    fun deserialise_message(message: vector<u8>): BridgeMessage {
        let bcs = bcs::new(message);
        BridgeMessage {
            message_type: bcs::peel_u8(&mut bcs),
            bridge_seq_num: bcs::peel_u64(&mut bcs),
            source_chain: bcs::peel_u8(&mut bcs),
            sender_address: bcs::peel_vec_u8(&mut bcs),
            target_chain: bcs::peel_u8(&mut bcs),
            target_address: bcs::peel_vec_u8(&mut bcs),
            payload: bcs::into_remainder_bytes(bcs)
        }
    }

    fun serialise_message(message: BridgeMessage): vector<u8> {
        let BridgeMessage {
            message_type,
            bridge_seq_num,
            source_chain,
            sender_address,
            target_chain,
            target_address,
            payload
        } = message;

        let message = vector[];
        vector::push_back(&mut message, message_type);
        vector::append(&mut message, bcs::to_bytes(&bridge_seq_num));
        vector::push_back(&mut message, source_chain);
        vector::append(&mut message, bcs::to_bytes(&sender_address));
        vector::push_back(&mut message, target_chain);
        vector::append(&mut message, bcs::to_bytes(&target_address));
        vector::append(&mut message, payload);

        message
    }

    /*    // todo: Send object to ethereum
        public fun send_object<T: key + store>(
            bridge: &mut Bridge,
            target_chain: u8,
            target_address: vector<u8>,
            obj: T,
            ctx: &mut TxContext
        ) {
            bridge.sequence_num = bridge.sequence_num + 1;
            // create bridge message
            let message = encode_message(&obj);
            // escrow object
            bridge_escrow::escrow_object(&mut bridge.escrow, obj);
            // emit event
            emit(BridgeEvent {
                sequence_num: bridge.sequence_num,
                sui_address: tx_context::sender(ctx),
                target_chain,
                target_address,
                message
            })
        }*/

    // Send token to ethereum
    public fun send_token<T>(
        self: &mut Bridge,
        target_chain: u8,
        target_address: vector<u8>,
        token: Coin<T>,
        ctx: &mut TxContext
    ) {
        self.sequence_num = self.sequence_num + 1;
        // create bridge message
        let payload = serialise_token_bridge_payload(&token);
        let message = BridgeMessage {
            message_type: TOKEN_BRIDGE_MSG,
            source_chain: chain_ids::sui(),
            bridge_seq_num: self.sequence_num,
            sender_address: address::to_bytes(tx_context::sender(ctx)),
            target_chain,
            target_address,
            payload
        };
        // burn / escrow token
        if (bridge_treasury::is_bridged_token<T>()) {
            bridge_treasury::burn(&mut self.treasury, token);
        }else {
            bridge_escrow::escrow_token(&mut self.escrow, token);
        };
        // emit event
        emit(BridgeEvent { message, message_bytes: serialise_message(message) })
    }

    // Record bridged message approvels in Sui, call by the bridge client
    public fun approve(
        bridge: &mut Bridge,
        message: vector<u8>,
        signatures: vector<vector<u8>>,
        ctx: &TxContext
    ) {
        // varify signatures
        bridge_governance::verify_signatures(&bridge.committee, message, signatures);
        let message = deserialise_message(message);
        let approved_message = ApprovedBridgeMessage {
            message,
            approved_epoch: tx_context::epoch(ctx),
            signatures,
        };
        df::add(
            &mut bridge.id,
            ApprovedBridgeMessageKey { source_chain: message.source_chain, bridge_seq_num: message.bridge_seq_num },
            approved_message
        )
    }

    // Claim message from ethereum
    fun claim_token_internal<T>(
        self: &mut Bridge,
        source_chain: u8,
        bridge_seq_num: u64,
        ctx: &mut TxContext
    ): (Coin<T>, address) {
        // retrieve approved bridge message
        let ApprovedBridgeMessage {
            message,
            approved_epoch: _,
            signatures: _,
        } = df::remove<ApprovedBridgeMessageKey, ApprovedBridgeMessage>(
            &mut self.id,
            ApprovedBridgeMessageKey { source_chain, bridge_seq_num }
        );
        // ensure target chain is Sui
        assert!(message.target_chain == chain_ids::sui(), UnexpectedChainID);
        // get owner address
        let owner = address::from_bytes(message.target_address);
        // ensure this is a token bridge message
        assert!(message.message_type == TOKEN_BRIDGE_MSG, UnexpectedMessageType);
        // extract token message
        let (token_type, amount) = deserialise_token_bridge_payload(message.payload);
        // check token type
        assert!(type_name::into_string(type_name::get<T>()) == token_type, UnexpectedTokenType);
        // claim from escrow or treasury
        let token = if (bridge_treasury::is_bridged_token<T>()) {
            bridge_treasury::mint<T>(&mut self.treasury, amount, ctx)
        }else {
            bridge_escrow::claim_token(&mut self.escrow, amount, ctx)
        };
        (token, owner)
    }

    /*    fun claim_object_internal<T>(self: &mut Bridge, bridge_tx_hash: vector<u8>, ): T {
            // retrieve approved bridge message
            let ApprovedBridgeMessage {
                target_chain,
                target_address,
                message,
                approved_epoch: _,
                signatures: _,
            } = df::remove<vector<u8>, ApprovedBridgeMessage>(&mut self.id, bridge_tx_hash);
            // ensure target chain is Sui
            assert!(target_chain == SUI, UnexpectedChainID);
            // get owner address
            let owner = address::from_bytes(target_address);
            // ensure this is a token bridge message
            assert!(message.message_type == OBJ_BRIDGE_MSG, UnexpectedMessageType);
            // get object id
            // Todo?
        }*/

    // This function can only be called by the token recipient
    public fun claim_token<T>(self: &mut Bridge, source_chain: u8, bridge_seq_num: u64, ctx: &mut TxContext): Coin<T> {
        let (token, owner) = claim_token_internal<T>(self, source_chain, bridge_seq_num, ctx);
        // Only token owner can claim the token
        assert!(tx_context::sender(ctx) == owner, UnauthorisedClaim);
        token
    }

    // This function can be called by anyone to claim and transfer the token to the recipient
    public fun claim_and_transfer_token<T>(
        self: &mut Bridge,
        source_chain: u8,
        bridge_seq_num: u64,
        ctx: &mut TxContext
    ) {
        let (token, owner) = claim_token_internal<T>(self, source_chain, bridge_seq_num, ctx);
        transfer::public_transfer(token, owner)
    }
}
