// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RewardsDistributor is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Root {
        bytes32 root;
        uint64 epoch;
        uint64 proposedAt;
        uint256 total;
    }

    bytes32 public constant ROOT_SETTER_ROLE = keccak256("ROOT_SETTER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    uint64 public constant MIN_ROOT_DELAY = 1 hours;
    uint64 public constant MAX_ROOT_DELAY = 30 days;

    uint64 public immutable ROOT_DELAY;

    mapping(address token => Root) public activeRoot;
    mapping(address token => Root) public pendingRoot;
    mapping(address token => uint256) public totalClaimed;
    mapping(address token => mapping(address account => uint256)) public claimed;

    event RootProposed(address indexed token, uint64 indexed epoch, bytes32 root, uint256 total, uint64 activatesAt);
    event RootVetoed(address indexed token, uint64 indexed epoch, bytes32 root);
    event RootActivated(address indexed token, uint64 indexed epoch, bytes32 root, uint256 total);
    event Claimed(address indexed token, address indexed account, uint256 amount, uint256 cumulative);

    error ZeroAddress();
    error InvalidRootDelay();
    error EmptyRoot();
    error EpochNotIncreasing();
    error NoPendingRoot();
    error RootDelayNotPassed();
    error RootUnderfunded();
    error NoActiveRoot();
    error InvalidProof();
    error NothingToClaim();

    constructor(address admin, address rootSetter, address guardian, uint64 rootDelay) {
        if (admin == address(0) || rootSetter == address(0) || guardian == address(0)) revert ZeroAddress();
        if (rootDelay < MIN_ROOT_DELAY || rootDelay > MAX_ROOT_DELAY) revert InvalidRootDelay();
        ROOT_DELAY = rootDelay;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ROOT_SETTER_ROLE, rootSetter);
        _grantRole(GUARDIAN_ROLE, guardian);
    }

    function proposeRoot(address token, bytes32 root, uint64 epoch, uint256 total) external onlyRole(ROOT_SETTER_ROLE) {
        if (token == address(0)) revert ZeroAddress();
        if (root == bytes32(0)) revert EmptyRoot();
        if (epoch <= activeRoot[token].epoch || epoch <= pendingRoot[token].epoch) revert EpochNotIncreasing();
        pendingRoot[token] = Root({root: root, epoch: epoch, proposedAt: uint64(block.timestamp), total: total});
        emit RootProposed(token, epoch, root, total, uint64(block.timestamp) + ROOT_DELAY);
    }

    function vetoRoot(address token) external onlyRole(GUARDIAN_ROLE) {
        Root memory p = pendingRoot[token];
        if (p.root == bytes32(0)) revert NoPendingRoot();
        delete pendingRoot[token];
        emit RootVetoed(token, p.epoch, p.root);
    }

    function activateRoot(address token) external {
        Root memory p = pendingRoot[token];
        if (p.root == bytes32(0)) revert NoPendingRoot();
        if (block.timestamp < uint256(p.proposedAt) + ROOT_DELAY) revert RootDelayNotPassed();
        if (p.total > IERC20(token).balanceOf(address(this)) + totalClaimed[token]) revert RootUnderfunded();
        delete pendingRoot[token];
        activeRoot[token] = p;
        emit RootActivated(token, p.epoch, p.root, p.total);
    }

    function claim(address token, address account, uint256 cumulativeAmount, bytes32[] calldata proof)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amount)
    {
        bytes32 root = activeRoot[token].root;
        if (root == bytes32(0)) revert NoActiveRoot();
        if (!MerkleProof.verifyCalldata(proof, root, leaf(account, token, cumulativeAmount))) revert InvalidProof();
        uint256 already = claimed[token][account];
        if (cumulativeAmount <= already) revert NothingToClaim();
        amount = cumulativeAmount - already;
        claimed[token][account] = cumulativeAmount;
        totalClaimed[token] += amount;
        IERC20(token).safeTransfer(account, amount);
        emit Claimed(token, account, amount, cumulativeAmount);
    }

    function pause() external {
        if (!hasRole(GUARDIAN_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, GUARDIAN_ROLE);
        }
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function leaf(address account, address token, uint256 cumulativeAmount) public pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account, token, cumulativeAmount))));
    }
}
