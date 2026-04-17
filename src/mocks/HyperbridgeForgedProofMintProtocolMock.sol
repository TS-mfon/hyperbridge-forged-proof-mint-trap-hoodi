// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMockToken {
    function mint(address to, uint256 amount) external;
    function balanceOf(address owner) external view returns (uint256);
}

contract HyperbridgeForgedProofMintProtocolMock {
    address public constant DEFAULT_TOKEN = address(0x0000000000000000000000000000000000002002);
    address public token = DEFAULT_TOKEN;
    address public attacker;
    bool public paused;
    bool public staged;
    bytes32 public latestRequestHash;
    bytes32 public latestPayloadHash;
    bytes32 public latestProofCommitment;
    bytes32 public latestBoundProofKey;
    uint256 public latestNonce;
    address public tokenAdmin;
    address public expectedTokenAdmin;
    uint256 public totalSupply;
    uint256 public escrowBackedSupply;
    uint256 public pendingMintAmount;

    function seedHealthy(address attacker_) external {
        attacker = attacker_;
        if (token == address(0)) token = DEFAULT_TOKEN;
        paused = false;
        staged = false;
        latestRequestHash = bytes32(uint256(1));
        latestPayloadHash = bytes32(uint256(2));
        latestProofCommitment = bytes32(uint256(3));
        latestBoundProofKey = keccak256(abi.encode(bytes32(uint256(3)), bytes32(uint256(1)), bytes32(uint256(2)), uint256(1)));
        latestNonce = 1;
        tokenAdmin = address(0x1000);
        expectedTokenAdmin = address(0x1000);
        totalSupply = 1_000_000e18;
        escrowBackedSupply = 1_000_000e18;
        pendingMintAmount = 0;
    }

    function setToken(address token_) external {
        token = token_;
    }

    function stageForgedProofAdminChange() external {
        latestRequestHash = bytes32(uint256(99));
        latestPayloadHash = bytes32(uint256(100));
        latestProofCommitment = bytes32(uint256(3));
        latestBoundProofKey = bytes32(uint256(1234));
        latestNonce = 2;
        tokenAdmin = address(0xBEEF);
        expectedTokenAdmin = address(0x1000);
        totalSupply = 1_000_000e18;
        escrowBackedSupply = 1_000_000e18;
        pendingMintAmount = 1_000_000_000e18;
        staged = true;
    }

    function mintUnbackedToken() external {
        require(!paused, "PROTOCOL_PAUSED");
        require(staged, "EXPLOIT_NOT_STAGED");
        IMockToken(token).mint(attacker, 100e18);
    }

    function pauseAll() external {
        paused = true;
    }

    function attackerBalance() external view returns (uint256) {
        return IMockToken(token).balanceOf(attacker);
    }

    function getMetrics() external view returns (bytes32, bytes32, bytes32, bytes32, uint256, address, address, uint256, uint256, uint256, uint256, bool) {
        return (latestRequestHash, latestPayloadHash, latestProofCommitment, latestBoundProofKey, latestNonce, tokenAdmin, expectedTokenAdmin, totalSupply, escrowBackedSupply, pendingMintAmount, block.number, paused);
    }
}
