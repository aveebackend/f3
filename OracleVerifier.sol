// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";
import {
    PriceReport,
    STATUS_TRADING,
    WAD,
    InvalidParams,
    InvalidPrice,
    InvalidSignature,
    NoReferenceFeed,
    PriceNotTrading,
    QuorumNotMet,
    ReferenceDeviation,
    ReferenceUnavailable,
    ZeroAddress
} from "./libraries/PerpTypes.sol";

contract OracleVerifier is EIP712, AccessControl {
    struct ReferenceFeed {
        address feed;
        uint32 heartbeat;
        uint64 maxDeviation;
    }

    bytes32 public constant PRICE_REPORT_TYPEHASH = keccak256(
        "PriceReport(uint32 marketId,uint256 price,uint256 confidence,uint64 timestamp,uint8 status,uint64 pauseAt,uint64 unpauseAt)"
    );
    uint256 public constant MAX_SIGNERS = 16;
    uint256 public constant MIN_THRESHOLD = 2;

    bool public immutable requireReference;

    mapping(address => bool) public isSigner;
    uint256 public signerCount;
    uint256 public threshold;
    mapping(uint32 => ReferenceFeed) public referenceFeeds;

    event SignerSet(address indexed signer, bool active);
    event ThresholdSet(uint256 threshold);
    event ReferenceFeedSet(uint32 indexed marketId, address feed, uint32 heartbeat, uint64 maxDeviation);

    constructor(address admin, address[] memory signers, uint256 threshold_, bool requireReference_)
        EIP712("F3Perp", "1")
    {
        if (admin == address(0)) revert ZeroAddress();
        requireReference = requireReference_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        for (uint256 i; i < signers.length; ++i) {
            _setSigner(signers[i], true);
        }
        _setThreshold(threshold_);
    }

    function setSigner(address signer, bool active) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setSigner(signer, active);
        if (threshold > signerCount) revert InvalidParams();
    }

    function setThreshold(uint256 threshold_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setThreshold(threshold_);
    }

    function setReferenceFeed(uint32 marketId, ReferenceFeed calldata ref) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (ref.feed != address(0) && (ref.heartbeat == 0 || ref.maxDeviation == 0 || ref.maxDeviation > WAD)) {
            revert InvalidParams();
        }
        referenceFeeds[marketId] = ref;
        emit ReferenceFeedSet(marketId, ref.feed, ref.heartbeat, ref.maxDeviation);
    }

    function reportHash(PriceReport calldata r) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    PRICE_REPORT_TYPEHASH,
                    r.marketId,
                    r.price,
                    r.confidence,
                    r.timestamp,
                    r.status,
                    r.pauseAt,
                    r.unpauseAt
                )
            )
        );
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function verify(PriceReport calldata report, bytes[] calldata sigs) external view {
        if (report.status != STATUS_TRADING) revert PriceNotTrading();
        if (report.price == 0) revert InvalidPrice();
        if (sigs.length < threshold) revert QuorumNotMet();

        bytes32 digest = reportHash(report);
        address last;
        for (uint256 i; i < sigs.length; ++i) {
            (address signer, ECDSA.RecoverError err,) = ECDSA.tryRecoverCalldata(digest, sigs[i]);
            if (err != ECDSA.RecoverError.NoError || signer <= last || !isSigner[signer]) revert InvalidSignature();
            last = signer;
        }

        _checkReference(report);
    }

    function _checkReference(PriceReport calldata report) private view {
        ReferenceFeed memory ref = referenceFeeds[report.marketId];
        if (ref.feed == address(0)) {
            if (requireReference) revert NoReferenceFeed();
            return;
        }

        uint256 refPrice = _referencePrice(ref);
        if (refPrice == 0) {
            if (requireReference) revert ReferenceUnavailable();
            return;
        }

        uint256 diff = report.price > refPrice ? report.price - refPrice : refPrice - report.price;
        if (Math.mulDiv(diff, WAD, refPrice) > ref.maxDeviation) revert ReferenceDeviation();
    }

    function _referencePrice(ReferenceFeed memory ref) private view returns (uint256) {
        uint8 decimals;
        try IAggregatorV3(ref.feed).decimals() returns (uint8 d) {
            decimals = d;
        } catch {
            return 0;
        }
        if (decimals > 36) return 0;

        try IAggregatorV3(ref.feed).latestRoundData() returns (
            uint80, int256 answer, uint256, uint256 updatedAt, uint80
        ) {
            if (answer <= 0 || updatedAt + ref.heartbeat < block.timestamp) return 0;
            return decimals <= 18 ? uint256(answer) * 10 ** (18 - decimals) : uint256(answer) / 10 ** (decimals - 18);
        } catch {
            return 0;
        }
    }

    function _setSigner(address signer, bool active) private {
        if (signer == address(0)) revert ZeroAddress();
        if (isSigner[signer] == active) return;
        isSigner[signer] = active;
        if (active) {
            if (++signerCount > MAX_SIGNERS) revert InvalidParams();
        } else {
            --signerCount;
        }
        emit SignerSet(signer, active);
    }

    function _setThreshold(uint256 threshold_) private {
        if (threshold_ < MIN_THRESHOLD || threshold_ > signerCount) revert InvalidParams();
        threshold = threshold_;
        emit ThresholdSet(threshold_);
    }
}
