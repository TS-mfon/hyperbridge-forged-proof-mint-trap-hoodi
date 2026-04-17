// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/mocks/MockToken.sol";
import "../src/mocks/HyperbridgeForgedProofMintProtocolMock.sol";
import "../src/mocks/HyperbridgeForgedProofMintAttacker.sol";
import "../src/HyperbridgeForgedProofMintResponse.sol";
import "../src/HyperbridgeForgedProofMintEnvironmentRegistry.sol";

interface VmScript {
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract DeployHoodiSimulation {
    VmScript internal constant vm = VmScript(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Deployment {
        address token;
        address protocol;
        address attacker;
        address response;
        address registry;
    }

    function run() external returns (Deployment memory out) {
        vm.startBroadcast();
        MockToken token = new MockToken();
        HyperbridgeForgedProofMintProtocolMock protocol = new HyperbridgeForgedProofMintProtocolMock(address(token));
        HyperbridgeForgedProofMintAttacker attacker = new HyperbridgeForgedProofMintAttacker(address(protocol));
        HyperbridgeForgedProofMintResponse response = new HyperbridgeForgedProofMintResponse();
        protocol.setEmergencyModule(address(response));
        protocol.seedHealthy(address(attacker));
        HyperbridgeForgedProofMintEnvironmentRegistry registry = new HyperbridgeForgedProofMintEnvironmentRegistry(keccak256("hyperbridge-forged-proof-mint-trap-hoodi"), address(protocol), address(response), address(response), true);
        out = Deployment(address(token), address(protocol), address(attacker), address(response), address(registry));
        vm.stopBroadcast();
    }
}
