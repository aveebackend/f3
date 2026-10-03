// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {PriceReport} from "../libraries/PerpTypes.sol";

interface IOracleVerifier {
    function verify(PriceReport calldata report, bytes[] calldata sigs) external view;
}
