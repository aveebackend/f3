// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {MarketParams, WAD} from "./PerpTypes.sol";

library PerpMath {
    using SafeCast for uint256;
    using SafeCast for int256;

    uint256 internal constant YEAR = 365 days;
    uint256 internal constant DAY = 1 days;

    function mulDivSigned(int256 x, uint256 y, uint256 d, bool roundUp) internal pure returns (int256) {
        if (x >= 0) {
            return Math.mulDiv(uint256(x), y, d, roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor).toInt256();
        }
        return -Math.mulDiv(uint256(-x), y, d, roundUp ? Math.Rounding.Floor : Math.Rounding.Ceil).toInt256();
    }

    function vpi(MarketParams memory p, bool isLong, uint256 sizeUsd, uint256 price, uint256 confidence)
        internal
        pure
        returns (uint256)
    {
        uint256 spread = Math.max(p.vpiSpread, Math.mulDiv(confidence, WAD, price, Math.Rounding.Ceil));
        uint256 depth = isLong ? p.vpiDepthLong : p.vpiDepthShort;
        return spread + Math.mulDiv(p.vpiCoef, sizeUsd, depth, Math.Rounding.Ceil);
    }

    function increasePrice(uint256 price, uint256 impact, bool isLong) internal pure returns (uint256) {
        if (isLong) {
            return Math.mulDiv(price, WAD + impact, WAD, Math.Rounding.Ceil);
        }
        return Math.mulDiv(price, WAD - impact, WAD, Math.Rounding.Floor);
    }

    function decreasePrice(uint256 price, uint256 closeSpread, bool isLong) internal pure returns (uint256) {
        if (isLong) {
            return Math.mulDiv(price, WAD - closeSpread, WAD, Math.Rounding.Floor);
        }
        return Math.mulDiv(price, WAD + closeSpread, WAD, Math.Rounding.Ceil);
    }

    function notional(uint256 size, uint256 price) internal pure returns (uint256) {
        return Math.mulDiv(size, price, WAD, Math.Rounding.Floor);
    }

    function pnl(uint256 size, uint256 entryNotional, uint256 price, bool isLong) internal pure returns (int256) {
        if (isLong) {
            return Math.mulDiv(size, price, WAD, Math.Rounding.Floor).toInt256() - entryNotional.toInt256();
        }
        return entryNotional.toInt256() - Math.mulDiv(size, price, WAD, Math.Rounding.Ceil).toInt256();
    }

    function fundingOwed(uint256 size, int256 indexNow, int256 indexAtEntry) internal pure returns (int256) {
        return mulDivSigned(indexNow - indexAtEntry, size, WAD, true);
    }

    function indexContribution(uint256 size, int256 index) internal pure returns (int256) {
        return mulDivSigned(index, size, WAD, true);
    }

    function rollover(uint256 collateral, uint256 ratePerYear, uint256 elapsed) internal pure returns (uint256) {
        return Math.mulDiv(collateral, ratePerYear * elapsed, WAD * YEAR, Math.Rounding.Ceil);
    }

    function fundingRatePerDay(MarketParams memory p, uint256 skewUsd) internal pure returns (uint256) {
        uint256 rel = Math.mulDiv(skewUsd, WAD, p.fundingSkewScale, Math.Rounding.Floor);
        int256 rate;
        if (rel <= p.fundingInflection) {
            rate = int256(uint256(p.fundingLowA)) + Math.mulDiv(p.fundingLowB, rel, WAD).toInt256();
        } else {
            rate = int256(p.fundingHighA) + Math.mulDiv(p.fundingHighB, rel, WAD).toInt256();
        }
        return rate > 0 ? uint256(rate) : 0;
    }

    function fundingStep(uint256 ratePerDay, uint256 price, uint256 elapsed) internal pure returns (uint256) {
        return Math.mulDiv(ratePerDay, price * elapsed, WAD * DAY, Math.Rounding.Floor);
    }

    function liquidatable(int256 equityUsd, uint256 notionalUsd, uint256 mmr) internal pure returns (bool) {
        return equityUsd < Math.mulDiv(notionalUsd, mmr, WAD, Math.Rounding.Ceil).toInt256();
    }

    function withinInitialMargin(int256 equityUsd, uint256 notionalUsd, uint256 maxLeverage)
        internal
        pure
        returns (bool)
    {
        return equityUsd > 0 && uint256(equityUsd) * maxLeverage >= notionalUsd;
    }

    function share(uint256 amount, uint256 fraction, bool roundUp) internal pure returns (uint256) {
        return Math.mulDiv(amount, fraction, WAD, roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor);
    }

    function toUsd(uint256 amount, uint256 usdScale, uint256 collateralPrice, bool roundUp)
        internal
        pure
        returns (uint256)
    {
        return Math.mulDiv(amount * usdScale, collateralPrice, WAD, roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor);
    }

    function toToken(uint256 usd, uint256 usdScale, uint256 collateralPrice, bool roundUp)
        internal
        pure
        returns (uint256)
    {
        return Math.mulDiv(usd, WAD, usdScale * collateralPrice, roundUp ? Math.Rounding.Ceil : Math.Rounding.Floor);
    }

    function toTokenSigned(int256 usd, uint256 usdScale, uint256 collateralPrice, bool roundUp)
        internal
        pure
        returns (int256)
    {
        return mulDivSigned(usd, WAD, usdScale * collateralPrice, roundUp);
    }

    function marginUsd(uint256 amount, uint256 usdScale, uint256 collateralPrice, uint256 haircut)
        internal
        pure
        returns (uint256)
    {
        return share(toUsd(amount, usdScale, collateralPrice, false), WAD - haircut, false);
    }
}
