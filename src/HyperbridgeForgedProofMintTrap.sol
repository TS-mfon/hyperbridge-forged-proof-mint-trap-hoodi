// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "./ITrap.sol";
import {TrapAlert} from "./TrapTypes.sol";

interface IHyperbridgeForgedProofMintEnvironmentRegistryView {
    function environmentId() external view returns (bytes32);
    function monitoredTarget() external view returns (address);
    function active() external view returns (bool);
}

interface IHyperbridgeForgedProofMintTarget {
    function getMetrics() external view returns (bytes32 latestRequestHash, bytes32 latestPayloadHash, bytes32 latestProofCommitment, bytes32 latestBoundProofKey, uint256 latestNonce, address tokenAdmin, address expectedTokenAdmin, uint256 totalSupply, uint256 escrowBackedSupply, uint256 pendingMintAmount, uint256 observedBlockNumber, bool paused);
}

contract HyperbridgeForgedProofMintTrap is ITrap {
    address public constant REGISTRY = address(0x0000000000000000000000000000000000003001);
    bytes32 public constant INVARIANT_ID = keccak256("HYPERBRIDGE_PROOF_MUST_BIND_REQUEST_V2");
    uint256 public constant REQUIRED_SAMPLES = 4;
    uint8 internal constant STATUS_OK = 0;
    uint8 internal constant STATUS_REGISTRY_INACTIVE = 1;
    uint8 internal constant STATUS_TARGET_MISSING = 2;
    uint8 internal constant STATUS_METRICS_CALL_FAILED = 3;
    uint8 internal constant STATUS_INVALID_METRICS = 4;
    uint256 internal constant BREACH_WINDOW = 5;
    uint256 internal constant MIN_BREACH_COUNT = 2;

    struct CollectOutput {
        bytes32 environmentId;
        address registry;
        address target;
        uint8 status;
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
        uint256 observedBlockNumber;
        bool paused;
    }

    function collect() external view returns (bytes memory) {
        if (REGISTRY.code.length == 0) {
            return _status(bytes32(0), address(0), STATUS_REGISTRY_INACTIVE);
        }

        IHyperbridgeForgedProofMintEnvironmentRegistryView registry = IHyperbridgeForgedProofMintEnvironmentRegistryView(REGISTRY);
        bytes32 environmentId = registry.environmentId();
        address target = registry.monitoredTarget();
        if (!registry.active()) return _status(environmentId, target, STATUS_REGISTRY_INACTIVE);
        if (target.code.length == 0) return _status(environmentId, target, STATUS_TARGET_MISSING);

        try IHyperbridgeForgedProofMintTarget(target).getMetrics() returns (bytes32 latestRequestHash, bytes32 latestPayloadHash, bytes32 latestProofCommitment, bytes32 latestBoundProofKey, uint256 latestNonce, address tokenAdmin, address expectedTokenAdmin, uint256 totalSupply, uint256 escrowBackedSupply, uint256 pendingMintAmount, uint256 observedBlockNumber, bool paused) {
            if (observedBlockNumber == 0 || paused) {
                return abi.encode(CollectOutput({
                    environmentId: environmentId,
                    registry: REGISTRY,
                    target: target,
                    status: paused ? STATUS_OK : STATUS_INVALID_METRICS,
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
                    observedBlockNumber: observedBlockNumber == 0 ? block.number : observedBlockNumber,
                    paused: paused
                }));
            }
            return abi.encode(CollectOutput({
                environmentId: environmentId,
                registry: REGISTRY,
                target: target,
                status: STATUS_OK,
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
                observedBlockNumber: observedBlockNumber,
                paused: paused
            }));
        } catch {
            return _status(environmentId, target, STATUS_METRICS_CALL_FAILED);
        }
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        if (data.length < REQUIRED_SAMPLES) return (false, bytes(""));
        CollectOutput memory latest = abi.decode(data[0], (CollectOutput));
        CollectOutput memory historical = abi.decode(data[data.length - 1], (CollectOutput));
        if (latest.status != STATUS_OK || latest.paused) return (false, bytes(""));
        if (historical.status != STATUS_OK || historical.environmentId != latest.environmentId || historical.target != latest.target) {
            return (false, bytes(""));
        }

        bool latestBreached = (_proofReplay(data, latest) || latest.latestBoundProofKey != _boundKey(latest.latestProofCommitment, latest.latestRequestHash, latest.latestPayloadHash, latest.latestNonce) || latest.tokenAdmin != latest.expectedTokenAdmin || latest.totalSupply + latest.pendingMintAmount > latest.escrowBackedSupply);
        if (!latestBreached) return (false, bytes(""));

        uint256 checked = data.length < BREACH_WINDOW ? data.length : BREACH_WINDOW;
        uint256 breachCount;
        for (uint256 i = 0; i < checked; i++) {
            CollectOutput memory sample = abi.decode(data[i], (CollectOutput));
            if (sample.status != STATUS_OK || sample.paused || sample.target != latest.target) continue;
            if (sample.observedBlockNumber >= historical.observedBlockNumber) {
                if (_proofReplay(data, latest) || sample.latestBoundProofKey != _boundKey(sample.latestProofCommitment, sample.latestRequestHash, sample.latestPayloadHash, sample.latestNonce) || sample.tokenAdmin != sample.expectedTokenAdmin || sample.totalSupply + sample.pendingMintAmount > sample.escrowBackedSupply) breachCount++;
            }
        }

        uint256 deteriorationSignals;
        if (latest.observedBlockNumber >= historical.observedBlockNumber) deteriorationSignals++;
        if (latest.target == historical.target) deteriorationSignals++;

        if (breachCount < MIN_BREACH_COUNT || deteriorationSignals < 2) return (false, bytes(""));

        TrapAlert memory alert = TrapAlert({
            invariantId: INVARIANT_ID,
            target: latest.target,
            observed: latest.totalSupply + latest.pendingMintAmount,
            expected: latest.escrowBackedSupply,
            blockNumber: latest.observedBlockNumber,
            environmentId: latest.environmentId,
            context: abi.encode(latest.registry, latest.status, latest.latestRequestHash, latest.latestPayloadHash, latest.latestProofCommitment, latest.latestBoundProofKey, latest.latestNonce, latest.tokenAdmin, breachCount, deteriorationSignals)
        });
        return (true, abi.encode(alert));
    }

    function _status(bytes32 environmentId, address target, uint8 status) internal view returns (bytes memory) {
        return abi.encode(CollectOutput({
            environmentId: environmentId,
            registry: REGISTRY,
            target: target,
            status: status,
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
            observedBlockNumber: block.number,
            paused: false
        }));
    }

    function _boundKey(bytes32 proof, bytes32 requestHash, bytes32 payloadHash, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encode(proof, requestHash, payloadHash, nonce));
    }

    function _proofReplay(bytes[] calldata data, CollectOutput memory latest) internal pure returns (bool) {
        for (uint256 i = 1; i < data.length; i++) {
            CollectOutput memory previous = abi.decode(data[i], (CollectOutput));
            if (
                previous.status == STATUS_OK &&
                previous.latestProofCommitment == latest.latestProofCommitment &&
                (previous.latestRequestHash != latest.latestRequestHash || previous.latestPayloadHash != latest.latestPayloadHash)
            ) return true;
        }
        return false;
    }

}
