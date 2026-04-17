// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "./ITrap.sol";
import {TrapAlert} from "./TrapTypes.sol";

interface IHyperbridgeForgedProofMintTarget {
    function getMetrics() external view returns (bytes32 latestRequestHash, bytes32 latestPayloadHash, bytes32 latestProofCommitment, bytes32 latestBoundProofKey, uint256 latestNonce, address tokenAdmin, address expectedTokenAdmin, uint256 totalSupply, uint256 escrowBackedSupply, uint256 pendingMintAmount, uint256 blockNumber, bool paused);
}

contract HyperbridgeForgedProofMintTrap is ITrap {
    address public constant TARGET = address(0x0000000000000000000000000000000000001001);
    bytes32 public constant INVARIANT_ID = keccak256("HYPERBRIDGE_PROOF_MUST_BIND_REQUEST");
    uint256 public constant REQUIRED_SAMPLES = 4;

    struct CollectOutput {
    address target;
    bytes32 latestRequestHash;
    bytes32 latestPayloadHash;
    bytes32 latestProofCommitment;
    bytes32 latestBoundProofKey;
    uint256 latestNonce;
    address tokenAdmin;
    address expectedTokenAdmin;
    uint256 totalSupply;
    uint256 escrowBackedSupply;
    uint256 pendingMintAmount;
    uint256 blockNumber;
    bool paused;
    }

    function collect() external view returns (bytes memory) {
        if (TARGET.code.length == 0) {
            return abi.encode(CollectOutput({
                target: TARGET,
                latestRequestHash: bytes32(uint256(1)),
            latestPayloadHash: bytes32(uint256(2)),
            latestProofCommitment: bytes32(uint256(3)),
            latestBoundProofKey: keccak256(abi.encode(bytes32(uint256(3)), bytes32(uint256(1)), bytes32(uint256(2)), uint256(1))),
            latestNonce: 1,
            tokenAdmin: address(0x1000),
            expectedTokenAdmin: address(0x1000),
            totalSupply: 1_000_000e18,
            escrowBackedSupply: 1_000_000e18,
            pendingMintAmount: 0,
                blockNumber: block.number,
                paused: false
            }));
        }
        try IHyperbridgeForgedProofMintTarget(TARGET).getMetrics() returns (bytes32 latestRequestHash, bytes32 latestPayloadHash, bytes32 latestProofCommitment, bytes32 latestBoundProofKey, uint256 latestNonce, address tokenAdmin, address expectedTokenAdmin, uint256 totalSupply, uint256 escrowBackedSupply, uint256 pendingMintAmount, uint256 blockNumber, bool paused) {
            return abi.encode(CollectOutput({
                target: TARGET,
                latestRequestHash: latestRequestHash,
                latestPayloadHash: latestPayloadHash,
                latestProofCommitment: latestProofCommitment,
                latestBoundProofKey: latestBoundProofKey,
                latestNonce: latestNonce,
                tokenAdmin: tokenAdmin,
                expectedTokenAdmin: expectedTokenAdmin,
                totalSupply: totalSupply,
                escrowBackedSupply: escrowBackedSupply,
                pendingMintAmount: pendingMintAmount,
                blockNumber: blockNumber,
                paused: paused
            }));
        } catch {
            return abi.encode(CollectOutput({
                target: TARGET,
                latestRequestHash: bytes32(uint256(1)),
            latestPayloadHash: bytes32(uint256(2)),
            latestProofCommitment: bytes32(uint256(3)),
            latestBoundProofKey: keccak256(abi.encode(bytes32(uint256(3)), bytes32(uint256(1)), bytes32(uint256(2)), uint256(1))),
            latestNonce: 1,
            tokenAdmin: address(0x1000),
            expectedTokenAdmin: address(0x1000),
            totalSupply: 1_000_000e18,
            escrowBackedSupply: 1_000_000e18,
            pendingMintAmount: 0,
                blockNumber: block.number,
                paused: false
            }));
        }
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        if (data.length < REQUIRED_SAMPLES) return (false, bytes(""));
        CollectOutput memory latest = abi.decode(data[0], (CollectOutput));
        CollectOutput memory oldest = abi.decode(data[data.length - 1], (CollectOutput));
        if (_proofReplay(data, latest) || latest.latestBoundProofKey != _boundKey(latest.latestProofCommitment, latest.latestRequestHash, latest.latestPayloadHash, latest.latestNonce) || latest.tokenAdmin != latest.expectedTokenAdmin || latest.totalSupply + latest.pendingMintAmount > latest.escrowBackedSupply) {
            TrapAlert memory alert = TrapAlert({
                invariantId: INVARIANT_ID,
                target: latest.target,
                observed: latest.totalSupply + latest.pendingMintAmount,
                expected: latest.escrowBackedSupply,
                blockNumber: latest.blockNumber,
                context: abi.encode(latest.latestRequestHash, latest.latestPayloadHash, latest.latestProofCommitment, latest.latestBoundProofKey, latest.latestNonce, latest.tokenAdmin)
            });
            return (true, abi.encode(alert));
        }
        return (false, bytes(""));
    }

    function _boundKey(bytes32 proof, bytes32 requestHash, bytes32 payloadHash, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode(proof, requestHash, payloadHash, nonce));
    }

    function _proofReplay(bytes[] calldata data, CollectOutput memory latest) internal pure returns (bool) {
        for (uint256 i = 1; i < data.length; i++) {
            CollectOutput memory previous = abi.decode(data[i], (CollectOutput));
            if (
                previous.latestProofCommitment == latest.latestProofCommitment
                    && (previous.latestRequestHash != latest.latestRequestHash || previous.latestPayloadHash != latest.latestPayloadHash)
            ) {
                return true;
            }
        }
        return false;
    }

}
