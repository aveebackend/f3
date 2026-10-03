// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

uint256 constant WAD = 1e18;
uint8 constant STATUS_TRADING = 1;

enum OrderKind {
    MarketIncrease,
    MarketDecrease,
    LimitIncrease,
    StopIncrease,
    LimitDecrease,
    StopDecrease,
    RemoveCollateral
}

enum ActionKind {
    Order,
    Liquidate,
    ForceCloseMaxProfit
}

struct Order {
    address account;
    uint32 marketId;
    OrderKind kind;
    bool isLong;
    uint256 size;
    uint256 collateral;
    uint256 triggerPrice;
    uint256 acceptablePrice;
    uint64 createdAt;
    uint64 expiry;
    uint32 generation;
    uint256 nonce;
}

struct Action {
    ActionKind kind;
    address account;
    bool isLong;
    Order order;
    bytes signature;
}

struct PriceReport {
    uint32 marketId;
    uint256 price;
    uint256 confidence;
    uint64 timestamp;
    uint8 status;
    uint64 pauseAt;
    uint64 unpauseAt;
}

struct PriceCtx {
    uint256 price;
    uint256 confidence;
    uint64 timestamp;
}

struct MarketParams {
    uint64 mmr;
    uint64 openFeeRate;
    uint64 closeFeeRate;
    uint64 liquidationFee;
    uint64 keeperShare;
    uint64 vpiSpread;
    uint64 vpiCoef;
    uint64 maxVpi;
    uint64 closeSpread;
    uint64 maxProfitRatio;
    uint64 rolloverRatePerYear;
    uint64 maxPriceJump;
    uint64 fundingLowA;
    uint64 fundingLowB;
    int64 fundingHighA;
    uint64 fundingHighB;
    uint64 fundingInflection;
    uint16 maxLeverage;
    uint128 vpiDepthLong;
    uint128 vpiDepthShort;
    uint128 maxOiLong;
    uint128 maxOiShort;
    uint128 maxPositionUsd;
    uint128 fundingSkewScale;
    uint128 minCollateral;
    uint128 minKeeperReward;
    uint128 maxKeeperReward;
}

struct GlobalParams {
    uint128 executionFee;
    uint64 reserveFactor;
    uint64 protocolFeeShare;
    uint32 maxPriceAge;
    uint32 maxFutureSkew;
    uint32 marketOrderMaxDelay;
    uint32 collateralMarketId;
    uint64 collateralHaircut;
}

struct SideState {
    uint256 size;
    uint256 entryNotional;
    uint256 collateral;
    int256 sumSizeIndex;
}

struct Position {
    uint128 size;
    uint128 entryNotional;
    uint128 collateral;
    int128 fundingIndex;
    uint64 lastFeeTs;
    uint32 generation;
}

struct Settlement {
    address account;
    address keeper;
    int256 free;
    int256 collateral;
    int256 lp;
    int256 insurance;
    uint256 protocolFee;
    uint256 keeperFee;
}

error Unauthorized();
error ZeroAddress();
error InvalidParams();
error Paused();
error InsufficientBalance();
error NotConserved();
error InvalidSignature();
error QuorumNotMet();
error PriceNotTrading();
error InvalidPrice();
error PriceTooOld();
error PriceFromFuture();
error PriceNotMonotonic();
error PriceJumpTooLarge();
error PriceBeforeOrder();
error ReferenceDeviation();
error NonceUsed();
error OrderExpired();
error MarketMismatch();
error MarketNotListed();
error MarketAlreadyListed();
error MarketPaused();
error MarketCloseOnly();
error TriggerNotMet();
error PriceNotAcceptable();
error PriceImpactTooHigh();
error LeverageTooHigh();
error CollateralTooLow();
error OiCapExceeded();
error PositionCapExceeded();
error ReserveExceeded();
error WouldBeBadDebt();
error PositionUnderwater();
error NotLiquidatable();
error NotAtProfitCap();
error GenerationMismatch();
error NoPosition();
error ZeroSize();
error ActionOutOfGas();
error StalePrice();
error RequestNotFound();
error RequestNotExpired();
error KeeperActive();
error QueueLocked();
error OutflowLimit();
error RecipientNotAllowed();
error NoReferenceFeed();
error ReferenceUnavailable();
error SharesLocked();
error EmergencyInactive();
